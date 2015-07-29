FROM centos:centos7

# OpenLDAP server image for OpenShift Origin
#
# Volumes:
# * /var/lib/ldap/data - Datastore for OpenLDAP
# * /etc/openldap/     - Config directory for slapd
# Environment:
# * $OPENLDAP_ADMIN_PASSWORD         - OpenLDAP administrator password
# * $OPENLDAP_DEBUG_LEVEL (Optional) - OpenLDAP debugging level, defaults to 256

MAINTAINER Steve Kuznetsov <skuznets@redhat.com>

LABEL io.k8s.description="OpenLDAP is an open source implementation of the Lightweight Directory Access Protocol." \
      io.k8s.display-name="OpenLDAP 2.4.41" \
      io.openshift.expose-services="389:ldap,636:ldaps" \
      io.openshift.tags="directory,ldap,openldap,openldap2441" \
      io.openshift.non-scalable="true"

# Add defaults for config
COPY ./contrib/config /opt/openshift/config
COPY ./contrib/lib /opt/openshift/lib
# Add startup scripts
COPY run-*.sh /usr/local/bin/
COPY contrib/*.ldif /usr/local/etc/openldap/
COPY contrib/DB_CONFIG /usr/local/etc/openldap/

# Install OpenLDAP Server, give it permissionst to bind to low ports
RUN yum install -y openldap openldap-servers openldap-clients && \
    yum clean all -y && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/slapd && \
    mkdir -p /var/lib/ldap && \
    chmod a+rwx -R /var/lib/ldap && \
    mkdir -p /etc/openldap && \
    chmod a+rwx -R /etc/openldap && \
    mkdir -p /var/run/openldap && \
    chmod a+rwx -R /var/run/openldap && \
    chmod -R a+rw /opt/openshift 

# Set OpenLDAP data and config directories in a data volume
VOLUME ["/var/lib/ldap", "/etc/openldap"]

# Expose default ports for ldap and ldaps
EXPOSE 389 636

CMD ["/usr/local/bin/run-openldap.sh"]
