#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+



# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "CONSUL - ACL CONFIGURATION"
###### -----------------------------------------------

export CONSUL_HTTP_ADDR="https://consul-server-${PRIMARY_DATACENTER}-1${FQDN_SUFFIX}"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${ASSETS}/consul-agent-ca-${PRIMARY_DATACENTER}.pem"
export CONSUL_TLS_SERVER_NAME="server.${PRIMARY_DATACENTER}.${DOMAIN}"
export CONSUL_FQDN_ADDR="consul-server-${PRIMARY_DATACENTER}-1${FQDN_SUFFIX}"

log "ACL Bootstrap"

for i in `seq 1 9`; do

  consul acl bootstrap --format json > ${ASSETS}/acl-token-bootstrap.json 2> /dev/null;

  excode=$?

  if [ ${excode} -eq 0 ]; then
    break;
  else
    if [ $i -eq 9 ]; then
      echo 'Failed to bootstrap ACL system, exiting.';
      exit 1
    else
      echo 'ACL system not ready. Retrying...';
      sleep 5;
    fi
  fi

done

export CONSUL_HTTP_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

## At this point all the environment variables are setup.
## Generate the env file for Consul
print_env consul > ${ASSETS}/env-consul-${PRIMARY_DATACENTER}.conf

log "Create ACL policies and tokens"

tee ${ASSETS}/acl-policy-dns.hcl > /dev/null << EOF
## dns-request-policy.hcl
node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
# only needed if using prepared queries
query_prefix "" {
  policy = "read"
}
EOF

tee ${ASSETS}/acl-policy-server-node.hcl > /dev/null << EOF
## consul-server-one-policy.hcl
node_prefix "consul-server-" {
  policy = "write"
}
EOF

consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @${ASSETS}/acl-policy-dns.hcl  > /dev/null 2>&1

consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @${ASSETS}/acl-policy-server-node.hcl  > /dev/null 2>&1

consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ${ASSETS}/acl-token-dns.json 2> /dev/null

DNS_TOK=`cat ${ASSETS}/acl-token-dns.json | jq -r ".SecretID"` 

## Create one agent token per server
for serv in $(seq 1 ${SERVER_NUMBER}); do 

  ADDR="consul-server-${PRIMARY_DATACENTER}-${serv}"
  export CONSUL_HTTP_ADDR=https://${ADDR}${FQDN_SUFFIX}

  log "Setup ACL tokens for ${ADDR}"

  consul acl token create -description "server-${PRIMARY_DATACENTER}-${serv} agent token" -policy-name acl-policy-server-node  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null

  TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

  consul acl set-agent-token agent ${TOK}
  consul acl set-agent-token default ${DNS_TOK}

done

export CONSUL_HTTP_ADDR=https://consul-server-${PRIMARY_DATACENTER}-1${FQDN_SUFFIX}


## Check federation config

if [ "${#DATACENTERS[@]}" -gt 1 ]; then

  log "Generating federation token"

  tee ${ASSETS}/acl-policy-federation.hcl > /dev/null << EOF
## acl-policy-federation.hcl
acl = "write"

operator = "write"

agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "read"
  intentions = "read"
}
EOF

  consul acl policy create -name 'acl-policy-wan-federation' -description 'Policy for Server WAN federation' -rules @${ASSETS}/acl-policy-federation.hcl  > /dev/null 2>&1

  consul acl token create -description "WAN federation token" -policy-name acl-policy-wan-federation  --format json > ${ASSETS}/acl-token-federation.json 2> /dev/null

  FED_TOK=`cat ${ASSETS}/acl-token-federation.json | jq -r ".SecretID"`

  # FED_TOK=$CONSUL_HTTP_TOKEN

fi


## Apply global configuration to service mesh
########## ------------------------------------------------
header1     "CONSUL - APPLY SERVICE MESH GLOBAL CONFIG"
###### -----------------------------------------------

for i in `find ${ASSETS}/ -name "config-global-*"`; do

  consul config write $i

done 

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

