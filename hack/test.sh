#!/usr/bin/env bash
#
# Test the OpenLDAP image.
#
# IMAGE specifies the name of the candidate image used for testing.
# The image has to be available before this script is executed.
#

set -eo nounset
shopt -s nullglob

IMAGE=${IMAGE:-openshift/openldap-candidate}
RUNTIME=${RUNTIME:-podman}

CIDFILE_DIR=$(mktemp --suffix=openldap_test_cidfiles -d)

function cleanup() {
  for cidfile in $CIDFILE_DIR/* ; do
    CONTAINER=$(cat $cidfile)
    echo "Stopping and removing container $CONTAINER..."

    $RUNTIME stop $CONTAINER
    exit_status=$($RUNTIME inspect -f '{{.State.ExitCode}}' $CONTAINER)
    if [ "$exit_status" != "0" ]; then
      echo "Dumping logs for $CONTAINER"
      $RUNTIME logs $CONTAINER
    fi
    $RUNTIME rm $CONTAINER
    rm $cidfile
    echo "Done."
  done

  rmdir $CIDFILE_DIR
}

function get_cid() {
  local id="$1" ; shift || return 1

  cat "$CIDFILE_DIR/$id"
}

function test_connection() {
  local name=$1
  local port=$2
  echo "  Testing OpenLDAP connection to localhost:$port..."

  local max_attempts=20
  local sleep_time=2
  for _ in $(seq $max_attempts); do
    echo "    Trying to connect..."
    set +e
    ldapsearch -x -h localhost -p $port -b dc=example,dc=com objectClass=*
    status=$?
    set -e
    if [ $status -eq 0 ]; then
      echo "  Success!"
      return 0
    fi
    sleep $sleep_time
  done
  echo "  Giving up: Failed to connect. Logs:"
  $RUNTIME logs "$(get_cid $name)"

  return 1
}

function test_openldap() {
  local port=$1
  echo "  Testing OpenLDAP"

  ldapsearch -x -LLL -h localhost -p $port -b dc=example,dc=com objectClass=organization | grep "dc=example,dc=com"
  ldapadd -x -h localhost -p $port -D cn=Manager,dc=example,dc=com -w admin -f test/test.ldif
  ldapsearch -x -LLL -h localhost -p $port -b cn=person,dc=example,dc=com memberof | grep "dc=example,dc=com"

  echo "  Success!"
}

function create_container() {
  local name=$1
  local port=$2

  cidfile="$CIDFILE_DIR/$name"
  # create container with a cidfile in a directory for cleanup
  $RUNTIME run ${DOCKER_ARGS:-} -p $port:389 --cidfile $cidfile -d $IMAGE ${CONTAINER_ARGS:-}

  echo "Created container $(cat $cidfile)"
}


function run_tests() {
  local name=$1
  local port=$2

  echo "#######################################"
  echo "# Test Case: $name"
  echo "#######################################"

  create_container $name $port
  test_connection $name $port
  test_openldap $port

  echo "  Test Success!"
  echo "#######################################"
}

trap cleanup EXIT SIGINT

# Tests.
run_tests test_container_root 8489
DOCKER_ARGS="-u 12345" run_tests test_container_non_root 8389
