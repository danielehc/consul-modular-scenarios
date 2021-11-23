#!/usr/bin/env bash

## Builds images for lab
## Image structure
## BASE: danielehc/consul-instruqt-base
## VERSION: The version for the image corresponds on the Consul version installed

# ++-----------------+
# || Functions       |
# ++-----------------+

## LOGGING
ts_log() {
  echo -e "\033[1m["$(date +"%Y-%m-%d %H:%M:%S")"] - ${@}\033[0m"
}


## Returns the lates compatible envoy version for the Consul version passed as argument
function get_envoy_version() {

    CONSUL_VER=$1

    CONSUL_VER=`echo ${CONSUL_VER} | sed 's/\.[0-9]*$//g'`

    ENVOY_VER=`wget https://www.consul.io/docs/connect/proxies/envoy -q -O - | \
                grep -o "<tbody>.*</tbody>" | sed -e 's/<\/td>/;/g' | \
                sed -e 's/<\/tr>/\n/g' | \
                sed -e 's/<[^>]*>//g' | \
                grep -e "^${CONSUL_VER}" | \
                sed -e 's/^[^;]*;//g' | \
                sed -e 's/,.*//g'`
    
    echo ${ENVOY_VER}
}

function get_latest_consul_version() {

	CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
    if [ -z "$1" ] || [ "$1" == "latest" ] ; then
        CONSUL_VER=$(curl -s "${CHECKPOINT_URL}"/consul | jq .current_version | tr -d '"')
    fi

	echo "${CONSUL_VER}"
}

function get_latest_app_version() {

    APP_NAME=$1

    APP_VER=`wget -q https://registry.hub.docker.com/v1/repositories/$1/tags -O -  | \
            jq -r ".[].name"  | \
            sort -Vr | \
            grep -e "^v[0-9]*\.[0-9]*\.[0-9]*" | \
            head -1  | sed 's/^v//g'`
    
    echo $APP_VER
}

# ++-----------------+
# || Variables       |
# ++-----------------+

## FLOW
# Directory for building
BUILD_DIR=${1:-"./"}
# Generates new certificates at every run
GEN_NEW_CERTS=${GEN_NEW_CERTS:-true}
# Push images after build
PUSH_IMG=${PUSH_IMG:-true}

# Only builds images locally no push to docker hub
ONLY_BUILD=${ONLY_BUILD:-false}

## DOCKER
DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-"danielehc"}
DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE:-"consul-instruqt-base"}

### VERSIONS
## HashiCorp tools
CONSUL_VERSION=${CONSUL_VERSION:-"latest"}
ASSIGN_LATEST=false
# CONSUL_VERSION=${CONSUL_VERSION:-`get_latest_consul_version`}
# CONSUL_TAG_VERSION=`echo ${CONSUL_VERSION} | sed 's/+/-/g'`

# VAULT_VERSION="latest"

# ## 3rd party
# ENVOY_VERSION=${ENVOY_VERSION:-`get_envoy_version ${CONSUL_VERSION}`}
# FAKEAPP_VERSION=${FAKEAPP_VERSION:-"0.22.7"}

# ## HashiCups
# HC_FRONTEND_VERSION=${HC_FRONTEND_VERSION:-`get_latest_app_version hashicorpdemoapp/frontend`}
# HC_PAYMENTS_VERSION=${HC_PAYMENTS_VERSION:-`get_latest_app_version hashicorpdemoapp/payments`}
# HC_PRODUCT_API_VERSION=${HC_PRODUCT_API_VERSION:-`get_latest_app_version hashicorpdemoapp/product-api`}
# HC_PRODUCT_DB_VERSION=${HC_PRODUCT_DB_VERSION:-`get_latest_app_version hashicorpdemoapp/product-api-db`}
# HC_PUBLIC_API_VERSION=${HC_PUBLIC_API_VERSION:-`get_latest_app_version hashicorpdemoapp/public-api`}

# ++-----------------+
# || Begin           |
# ++-----------------+

pushd ${BUILD_DIR}base

## Generate SSH Keys
KEYS_DIR="./ssh"

