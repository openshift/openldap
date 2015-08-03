#!/bin/bash

set -x

# Reduce maximum number of number of open file descriptors to 1024
# otherwise slapd consumes two orders of magnitude more of RAM
# see https://github.com/docker/docker/issues/8231
ulimit -n 1024

ROOT_PW=${OPENLDAP_ROOT_PASSWORD:-admin}
ROOT_DN_PREFIX=${OPENLDAP_ROOT_DN_RREFIX:-'cn=Manager'}
ROOT_DN_SUFFIX=${OPENLDAP_ROOT_DN_SUFFIX:-'dc=example,dc=com'}
DEBUG_LEVEL=${OPENLDAP_DEBUG_LEVEL:-256}

# Only run if no config has happened fully before
if [ ! -f /etc/openldap/CONFIGURED ]; then

    # Bring in default databse config
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap:ldap /var/lib/ldap/DB_CONFIG 

    # Add LDAPS support if possible
    if [ -f /opt/openshift/certs/server.key ] &&
       [ -f /opt/openshift/certs/server.crt ] && 
       [ -f /opt/openshift/certs/ca-bundle.crt ]
    then
        mv -fv /opt/openshift/certs/* /etc/openldap/certs
    fi

    # start the daemon in another process and make config changes
    /usr/sbin/slapd -h "ldap:/// ldaps:/// ldapi:///" -u ldap -d $DEBUG_LEVEL &
    sleep 3

    # Generate hash of password
    ROOT_PASSWORD=$(slappasswd -s "${ROOT_PW}")

    # Update configuration with root password, root DN, and root suffix
    sed -e "s OPENLDAP_ROOT_PASSWORD ${ROOT_PASSWORD} g" \
        -e "s OPENLDAP_ROOT_DN ${ROOT_DN_PREFIX} g" \
        -e "s OPENLDAP_SUFFIX ${ROOT_DN_SUFFIX} g" /usr/local/etc/openldap/first_config.ldif |
        ldapmodify -Y EXTERNAL -H ldapi:/// 

    # Register LDAPS certs if present
    if [ -f /etc/openldap/certs/server.key ] &&
       [ -f /etc/openldap/certs/server.crt ] && 
       [ -f /etc/openldap/certs/ca-bundle.crt ]
    then
        ldapmodify -Y EXTERNAL -H ldapi:/// -f /usr/local/etc/openldap/ldaps_init.ldif
        # Update sysconfig for ldaps
        sed -i 's|^SLAPD_URLS*+$|SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"|g' /etc/sysconfig/slapd
        echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf 
    fi 

    # add useful schemas
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

    # create base organization object
    ldapadd -x -D "$ROOT_DN_PREFIX,$ROOT_DN_SUFFIX" -w "$ROOT_PW" -f /usr/local/etc/openldap/base.ldif

    # stop the daemon
    pid=$(ps -A | grep slapd | awk '{print $1}')
    kill -2 $pid || echo $?
    sleep 3
    # ensure the daemon stopped
    exists=$(ps -A | grep $pid)
    if [ -n "${exists}" ]
    then
        echo "slapd restart failed"
        exit 1
    fi

    # Test configuration files
    LOG=`slaptest 2>&1`
    CHECKSUM_ERR=$(echo "${LOG}" | grep -Po "(?<=ldif_read_file: checksum error on \").+(?=\")")
    for err in $CHECKSUM_ERR
    do
        echo "The file ${err} has a checksum error. Ensure that this file is not edited manually, or re-calculate the checksum."
    done

    rm -rf /opt/openshift

    touch /etc/openldap/CONFIGURED
fi

# Start the slapd service
exec /usr/sbin/slapd -h "ldap:/// ldaps:/// ldapi:///" -u ldap -d $DEBUG_LEVEL