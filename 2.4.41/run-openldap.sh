#!/bin/bash

set -x

# Reduce maximum number of number of open file descriptors to 1024
# otherwise slapd consumes two orders of magnitude more of RAM
# see https://github.com/docker/docker/issues/8231
ulimit -n 1024

OPENLDAP_ROOT_PASSWORD=${OPENLDAP_ROOT_PASSWORD:-admin}
OPENLDAP_ROOT_DN_RREFIX=${OPENLDAP_ROOT_DN_RREFIX:-'cn=Manager'}
OPENLDAP_ROOT_DN_SUFFIX=${OPENLDAP_ROOT_DN_SUFFIX:-'dc=example,dc=com'}
OPENLDAP_DEBUG_LEVEL=${OPENLDAP_DEBUG_LEVEL:-256}

# Only run if no config has happened fully before
if [ ! -f /etc/openldap/CONFIGURED ]; then

    user=`id | grep -Po "(?<=uid=)\d+"`
    if (( user == 0 ))
    then
        # We are root, we can use user input!
        # Bring in default databse config
        cp /usr/local/etc/openldap/DB_CONFIG /var/lib/ldap/DB_CONFIG

        # start the daemon in another process and make config changes
        slapd -h "ldap:/// ldaps:/// ldapi:///" -d $OPENLDAP_DEBUG_LEVEL &
        for ((i=30; i>0; i--))
        do
            ping_result=`ldapsearch 2>&1 | grep "Can.t contact LDAP server"`
            if [ -z "$ping_result" ]
            then
                break
            fi
            sleep 1
        done
        if [ $i -eq 0 ]
        then
            echo "slapd did not start correctly"
            exit 1
        fi

        # Generate hash of password
        OPENLDAP_ROOT_PASSWORD_HASH=$(slappasswd -s "${OPENLDAP_ROOT_PASSWORD}")

        # Update configuration with root password, root DN, and root suffix
        sed -e "s OPENLDAP_ROOT_PASSWORD ${OPENLDAP_ROOT_PASSWORD_HASH} g" \
            -e "s OPENLDAP_ROOT_DN ${OPENLDAP_ROOT_DN_RREFIX} g" \
            -e "s OPENLDAP_SUFFIX ${OPENLDAP_ROOT_DN_SUFFIX} g" /usr/local/etc/openldap/first_config.ldif |
            ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_DEBUG_LEVEL

        # add useful schemas
        ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif -d $OPENLDAP_DEBUG_LEVEL
        ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif -d $OPENLDAP_DEBUG_LEVEL

        # load memberOf and refint modules
        ldapadd -Y EXTERNAL -H ldapi:/// -f /usr/local/etc/openldap/load_modules.ldif -d $OPENLDAP_DEBUG_LEVEL
        
        # configure memberOf module
        ldapadd -Y EXTERNAL -H ldapi:/// -f /usr/local/etc/openldap/memberof_configure.ldif -d $OPENLDAP_DEBUG_LEVEL

        # configure refint module
        ldapadd -Y EXTERNAL -H ldapi:/// -f /usr/local/etc/openldap/refint_configure.ldif -d $OPENLDAP_DEBUG_LEVEL

        # extract dc name from root DN suffix
        dc_name=$(echo "${OPENLDAP_ROOT_DN_SUFFIX}" | grep -Po "(?<=^dc\=)[\w\d]+")
        # create base organization object
        sed -e "s OPENLDAP_SUFFIX ${OPENLDAP_ROOT_DN_SUFFIX} g" \
            -e "s FIRST_PART ${dc_name} g" \
            usr/local/etc/openldap/base.ldif |
            ldapadd -x -D "$OPENLDAP_ROOT_DN_RREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"

        # stop the daemon
        pid=$(ps -A | grep slapd | awk '{print $1}')
        kill -2 $pid || echo $?
        
        # ensure the daemon stopped
        for ((i=30; i>0; i--))
        do
            exists=$(ps -A | grep $pid)
            if [ -z "${exists}" ]
            then
                break
            fi
            sleep 1
        done
        if [ $i -eq 0 ]
        then
            echo "slapd did not stop correctly"
            exit 1
        fi
    else
        # We are not root, we need to populate from the default blind-mount source 
        if [ -f /opt/openshift/config/slapd.d/cn\=config/olcDatabase\=\{0\}config.ldif ]
        then
            # Use provided default config, get rid of current data
            rm -rf /var/lib/ldap/*
            rm -rf /etc/openldap/*
            # Bring in associated default database files
            mv -f /opt/openshift/lib/* /var/lib/ldap
            mv -f /opt/openshift/config/* /etc/openldap
        else
            # Something has gone wrong with our image build
            echo "FAILURE: Default configuration files from /contrib/ are not present in the image at /opt/oepnshift."
            exit 1
        fi
    fi

    # Test configuration files, log checksum errors. Errors may be tolerated and repaired by slapd so don't exit
    LOG=`slaptest 2>&1`
    CHECKSUM_ERR=$(echo "${LOG}" | grep -Po "(?<=ldif_read_file: checksum error on \").+(?=\")")
    for err in $CHECKSUM_ERR
    do
        echo "The file ${err} has a checksum error. Ensure that this file is not edited manually, or re-calculate the checksum."
    done

    rm -rf /opt/openshift/*

    touch /etc/openldap/CONFIGURED
fi

# Start the slapd service
exec slapd -h "ldap:/// ldaps:///" -d $OPENLDAP_DEBUG_LEVEL