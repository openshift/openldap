#!/bin/bash
set -x 

# Wait for daemon
sleep 15

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