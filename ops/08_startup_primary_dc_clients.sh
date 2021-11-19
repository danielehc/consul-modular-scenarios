#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "CONSUL - CONFIGURE SERVICE MESH FOR ${PRIMARY_DATACENTER}"
###### -----------------------------------------------

for svc in "${SERVICES[@]}" ; do

  log "Starting scv-${PRIMARY_DATACENTER}-${svc}"

  ADDR="svc-${PRIMARY_DATACENTER}-${svc}"

  ssh -o ${SSH_OPTS} ${ADDR}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
      -node=${ADDR} \
      -log-file=${WORKDIR}logs/${ADDR} \
      -config-dir=${WORKDIR}consul/config > ${WORKDIR}logs/${ADDR}.log 2>&1" &

done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