# Check if the ssh folder for SSH keys exists
if [ -d "${KEYS_DIR}" ] ; then

  # If GEN_NEW_CERTS set to true remove existing certificates
  if [ "${GEN_NEW_CERTS}" == true ]; then
    rm -rf ${KEYS_DIR}/*
  fi

  if [ "$(ls -A ${KEYS_DIR})" ]; then
    ts_log "Certificates found in ${KEYS_DIR}"
  else
    ts_log "Creating certificates in ${KEYS_DIR}"

    pushd ${KEYS_DIR}
    ssh-keygen -t rsa -b 4096 -f ./id_rsa -N ""
    popd 
  fi
fi

ts_log "Checking application versions"

## Check if needs to assign tag latest
CONSUL_LAST_VER=`get_latest_consul_version`

if [ "${CONSUL_VERSION}" == "latest" ]; then

  ASSIGN_LATEST=true
  CONSUL_VERSION="${CONSUL_LAST_VER}"
  LATEST_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"

elif [ "${CONSUL_VERSION}" == "${CONSUL_LAST_VER}" ]; then

  ASSIGN_LATEST=true
  LATEST_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"
fi

CONSUL_TAG_VERSION=`echo ${CONSUL_VERSION} | sed 's/+/-/g'`

## Setting up other bins versions
VAULT_VERSION="latest"
ENVOY_VERSION=${ENVOY_VERSION:-`get_envoy_version ${CONSUL_VERSION}`}
FAKEAPP_VERSION=${FAKEAPP_VERSION:-`get_latest_app_version nicholasjackson/fake-service`}

echo -e "- \033[1m\033[31m[Consul]\033[0m: ${CONSUL_VERSION}"
echo -e "- \033[1m\033[35m[Envoy]\033[0m: ${ENVOY_VERSION}"
echo -e "- \033[1m\033[33m[Vault]\033[0m: ${VAULT_VERSION}"
echo -e "- \033[1m\033[34m[FakeApp]\033[0m: ${FAKEAPP_VERSION}"

## Build image

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}\033[0m"

DOCKER_BUILDKIT=1 docker build \
  --build-arg CONSUL_VERSION=${CONSUL_VERSION} \
  --build-arg ENVOY_VERSION=v${ENVOY_VERSION} \
  --build-arg FAKEAPP_VERSION=v${FAKEAPP_VERSION} \
  -t "${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}" ${LATEST_TAG} . > /dev/null 2>&1

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}...exiting."
  popd
  exit 1
fi

if [ "${ONLY_BUILD}" == false ]; then
  ## Push Image
  if [ "${PUSH_IMG}" == true ]; then
    ts_log "Pushing \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}\033[0m"
    docker push "${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}" > /dev/null 2>&1

    if [ $? != 0 ]; then
      ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed push for ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}"
    fi

    if [ "${ASSIGN_LATEST}" == true ]; then
      ts_log "Pushing \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest\033[0m"
      docker push "${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest" > /dev/null 2>&1

      if [ $? != 0 ]; then
        ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed push for ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"
      fi
    fi
  fi
fi
popd

## BUILDING HASHICUPS IMAGES

for folder in ${BUILD_DIR}hashicups-*; do

  if [[ -d "$folder" && ! -L "$folder" && "$folder" && -f "$folder/Dockerfile" ]]; then

    pushd ${folder}

    IMAGE_NAME=`echo ${folder} | sed 's/.*hashicups-//g'`

    APP_VERSION=`get_latest_app_version hashicorpdemoapp/${IMAGE_NAME}`
    
    ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${IMAGE_NAME}:v${APP_VERSION}\033[0m"

    DOCKER_BUILDKIT=1 docker build \
      --build-arg BASE_VERSION="v${CONSUL_VERSION}" \
      --build-arg APP_VERSION="v${APP_VERSION}" \
      -t "${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:v${APP_VERSION}" \
      -t "${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:latest" . > /dev/null 2>&1

    if [ $? != 0 ]; then
      ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:v${APP_VERSION}...exiting."
      popd
      exit 1
    fi

    if [ "${ONLY_BUILD}" == false ]; then
      ts_log "Pushing \033[1m\033[33m${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:v${APP_VERSION}\033[0m"
      docker push "${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:v${APP_VERSION}" > /dev/null 2>&1

      if [ $? != 0 ]; then
        ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed push for ${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:v${APP_VERSION}"
      fi

      ts_log "Pushing \033[1m\033[33m${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:latest\033[0m"
      docker push "${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:latest" > /dev/null 2>&1

      if [ $? != 0 ]; then
        ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed push for ${DOCKER_REPOSITORY}/hashicups-${IMAGE_NAME}:latest"
      fi
    fi
    popd

  fi

done