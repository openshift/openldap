#!/usr/bin/env bash
#
# Test the OpenLDAP image.
#
# IMAGE specifies the test_name of the candidate image used for testing.
# The image has to be available before this script is executed.
#

set -eo nounset
shopt -s nullglob

IMAGE=${IMAGE:-openshift/openldap-candidate}
RUNTIME=${RUNTIME:-podman}

function cleanup() {
  local network_name=$1
  local container_names="$2 $3"

  $RUNTIME network rm -f "$network_name"

  for container in $container_names
  do
    echo "Stopping and removing container $container..."

    $RUNTIME stop "$container"
    exit_status=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$container")
    if [ "$exit_status" != "0" ]; then
      echo "Dumping logs for $container"
      $RUNTIME logs "$container"
    fi

    $RUNTIME rm "$container"
    echo "Done."

  done
}

function test_connection() {
  local client_name=$1
  local server_name=$2
  local max_attempts=20
  local sleep_time=2

  echo "  Testing OpenLDAP connection to $server_name..."

  for _ in $(seq $max_attempts); do
    echo "    Trying to connect..."

    set +e
    $RUNTIME container exec "$client_name" \
      ldapsearch -x \
        -h "$server_name" -p 389 \
        -b dc=example,dc=com objectClass="*"
    status=$?
    set -e

    if [ $status -eq 0 ]; then
      echo "  Success!"
      return 0
    fi

    sleep $sleep_time
  done

  echo "  Giving up: Failed to connect. Logs:"
  $RUNTIME logs "$client_name"

  return 1
}

function test_openldap() {
  local client_name=$1
  local server_name=$2
  echo "  Testing OpenLDAP"

  $RUNTIME container exec "$client_name" \
    ldapsearch -x -LLL \
      -h "$server_name" -p 389 \
      -b dc=example,dc=com objectClass=organization \
      | grep "dc=example,dc=com"

  $RUNTIME container exec "$client_name" \
    ldapadd -x \
      -h "$server_name" -p 389 \
      -D cn=Manager,dc=example,dc=com -w admin \
      -f test/test.ldif

  $RUNTIME container exec "$client_name" \
    ldapsearch -x -LLL \
      -h "$server_name" -p 389 \
      -b cn=person,dc=example,dc=com memberof \
      | grep "dc=example,dc=com"

  echo "  Success!"
}

function create_container() {
  local container_name=$1
  local docker_args=$2

  $RUNTIME run $docker_args --name "$container_name" -d "$IMAGE"

  echo "Created container $container_name"
}

function run_tests() {
  local test_name=$1
  local additional_args=$2
  local timestamp=$(date '+%s')
  local client_name="ldap_client_$timestamp"
  local server_name="ldap_server_$timestamp"
  local network_name="ldap_net_$timestamp"

  trap 'cleanup $client_name $server_name' SIGINT

  echo "#######################################"
  echo "# Test Case: $test_name"
  echo "#######################################"

  $RUNTIME network create -d bridge "$network_name"

  create_container "$client_name" "--network $network_name $additional_args"
  create_container "$server_name" "--network $network_name $additional_args"

  test_connection "$client_name" "$server_name"
  test_openldap "$client_name" "$server_name"

  echo "  Test Success!"
  echo "#######################################"

  cleanup "$client_name" "$server_name"
}

# Tests.
run_tests "root" " "
run_tests "rootless" "-u 12345"
