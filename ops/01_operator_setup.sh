#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

WORKDIR="/home/app/"
ASSETS="${WORKDIR}assets/"
LOGS="${WORKDIR}logs/"

LOG_PROVISION="${LOGS}provision.log"
LOG_CERTIFICATES="${LOGS}certificates.log"
LOG_FILES_CREATED="${LOGS}files_created.log"

# Create necessary directories to operate
mkdir -p ${ASSETS}
mkdir -p ${LOGS}

PATH=$PATH:/home/app/bin

## Instruqt compatibility
if [[ ! -z "${INSTRUQT_PARTICIPANT_ID}" ]]; then
    FQDN_SUFFIX=".$INSTRUQT_PARTICIPANT_ID.svc.cluster.local"
else
    FQDN_SUFFIX=""
fi

SSH_OPTS="StrictHostKeyChecking=accept-new"

# ++-----------------+
# || Functions       |
# ++-----------------+

print_env() {
  if [ ! -z $1 ] ; then

    if [[ -f "${ASSETS}/env-$1.conf" ]] && [[ -s "${ASSETS}/env-$1.conf" ]] ;  then

      cat ${ASSETS}/env-$1.conf

    elif [ "$1" == "consul" ]; then

      ## If the environment file does not exist prints current variables
      ## This is used to export them in a file afted defining them in the script.
      echo " export CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
      echo " export CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}"
      echo " export CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL}"
      echo " export CONSUL_CACERT=${CONSUL_CACERT}"
      echo " export CONSUL_TLS_SERVER_NAME=${CONSUL_TLS_SERVER_NAME}"
      echo " export CONSUL_FQDN_ADDR=${CONSUL_FQDN_ADDR}"

    elif [ "$1" == "vault" ]; then

      echo " export VAULT_ADDR=${VAULT_ADDR}"
      echo " export VAULT_TOKEN=${VAULT_TOKEN}"

    fi

  else
    # If no argument is passed prints all available environment files
    for env_file in `find ${ASSETS} -name env-*`; do
      
      echo -e "\033[1m\033[31mENV: ${env_file}\033[0m"
      cat ${env_file}
      echo ""
    done
  fi
}

# Waits for a node with hostname passed as an argument to be resolvable
wait_for() {

  _HOSTNAME=$1

  _NODE_IP=`dig +short $1`

  while [ -z ${_NODE_IP} ]; do

    log_warn "$1 not running yet"

    _NODE_IP=`dig +short $1`
  
  done

}

run_locally() {
  echo "Run command and log on files"
}

run_on() {
  echo "Run command and log on files"
}

source_and_log() {
    echo "Source file and log on files"
}

get_created_files() {

  echo "------------------------------------------------"  >> ${LOG_FILES_CREATED}
  echo " Module $H1 - Files Created"                       >> ${LOG_FILES_CREATED}
  echo "-----------------------------------------------"   >> ${LOG_FILES_CREATED}
  echo ""                                                  >> ${LOG_FILES_CREATED}

  find ${ASSETS} -type f -newer ${TSTAMP_MARKER} | sort >> ${LOG_FILES_CREATED}

  echo ""                                                  >> ${LOG_FILES_CREATED}

  if [[ ! -z "$1" ]] && [[ "$1" == "--verbose" ]] ; then

    echo -e "\033[1m\033[31mFILES CREATED IN THIS MODULE:\033[0m"
    find ${ASSETS} -type f -newer ${TSTAMP_MARKER} | sort
    echo ""

  fi

  touch -t `date '+%Y%m%d%H%M.%S'` ${TSTAMP_MARKER}

  sleep 1

}

# ++-----------------+
# || Begin           |
# ++-----------------+

# Check if start filebrowser on operator
if [ "${START_FILE_BROWSER}" == true ]; then
  log "Starting filebrowser on operator"
  LOG_FILEBROWSER="${LOGS}filebrowser.log"
  nohup filebrowser > ${LOG_FILEBROWSER} 2>&1 &
fi



