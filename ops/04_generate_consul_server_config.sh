#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+


# ++-----------------+
# || Functions       |
# ++-----------------+

generate_retry_join() {

  _RETRY_JOIN=""
  _DC=$1

  for serv in $(seq 1 ${SERVER_NUMBER}); do 
    _RETRY_JOIN="${_RETRY_JOIN} \"consul-server-${_DC}-${serv}\","
  done
  
  # Remove trailing commas
  echo ${_RETRY_JOIN} | sed 's/,$//g'

}


generate_retry_join_wan() {

  _RETRY_JOIN_WAN=""
  _DC=$1

  for dc in "${DATACENTERS[@]}" ; do

    if [ ! ${_DC} == ${dc} ]; then
      _RETRY_JOIN_WAN="${_RETRY_JOIN_WAN} `generate_retry_join ${dc}`,"
    fi

  done
  
  # Remove trailing commas
  echo ${_RETRY_JOIN_WAN} | sed 's/,$//g'

}

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "GENERATE CONSUL SERVER CONFIG"
###### -----------------------------------------------

## At this point the TLS and Gossip encryption config files are already created
# ${ASSETS}/agent-gossip-encryption.hcl
# ${ASSETS}/agent-${dc}-server-${srv}-tls.hcl

########## ------------------------------------------------
header2     "Generate generic server config"
###### -----------------------------------------------

### Base server configuration
log "Generate base server configuration"
tee ${ASSETS}/agent-server-secure.hcl > /dev/null << EOF
# Enable DEBUG logging
log_level = "DEBUG"

# Addresses and ports
addresses {
  grpc = "127.0.0.1"
  // http = "127.0.0.1"
  // http = "0.0.0.0"
  https = "0.0.0.0"
  dns = "127.0.0.1"
}

ports {
  grpc  = 8502
  http  = 8500
  https = 443
  dns   = 53
}

# DNS recursors
recursors = ["8.8.8.8"]

## Disable script checks
enable_script_checks = false

## Enable local script checks
enable_local_script_checks = true

## Centralized configuration (enabled by default since 1.9)
enable_central_service_config = true

## Data Persistence
data_dir = "${WORKDIR}/consul/data"

## TLS Encryption (requires cert files to be present on the server nodes)
verify_incoming        = false
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true

auto_encrypt {
  allow_tls = true
}
EOF

### Consul Connect service mesh CA
tee ${ASSETS}/agent-server-connect-ca.hcl > /dev/null << EOF
## Service mesh CA configuration
connect {
  ca_provider = "consul"
  ca_config {
      leaf_cert_ttl = "1h"
      rotation_period = "1h"
      intermediate_cert_ttl = "3h"
  }
}
EOF

### Consul ACL configuration
tee ${ASSETS}/agent-server-acl.hcl > /dev/null << EOF
## ACL configuration
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  enable_token_replication = true
  down_policy = "extend-cache"
}
EOF


for dc in "${DATACENTERS[@]}" ; do

  ########## ------------------------------------------------
  header2     "Generate Consul server config for ${dc}"
  ###### -----------------------------------------------

  RETRY_JOIN=`generate_retry_join ${dc}`
  RETRY_JOIN_WAN=`generate_retry_join_wan ${dc}`
  
  ### Consul ACL configuration
  tee ${ASSETS}/agent-server-specific-${dc}.hcl > /dev/null << EOF
## Server specific configuration for ${dc}
server = true
bootstrap_expect = ${SERVER_NUMBER}
datacenter = "${dc}"
primary_datacenter = "${PRIMARY_DATACENTER}"

client_addr = "127.0.0.1"

## UI configuration (1.9+)
ui_config {
  enabled = true
}

retry_join = [ ${RETRY_JOIN} ]

retry_join_wan = [ ${RETRY_JOIN_WAN} ]

EOF

  ########## ------------------------------------------------
  header3     "Distribute Consul server config for ${dc}"
  ###### -----------------------------------------------

  for serv in $(seq 1 ${SERVER_NUMBER}); do 

    wait_for consul-server-${dc}-${serv}${FQDN_SUFFIX}

    log "Distribute Consul config on consul-server-${dc}-${serv}"

    ## Create folder structure
    ssh -o ${SSH_OPTS} consul-server-${dc}-${serv}${FQDN_SUFFIX} \
      "mkdir -p ${WORKDIR}/consul/config \
        && mkdir -p ${WORKDIR}/consul/data \
        && mkdir -p ${WORKDIR}/logs" > /dev/null 2>&1

    # ++---------------------------+
    # || Distribute server config  |
    # ++---------------------------+

    ## Copy configuration files
    scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-server-${dc}-${serv}-tls.hcl      consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca-${dc}.pem               consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/server.${serv}.${dc}.${DOMAIN}.crt      consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/server.${serv}.${dc}.${DOMAIN}.key      consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-server-secure.hcl                 consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-server-connect-ca.hcl             consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-server-acl.hcl                    consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-server-specific-${dc}.hcl         consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1

  done 

done

########## ------------------------------------------------
header2     "Generate Global service mesh configuration"
###### -----------------------------------------------

tee ${ASSETS}/config-global-proxy-default.hcl > /dev/null << EOF
Kind      = "proxy-defaults"
Name      = "global"
Config {
  protocol = "http"
}
EOF


tee ${ASSETS}/config-global-intentions.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "*"
Sources = [
  {
    Name = "*"
    Action = "deny"
  }
]
EOF

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

