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

  ## Containers have a user named `app` with UID=1000 and GID=1000 
  # USER="$(id -u):$(id -g)"
  USER="1000:1000"

  log "Starting container $1"

  docker run \
  -d \
  --net ${CONTAINER_NET} \
  --user ${USER} \
  --name=${CONTAINER_NAME} \
  --hostname=${CONTAINER_NAME} \
  --label tag=${DK_TAG} ${EXTRA_PARAMS}\
  ${IMAGE} > /dev/null 2>&1

  if [ $? != 0 ]; then
    log_err "Failed startup for container $1. Exiting."
    exit 1
  fi 
}

operate_modular() { 

  mkdir -p ${ASSETS}scripts

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

build() {
  
  ########## ------------------------------------------------
  header1     "BUILDING DOCKER IMAGES"
  ###### -----------------------------------------------
  ./images/batch_build.sh $1

  if [ $? != 0 ]; then
    log_err "Build failed. Exiting."
    exit 1
  fi
}

print_available_services() {

  echo -e "\033[1m\033[31mFILES CREATED IN THIS MODULE:\033[0m"
    find ${ASSETS} -type f -newer ${TSTAMP_MARKER} | sort
  echo ""

  if [ "${EXPOSE_CONTAINER_PORTS}" == true ]; then 

  echo pippo

  fi

}

print_available_configs() {

  for i in `docker exec -it operator /bin/bash -c "find ~/assets -type f -name \"${1:-*}\" | sort"`; do

    REPLACEMENT_URL="/home/app"

    if [ "${START_FILE_BROWSER}" == true ] ; then

      if [ "${EXPOSE_CONTAINER_PORTS}" == true ]; then 

        REPLACEMENT_URL="http://localhost:7777/files"
      else
        REPLACEMENT_URL="http://`docker inspect operator --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`:7777/files"
      fi
    fi

    echo ${REPLACEMENT_URL}$(echo $i | sed 's/\/home\/app//g')

  done

}

# ++-----------------+
# || Variables       |
# ++-----------------+

# --- GLOBAL VARS AND FUNCTIONS ---
source ops/00_global_vars.env

# --------------------
# --- FLOW CONTROL ---
# --------------------

## Build docker imgages on startup
## TODO: Make it count
BUILD_ON_STARTUP=false

## Generate new certificates
export GEN_NEW_CERTS=false

# --------------------
# ------ CONSUL ------
# --------------------
CONSUL_VERSION=${CONSUL_VERSION:="latest"}
VAULT_VERSION="latest"

# --------------------
# ------ DOCKER ------
# --------------------

# ${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}
DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-"danielehc"}
IMAGE_NAME_BASE="consul-instruqt-base"
IMAGE_TAG=v${CONSUL_VERSION}

GENERATE_MULTIPLE_NETWORKS=false

## If true will expose to host some of the container ports
EXPOSE_CONTAINER_PORTS=true

# For OSes different than Linux ports are exposed automatically
if [ `is_linux` != "true" ] ; then
  EXPOSE_CONTAINER_PORTS=true
fi

## Docker tag for resources
DK_TAG="instruqt"
DK_NET="instruqt-net"

# --------------------
# --- ENVIRONMENT ----
# --------------------

ASSETS="assets/"

## Comma separates string of prerequisites
PREREQUISITES="docker,wget,jq,grep,sed,tail,awk"

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
elif [ "$1" == "services" ]; then
  print_available_services
  exit 0
elif [ "$1" == "configs" ]; then
  print_available_configs $2
  exit 0
elif [ "$1" == "build" ]; then
  export CONSUL_VERSION
  # export DOCKER_REPOSITORY
  build "./images/"
  exit 0
elif [ "$1" == "build_only" ]; then
  export CONSUL_VERSION
  export ONLY_BUILD=true
  # export DOCKER_REPOSITORY
  build "./images/"
  exit 0
fi


## Clean environment
log "Cleaning Environment"
clean_env

########## ------------------------------------------------
header1     "PROVISIONING PREREQUISITES"
###### -----------------------------------------------

## Checking Prerequisites
log "Checking prerequisites..."
for i in `echo ${PREREQUISITES} | sed 's/,/ /g'` ; do
  prerequisite_check $i
done

## Create network
log "Creating Network ${DK_NET}"
docker network create ${DK_NET} --subnet=172.20.0.0/24 --label tag=${DK_TAG}

# log "Starting Vault"
EXTRA_PARAMS="-e 'VAULT_DEV_ROOT_TOKEN_ID=password'"
if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ] ; then
  EXTRA_PARAMS="-p 8200:8200 ${EXTRA_PARAMS}"
fi

spin_container_param "vault" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"

# log "Starting Operator"
EXTRA_PARAMS=""
if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ] ; then
  EXTRA_PARAMS="-p 7777:7777 ${EXTRA_PARAMS}"
fi
spin_container_param "operator" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"

EXTRA_PARAMS=""

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

    EXTRA_PARAMS=""
    if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ] && [ "${serv}" -eq 1 ] && [ "${dc}" == ${PRIMARY_DATACENTER} ]; then
      EXTRA_PARAMS="-p 1443:443 ${EXTRA_PARAMS}"
    fi

    # log "Starting Consul server consul-server-$dc-$serv"
    spin_container_param "consul-server-$dc-$serv" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"

    EXTRA_PARAMS=""
  done

  if (( ${#SERVICES[@]} )); then
    ########## ------------------------------------------------
    header2     "PROVISIONING SERVICES NODES: $dc"
    ###### -----------------------------------------------

    for svc in "${SERVICES[@]}" ; do

      if [ "${SVC_MATCH_IMAGE_NAME}" == true ]; then
        IMAGE_NAME="hashicups-${svc}"
        IMG_TAG="latest"
      else
        IMAGE_NAME=${IMAGE_NAME_BASE}
        IMG_TAG=${IMAGE_TAG}
      fi

      # log "Starting Consul client svc-$dc-$svc"
      EXTRA_PARAMS=""
      if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ] && [ "${svc}" == "frontend" ] ; then
        EXTRA_PARAMS="-p 8888:80 ${EXTRA_PARAMS}"
      fi
      spin_container_param "svc-$dc-$svc" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME}:${IMG_TAG}" "${EXTRA_PARAMS}"

      EXTRA_PARAMS=""

    done
  fi

  if (( ${#MESH_ELEMENTS[@]} )); then
    ########## ------------------------------------------------
    header2     "PROVISIONING MESH ELEMENTS NODES: $dc"
    ###### -----------------------------------------------

    for gw in "${MESH_ELEMENTS[@]}" ; do

      # log "Starting Consul client mesh-$dc-$gw"
      spin_container_param "mesh-$dc-$gw" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}"

    done
  fi
done

