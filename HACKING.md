# Development Reference 

## Purpose
The purpose of this document is to provide a clear and reference-filled document for developers that want to work with the OpenShift OpenLDAP Docker image. The creation of this image brought many issues to light and was not straightforward. Decisions were made to mitigate these issues and the description of those decisions follows.

## Development Considerations
This image was originally created in order to facilitate testing of the OpenShift LDAP group sync feature. However, during creation it was clear that it would not be difficult to build the test image as a layer or layers on top of a general-purpose OpenLDAP image for use by developers in OpenShift. Therefore, the following characteristics were desriable from the image: 

* random UID for the user in the running container
* user-settable attributes for OpenLDAP setup at run-time
* ability for full user interaction:
  * searching for records
  * amending, adding and removing records

In order to support all of these requirements, we need some permissions during the initial OpenLDAP installation. Specifically, if a user wants to set characteristics in the `cn\=config` database (`olcDatabase{0}config`), the user needs to authenticate with the LDAP server. This can be done in three ways: [simply](http://www.openldap.org/doc/admin24/security.html#%22simple%22%20method), [using SASL](http://www.openldap.org/doc/admin24/sasl.html), and [using TLS](http://www.openldap.org/doc/admin24/tls.html). The user could also choose to use `slapcat` and `slapadd` to dump a valid configuration and load it into a new server, or blind-mount the entire `etc/openldap` and `var/lib/ldap` directories.

### OpenLDAP Authentication
In order to use simple authentication, no extra work has to be done. However, this level of authentication does not give enough privilege to configure `olcDatabase{0}config` and therefore does not allow a user to change `root` characteristics, schemas, *etc.*

In order to use [SASL](https://en.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer), extra work might need to be done. The following table juxtaposes SASL mechanisms with the work they need:

SASL Mechanism                        | Implementation
------------------------------------- | -------------- 
`EXTERNAL`                            | The `EXTERNAL` mechanism makes use of a lower-level authentication level, either IPC or TLS. In order to set up TLS, `root`-level authenticated access to `olcDatabase{0}config` database is necessary to add proper certificates. In order to set up IPC, `root`-level user privilege is necessary to open the `ldapi:///` socket. 
`GSSAPI`, `KERBEROS_V4`, `DIGEST-MD5` | The `GSSAPI`, `KERBEROS_V4`, `DIGEST-MD5` mechanisms all require the set-up of an external authentication mechanism, either Kerberos or an authentication identity mapping. They furthermore require `root`-level access to `olcDatabase{0}config` to initiate the setup. 

As is clear, in order to use SASL, `root`-level access to the `olcDatabase{0}config` database is required. If we are trying to acces this database in order to commit `root`-level credentials or information like schemas or the `top` object, this is a self-referential problem.

In order to use TLS as the underlying mechanism for SASL `EXTERNAL`, one can only vaguely follow the [documentation](http://www.openldap.org/faq/data/cache/185.html) as it continues to refer to the `slapd.conf` schema for configuration, which is deprecated in the current OpenLDAP release. Furthermore, pointing the OpenLDAP daemon to certs requires `root`-level access to `olcDatabase{0}config`, which, again, is an endless problem if you are attempting to create an authentication scheme so you can access that database.

The default out-of-the-box installation of OpenLDAP contains a `olcRootDN` manager for the `cn=config` database but does not list a password, which is problematic as it does not allow you to use the full authentication (`-x -D <managerCN> -w <password>`) and therefore does not allow for the user to use this set-up to add or remove records unless they are `UID 0`.

### OpenLDAP Configuration Dump
OpenLDAP exposes administrative tools like [`slapadd`](http://www.openldap.org/software/man.cgi?query=slapadd&apropos=0&sektion=0&manpath=OpenLDAP+2.4-Release&format=html) and [`slpacat`](http://www.openldap.org/software/man.cgi?query=slapcat&apropos=0&sektion=0&manpath=OpenLDAP+2.4-Release&format=html) which operate on OpenLDAP installations with the daemon not running. These tools are a promising work-around to the authentication nightmare above. The gist of this approach is as such: first, install OpenLDAP on a machine or container where you have `root` privileges (`UID 0` and `GID 0` are required due to how OpenLDAP generates authentication identities), create an OpenLDAP installation to your liking, stop the daemon (`slapd`), dump all of the OpenLDAP installation to `ldif` using `slapcat -n0`, then import all of the data using `slapadd -n0` on another installation. 

This approach does not seem to work, however. If there are no traces of the new `cn=config` configuration schema in the `etc/openldap` directory, the `slapadd` command looks for the old `slapd.conf` configuration schema and fails because that schema is deprecated. `slapadd` also cannot be used while the daemon is off to edit records as it is only capable of adding objects. Therefore, a partial edit using `slapadd` is not possible. Furthermore, editing the files by hand will trigger checksum errors and cause a corrupt installation.

### OpenLDAP Blind-Mount of Files
The final and ugliest option is the blindly mount files to `etc/openldap` and `var/lib/ldap`. The process for this is very similar to that using `slapcat` and `slapadd` above. A working LDAP server has every single file in it's `etc/openldap` and `var/lib/ldap` directories copied and placed into the surrogate LDAP server you are trying to set up. The new server, when the daemon is run, will complain about the databases not being closed correctly but it is able tor recover and no errors result. The files in the [`contrib`](2.4.41/contrib) subdirectories ([`lib`](2.4.41/contrib/lib), [`config`](2.4.41/contrib/config)) are the result of this operation. These files can be re-created at any time by running the `openshift/openldap-2441-centos7` image as `UID 0` and harvesting the resulting files in the container's `etc/openldap` and `var/lib/ldap` directories.

This last approach is the approach that was finally able to create a valid OpenLDAP installation with a non-root user running the container.