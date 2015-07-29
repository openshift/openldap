#!/bin/bash
set -x 

# Wait for daemon
for ((i=30; i>0; i--))
do
    ping_result=`ldapsearch "objectClass=*" 2>&1 | grep -Po "Can.t contact LDAP server"`
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

# Assumptions:
OPENLDAP_ROOT_DN="cn=Manager,dc=example,dc=com"
OPENLDAP_ROOT_PW="admin"

# Only do setup if it has not yet been done
if [ ! -f /etc/openldap/INITIALIZED ]
then
	# Add test users and groups to the server
	ldapadd -x -D $OPENLDAP_ROOT_DN -w $OPENLDAP_ROOT_PW -f /usr/local/etc/openldap/init.ldif

	touch /etc/openldap/INITIALIZED
fi