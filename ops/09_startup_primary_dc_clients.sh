#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "CONSUL - CONFIGURE SERVICES FOR ${PRIMARY_DATACENTER}"
###### -----------------------------------------------

for svc in "${SERVICES[@]}" ; do

  ADDR="svc-${PRIMARY_DATACENTER}-${svc}"

  ## Start Consul
  log "Starting Consul on scv-${PRIMARY_DATACENTER}-${svc}"

  ssh -o ${SSH_OPTS} ${ADDR}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
      -node=${ADDR} \
      -log-file=${WORKDIR}logs/${ADDR} \
      -config-dir=${WORKDIR}consul/config > ${WORKDIR}logs/${ADDR}.log 2>&1" &

  sleep 1

  if [ "${START_APPS}" == true ]; then

    ## Start Application (removed after HashiCups apps are in place)
    log "Starting service scv-${PRIMARY_DATACENTER}-${svc}"
  
    UP_URI=""

    for i in `cat "${ASSETS}/svc-${PRIMARY_DATACENTER}-${svc}.hcl" | grep local_bind_port | sed "s/.*=\ //g"` ; do 
      UP_URI="${UP_URI}http://localhost:$i," 
    done

    SVC_PORT=`cat "/home/app/assets/svc-${PRIMARY_DATACENTER}-${svc}.hcl" | grep -e "\sport" | sed "s/.*=\ //g"` 

    ssh -o ${SSH_OPTS} ${ADDR}${FQDN_SUFFIX} \
      "LISTEN_ADDR=0.0.0.0:${SVC_PORT} NAME=${svc} UPSTREAM_URIS=${UP_URI} /usr/local/bin/fake-service > ${WORKDIR}/logs/service-${ADDR}.log 2>&1 &"

    sleep 1
  fi

  ## Start Envoy sidecar
  log "Starting sidecar for scv-${PRIMARY_DATACENTER}-${svc}"

  TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

  ssh -o ${SSH_OPTS} ${ADDR}${FQDN_SUFFIX} \
    "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${svc}-${PRIMARY_DATACENTER} -admin-bind 0.0.0.0:19001 -- -l debug > ${WORKDIR}/logs/sidecar-proxy-${svc}-${PRIMARY_DATACENTER}.log 2>&1 &"

done

for i in `find ${ASSETS}/ -name "config-intentions-${PRIMARY_DATACENTER}-*"`; do
  # log_err Found asset $i
  consul config write $i
done 

for i in `find ${ASSETS}/ -name "config-service-${PRIMARY_DATACENTER}-*"`; do
  # log_err Found asset $i
  consul config write $i
done 

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

