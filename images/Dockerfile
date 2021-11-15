FROM fedora:35

# OpenLDAP server image for OpenShift Origin
#
# Volumes:
# * /var/lib/ldap/data - Datastore for OpenLDAP
# * /etc/openldap/     - Config directory for slapd
# Environment:
# * $OPENLDAP_ADMIN_PASSWORD         - OpenLDAP administrator password
# * $OPENLDAP_DEBUG_LEVEL (Optional) - OpenLDAP debugging level, defaults to 256

LABEL io.k8s.description="OpenLDAP is an open source implementation of the Lightweight Directory Access Protocol." \
      io.openshift.expose-services="389:ldap,636:ldaps" \
      io.openshift.tags="directory,ldap,openldap" \
      io.openshift.non-scalable="true"

# Add defaults for config
COPY ./contrib/config /opt/openshift/config
COPY ./contrib/lib /opt/openshift/lib

# Add startup scripts
COPY ./contrib/run-*.sh /usr/local/bin/
COPY ./contrib/*.ldif /usr/local/etc/openldap/
COPY ./contrib/*.schema /usr/local/etc/openldap/
COPY ./contrib/DB_CONFIG /usr/local/etc/openldap/

# Add test query
COPY test/test.ldif /test/test.ldif

# Install OpenLDAP Server, give it permissionst to bind to low ports
RUN yum install -y \
        openldap \
        openldap-servers \
        openldap-clients \
        openssl \
        procps-ng && \
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
