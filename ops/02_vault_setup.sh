#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

VAULT_MAX_LEASE_ROOT_CA="87600h"
VAULT_MAX_LEASE_INT_CA="43800h"
VAULT_MAX_LEASE_CERT="720h"

# ++-----------------+
# || Functions       |
# ++-----------------+

get_sans() {

  CURRENT_DC=$1

  SANS_STRING=""

  for dc in "${DATACENTERS[@]}" ; do

    if [ ${dc} != ${CURRENT_DC} ]; then

      SANS_STRING="${SANS_STRING} *.${dc}.${DOMAIN},"
    fi
  done

  # Remove trailing commas
  echo ${SANS_STRING} | sed 's/,$//g'

}

get_server_sans() {
  CURRENT_DC=$1

  SANS_STRING=""

  for dc in "${DATACENTERS[@]}" ; do

    if [ ${dc} != ${CURRENT_DC} ]; then

      SANS_STRING="${SANS_STRING} server.${dc}.${DOMAIN},"
    fi
  done

  # Remove trailing commas
  echo ${SANS_STRING} | sed 's/,$//g'
}

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "START VAULT SERVER"
###### -----------------------------------------------

wait_for vault${FQDN_SUFFIX}

## Create folder structure
ssh -o ${SSH_OPTS} vault${FQDN_SUFFIX} \
  "mkdir -p ${WORKDIR}vault/config \
    && mkdir -p ${WORKDIR}vault/data \
    && mkdir -p ${WORKDIR}logs" > /dev/null 2>&1

# Start Vault in dev mode 
ssh -o ${SSH_OPTS} vault${FQDN_SUFFIX} \
  "export VAULT_DEV_ROOT_TOKEN_ID=password; /usr/local/bin/vault server -dev -dev-listen-address="0.0.0.0:8200" > ${WORKDIR}logs/vault.log 2>&1" &

export VAULT_ADDR="http://vault${FQDN_SUFFIX}:8200"
export VAULT_TOKEN="password"

print_env vault > ${ASSETS}/env-vault.conf

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

