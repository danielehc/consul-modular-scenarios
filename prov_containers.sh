#! /bin/bash
# set -x

# ++-----------------+
# || Functions       |
# ++-----------------+

clean_env() {

  if [[ $(docker ps -aq --filter label=tag=${DK_TAG}) ]]; then
    docker rm -f $(docker ps -aq --filter label=tag=${DK_TAG})
  fi

  if [[ $(docker volume ls -q --filter label=tag=${DK_TAG}) ]]; then
    docker volume rm $(docker volume ls -q --filter label=tag=${DK_TAG})
  fi

  if [[ $(docker network ls -q --filter label=tag=${DK_TAG}) ]]; then
    docker network rm $(docker network ls -q --filter label=tag=${DK_TAG})
  fi

  # ## Remove custom scripts
  rm -rf ${ASSETS}scripts/*

  # ## Remove certificates 
  # rm -rf ${ASSETS}secrets

  # ## Remove data 
  # rm -rf ${ASSETS}data

  # ## Remove logs
  # rm -rf ${LOGS}/*
  
  ## Unset variables
  unset CONSUL_HTTP_ADDR
  unset CONSUL_HTTP_TOKEN
  unset CONSUL_HTTP_SSL
  unset CONSUL_CACERT
  unset CONSUL_CLIENT_CERT
  unset CONSUL_CLIENT_KEY
}

## spin_container_param NAME NETWORK IMAGE_NAME:IMAGE_TAG EXTRA_DOCKER_PARAMS
## NAME: Name of the container and hostname of the node
## NETWORK: Docker network the container will run into
## IMAGE_NAME:IMAGE_TAG: Docker image and version to run
## EXTRA_DOCKER_PARAMS: The following tring gets paseed as is as Docker command params
spin_container_param() {
  CONTAINER_NAME=$1
  CONTAINER_NET=$2
  IMAGE=$3
  EXTRA_PARAMS=$4

  log "Starting container $1"

  docker run \
  -d \
  --net ${CONTAINER_NET} \
  --user $(id -u):$(id -g) \
  --name=${CONTAINER_NAME} \
  --hostname=${CONTAINER_NAME} \
  --label tag=${DK_TAG} ${EXTRA_PARAMS}\
  ${IMAGE} "" > /dev/null 2>&1
}

spin_container() {
  log "Starting container $1"

  docker run \
  -d \
  --net ${DK_NET} \
  --user $(id -u):$(id -g) \
  --name=$1 \
  --hostname=$1 \
  --label tag=${DK_TAG} \
  ${IMAGE_NAME}:${IMAGE_TAG} "" > /dev/null 2>&1
}

operate() {
  # Copy script to operator container

  docker cp ./operate.sh operator:/home/app/operate.sh
  
  # Run script
  # docker exec -it operator "chmod +x /home/app/operate.sh"
  docker exec -it operator "/home/app/operate.sh"
}

operate_modular() { 

  for i in `find ops/*` ; do
    cat $i >> ${ASSETS}scripts/operate.sh
  done

  chmod +x ${ASSETS}scripts/operate.sh

  # Copy script to operator container
  docker cp ${ASSETS}scripts/operate.sh operator:/home/app/operate.sh
  
  # Run script
  # docker exec -it operator "chmod +x /home/app/operate.sh"
  docker exec -it operator "/home/app/operate.sh"

}

login() {
  docker exec -it $1 /bin/bash
}

# ++-----------------+
# || Variables       |
# ++-----------------+

# --- GLOBAL VARS AND FUNCTIONS ---
source ops/00_global_vars.env

# --- CONSUL ---


CONSUL_VERSION=${CONSUL_VERSION:="1.10.3"}
VAULT_VERSION="latest"

# --- DOCKER IMAGE ---
IMAGE_NAME=danielehc/consul-instruqt-base
IMAGE_TAG=v${CONSUL_VERSION}

# --- ENVIRONMENT ---

ASSETS="assets/"

## Docker tag for resources
DK_TAG="instruqt"
DK_NET="instruqt-net"

GENERATE_MULTIPLE_NETWORKS=false

# ++-----------------+
# || Begin           |
# ++-----------------+

## Check Parameters
if   [ "$1" == "clean" ]; then
  clean_env
  exit 0
elif [ "$1" == "operate" ]; then
  operate_modular
  exit 0
elif [ "$1" == "login" ]; then
  login $2
  exit 0
fi

## Clean environment
log "Cleaning Environment"
clean_env

########## ------------------------------------------------
header1     "PROVISIONING PREREQUISITES"
###### -----------------------------------------------

## Create network
log "Creating Network ${DK_NET}"
docker network create ${DK_NET} --subnet=172.20.0.0/24 --label tag=${DK_TAG}

# log "Starting Vault"
spin_container_param "vault" "${DK_NET}" "${IMAGE_NAME}:${IMAGE_TAG}" "-e 'VAULT_DEV_ROOT_TOKEN_ID=password'"

# log "Starting Operator"
spin_container_param "operator" "${DK_NET}" "${IMAGE_NAME}:${IMAGE_TAG}"

## now loop through the above array
for dc in "${DATACENTERS[@]}" ; do

  if [ "${PRIMARY_DATACENTER}" == $dc ]; then

    ########## ------------------------------------------------
    header1     "PROVISIONING PRIMARY DATACENTER: $dc"
    ###### -----------------------------------------------

  else 

    ########## ------------------------------------------------
    header1     "PROVISIONING SECONDARY DATACENTER: $dc"
    ###### -----------------------------------------------

  fi

    ########## ------------------------------------------------
    header2     "PROVISIONING SERVER NODES: $dc"
    ###### -----------------------------------------------

    for serv in $(seq 1 ${SERVER_NUMBER}); do 

      # log "Starting Consul server consul-server-$dc-$serv"
      spin_container_param "consul-server-$dc-$serv" "${DK_NET}" "${IMAGE_NAME}:${IMAGE_TAG}"

    done

    if (( ${#SERVICES[@]} )); then
      ########## ------------------------------------------------
      header2     "PROVISIONING SERVICES NODES: $dc"
      ###### -----------------------------------------------

      for svc in "${SERVICES[@]}" ; do

        # log "Starting Consul client svc-$dc-$svc"
        spin_container_param "svc-$dc-$svc" "${DK_NET}" "${IMAGE_NAME}:${IMAGE_TAG}"

      done
    fi

    if (( ${#MESH_ELEMENTS[@]} )); then
      ########## ------------------------------------------------
      header2     "PROVISIONING MESH ELEMENTS NODES: $dc"
      ###### -----------------------------------------------

      for gw in "${MESH_ELEMENTS[@]}" ; do

        # log "Starting Consul client mesh-$dc-$gw"
        spin_container_param "mesh-$dc-$gw" "${DK_NET}" "${IMAGE_NAME}:${IMAGE_TAG}"

      done
    fi
done


