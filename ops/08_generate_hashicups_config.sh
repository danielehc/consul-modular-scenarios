#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

generate_connect_stanza() {

  UPSTREAMS=""

  if [ ! -z "$1" ]; then
    for i in `echo $1`; do

      ADDRESS="$(echo $i | cut -d ':' -f1)"
      PORT="$(echo $i | cut -d ':' -f2)"


      UPSTREAMS=$(cat <<EOF
          ${UPSTREAMS}
          {
            destination_name = "${ADDRESS}"
            local_bind_port = ${PORT}
          },
EOF
)
      done

    UPSTREAMS=$(cat <<EOF
proxy {
        upstreams = [ ${UPSTREAMS} 
        ]
      }
EOF
)

  fi

  CONNECT_TEMPLATE=$(cat <<EOF
  # Required in order to allow registration of a sidecar
  connect {
    sidecar_service {
      ${UPSTREAMS}
    }
  }
EOF
)

echo -e "${CONNECT_TEMPLATE}" 

}

generate_tcp_check() {

  SERV=${1}
  SERV_ID=${2}
  ADDR_AND_PORT=${3}

  CHECK_TEMPLATE=$(cat <<EOF
  check {
    id =  "${SERV}-check"
    name = "${SERV} status check"
    service_id = "${SERV_ID}"
    tcp  = "${ADDR_AND_PORT}"
    interval = "1s"
    timeout = "1s"
 }
EOF
)

echo -e "${CHECK_TEMPLATE}" 

}

generate_service_config() {

SERV=${1}
SERV_ID=${2}
PORT=${3}

CONNECT=${4}

CHECK_STANZA=`generate_tcp_check "${1}" "${2}" "localhost:${3}"`

CONNECT_STANZA=`generate_connect_stanza "${4}"`

SVC_TEMPLATE=$(cat <<EOF
service {
  name = "${SERV}"
  id = "${SERV_ID}"
  port = ${PORT}
  token = "${AGENT_TOK}"
 
${CONNECT_STANZA}
  
${CHECK_STANZA}
}

EOF
)

echo -e "${SVC_TEMPLATE}" 

}


## Use
## generate_config <service_name> <datacenter>
generate_config_files() {

  SVC=${1}
  DATAC=${2}

  case "${SVC}" in
    "frontend")  
      SVC_PORT=80
      CONN_STANZA="public-api:8080"
      ;;
    "payments")  
      SVC_PORT=8080
      CONN_STANZA=""
      ;;
    "product-api")  
      SVC_PORT=9090
      CONN_STANZA="product-api-db:5432"
      ;;
    "product-api-db") 
      SVC_PORT=5432
      CONN_STANZA=""
      SD_TYPE="tcp"
      ;;
    "public-api") 
      SVC_PORT=8080
      CONN_STANZA="payments:1800 product-api:9090"
      ;;
    *) 
      log_err "Unkown service. Skipping service definition creation."
      return
      ;;
  esac

  log "Generate service definition for \033[1m\033[33m${SVC}.${DATAC}.${DOMAIN}\033[0m"
  generate_service_config "${SVC}" "${SVC}-${DATAC}" "${SVC_PORT}" "${CONN_STANZA}" >> ${ASSETS}/svc-${DATAC}-${SVC}.hcl

  if [ ! -z "${CONN_STANZA}" ]; then
    for i in `echo ${CONN_STANZA}`; do

      ADDRESS="$(echo $i | cut -d ':' -f1)"
      PORT="$(echo $i | cut -d ':' -f2)"


      INTENTION=$(cat <<EOF
Kind = "service-intentions"
Name = "${ADDRESS}"
Sources = [
  {
    Name = "${SVC}"
    Action = "allow"
  }
]
EOF
)
      log "Generate intention for \033[1m\033[33m${ADDRESS} > ${SVC}\033[0m"
      echo -e "$INTENTION" >> ${ASSETS}/config-intentions-${DATAC}-${ADDRESS}.hcl 
    done
  fi

  if [ ! -z "${SD_TYPE}" ]; then

    SERVICE_DEFAULTS=$(cat <<EOF
Kind     = "service-defaults"
Name     = "${SVC}"
Protocol = "${SD_TYPE}"
EOF
)
    echo -e "$SERVICE_DEFAULTS" >> ${ASSETS}/config-service-${DATAC}-${SVC}.hcl 
    SD_TYPE=""
  fi

}


# generate_service_config "service" "service_id" "1234" "connect:80 stanza:8080"


# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "HASHICUPS - GENERATE CONFIGURATION"
###### -----------------------------------------------

for dc in "${DATACENTERS[@]}" ; do

  ## Configuration is statically generated for all DCs and only copied on 
  ## existing service nodes.

  log "Generating configuration for HahiCups in ${dc}"

  for svc in "${SERVICES[@]}" ; do

    ADDR="svc-${dc}-${svc}"
    AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

    ## Generate configuration
    generate_config_files ${svc} ${dc}

    ## Copy configuration
    scp -o ${SSH_OPTS} ${ASSETS}/svc-${DATAC}-${SVC}.hcl             ${ADDR}${FQDN_SUFFIX}:${WORKDIR}consul/config > /dev/null 2>&1
  done
done



# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files --verbose

