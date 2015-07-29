OpenLDAP for OpenShift - Docker images
========================================

This repository contains Dockerfiles for OpenLDAP images for OpenShift testing.
Images are based on CentOS. Images are **NOT** meant to be used for LDAP servers in
any environment other than the OpenShift Origin test environment at this time. No
guarantees are given for the efficacy or stability of images in this repository or
those created with Dockerfiles from this repository.


Versions
---------------
OpenLDAP versions currently provided are:
* openldap-2.4.41

CentOS versions currently supported are:
* CentOS7


Installation
----------------------
To build an OpenLDAP image from scratch run:

```
$ git clone https://github.com/openshift/openldap.git
$ cd openldap
$ make build
```

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name           |    Description                            | Default                   |
| :------------------------- | ----------------------------------------- | ------------------------- |
|  `OPENLDAP_ROOT_PASSWORD`  | OpenLDAP `olcRootPW` password             | `admin`                   |
|  `OPENLDAP_ROOT_DN_SUFFIX` | OpenLDAP `olcSuffix` suffix               | `dc=example,dc=com`       |
|  `OPENLDAP_ROOT_DN_PREFIX` | OpenLDAP `olcRootDN` prefix               | `cn=Manager`              |
|  `OPENLDAP_DEBUG_LEVEL`    | OpenLDAP Server Debug Level               | `256`                     |

The following table details the possible debug levels.

| Debug Level | Description                                   |
| ----------- | --------------------------------------------- |
| -1          | Enable all debugging                          |  
|  0          | Enable no debugging                           |
|  1          | Trace function calls                          |
|  2          | Debug packet handling                         |
|  4          | Heavy trace debugging                         |
|  8          | Connection management                         |
|  16         | Log packets sent and recieved                 |
|  32         | Search filter processing                      |
|  64         | Configuration file processing                 |
|  128        | Access control list processing                |
|  256        | Stats log connections, operations and results |
|  512        | Stats log entries sent                        |
|  1024       | Log communication with shell backends         |
|  2048       | Log etry parsing debugging                    | 

Usage
---------------------------------

If you want to set only the mandatory environment variables and not store
the LDAP directory in a host directory, execute the following command:

```
$ docker run -d --name openldap_server -p 389:389 -p 636:636 openshift/openldap-2441-centos7:latest
```

This will create a container named `openldap_server` running OpenLDAP with an admin
user with credentials `cn=Manager,dc=example,dc=com:admin`. Ports 389 and 636 will be exposed and mapped
to the host for `ldap` and `ldaps` endpoints.

If the configuration directory is not initialized, the entrypoint script will first
run [`run-openldap.sh`](2.4.41/run-openldap.sh) and setup necessary directory users and passwords. 
After the database is initialized, or if it was already present, `slapd` is executed and will run 
as PID 1. You can stop the detached container by running `docker stop openldap_server`.

Test [NYI]
---------------------------------

This repository also provides a test framework, which checks basic functionality
of the OpenLDAP image. To run the tests, execute the follwing:

```
$ cd openldap
$ make test
```
