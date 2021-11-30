
#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "STARTING PRIMARY DATACENTER SERVERS"
###### -----------------------------------------------

for serv in $(seq 1 ${SERVER_NUMBER}); do 

  log "Starting Consul on consul-server-${PRIMARY_DATACENTER}-${serv}"

  ssh -o ${SSH_OPTS} consul-server-${PRIMARY_DATACENTER}-${serv}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=consul-server-${PRIMARY_DATACENTER}-${serv} \
    -log-file=${WORKDIR}logs/consul-server-${PRIMARY_DATACENTER}-${serv} \
    -config-dir=${WORKDIR}consul/config > ${WORKDIR}logs/consul-server-${PRIMARY_DATACENTER}-${serv}.log 2>&1" &
done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

