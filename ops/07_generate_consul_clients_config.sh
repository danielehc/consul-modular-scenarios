#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "CONSUL - GENERATE CLIENT CONFIGURATION"
###### -----------------------------------------------

########## ------------------------------------------------
header2     "Generate common configuration"
###### -----------------------------------------------

### Base client configuration
log "Generate base client configuration"
tee ${ASSETS}/agent-client-secure.hcl > /dev/null << EOF
log_level = "DEBUG"

ports {
  grpc  = 8502
  http  = 8500
  https = -1
  dns   = 53
}

enable_script_checks = false

enable_central_service_config = true

data_dir = "${WORKDIR}/consul/data"

verify_incoming        = false
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true

ca_file = "${WORKDIR}/consul/config/consul-agent-ca.pem"

auto_encrypt {
  tls = true
}

acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

for dc in "${DATACENTERS[@]}" ; do

  for svc in "${SERVICES[@]}" ; do

    ADDR="svc-${dc}-${svc}"
    
    log "Generate token for agent ${ADDR}"
    
    consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null

    TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

    tee ${ASSETS}/agent-client-${ADDR}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${TOK}"
    default  = "${DNS_TOK}"
  }
}
EOF

    log "Generate node specific configuration"

    RETRY_JOIN=`generate_retry_join ${dc}`
  
  tee ${ASSETS}/agent-client-${ADDR}-specific.hcl > /dev/null << EOF
## CLient specific configuration for ${dc}
server = false
datacenter = "${dc}"
domain = "${DOMAIN}" 

#client_addr = "127.0.0.1"

retry_join = [ ${RETRY_JOIN} ]
EOF

    log "Copy configuration on agent"

    wait_for ${ADDR}${FQDN_SUFFIX}

    ssh -o ${SSH_OPTS} ${ADDR}${FQDN_SUFFIX} \
    "mkdir -p ${WORKDIR}/consul/config \
      && mkdir -p ${WORKDIR}/consul/data \
      && mkdir -p ${WORKDIR}/logs" > /dev/null 2>&1

    # Copy configuration files
    scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-client-secure.hcl                 ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    # scp -o ${SSH_OPTS} ${ASSETS}/agent-connect.hcl                     ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca-${dc}.pem               ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config/consul-agent-ca.pem > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${ADDR}-acl-tokens.hcl     ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
    scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${ADDR}-specific.hcl       ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1

  done
done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

