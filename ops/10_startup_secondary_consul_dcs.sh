
#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+



# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "STARTING SECONDARY DATACENTERS SERVERS"
###### -----------------------------------------------

for dc in "${DATACENTERS[@]}" ; do

  if [ ${dc} != ${PRIMARY_DATACENTER} ]; then

    ########## ------------------------------------------------
    header2     "Configuring Servers for ${dc}"
    ###### -----------------------------------------------

    for serv in $(seq 1 ${SERVER_NUMBER}); do 

      ADDR="consul-server-${dc}-${serv}"
      
      log "Setup ACL tokens for ${ADDR}"
      
      consul acl token create -description "server-${dc}-${serv} agent token" -policy-name acl-policy-server-node  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null

      TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

      tee ${ASSETS}/agent-server-${dc}-${serv}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${TOK}"
    default  = "${DNS_TOK}"
    replication = "${FED_TOK}"
  }
}
EOF

      scp -o ${SSH_OPTS} ${ASSETS}/agent-server-${dc}-${serv}-acl-tokens.hcl      consul-server-${dc}-${serv}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
      
      log "Starting consul-server-${dc}-${serv}"

      ssh -o ${SSH_OPTS} consul-server-${dc}-${serv}${FQDN_SUFFIX} \
        "/usr/local/bin/consul agent \
        -node=consul-server-${dc}-${serv} \
        -log-file=${WORKDIR}logs/consul-server-${dc}-${serv} \
        -config-dir=${WORKDIR}consul/config > ${WORKDIR}logs/consul-server-${dc}-${serv}.log 2>&1" &
    done

  fi

  ## TODO: Define ENV variables and sve them in file

done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

