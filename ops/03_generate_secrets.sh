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

log_certificate() {

  # Make sure the ${LOGS} folder exists
  mkdir -p ${LOGS} 

  echo ""                           >> ${LOG_CERTIFICATES}
  echo "++----------- "             >> ${LOG_CERTIFICATES}
  echo "||   ${1} "                 >> ${LOG_CERTIFICATES}
  echo "++------      "             >> ${LOG_CERTIFICATES}
  echo "$2"                         >> ${LOG_CERTIFICATES}
  echo ""                           >> ${LOG_CERTIFICATES}
  openssl x509 -text -noout -in $1  >> ${LOG_CERTIFICATES}
  echo ""                           >> ${LOG_CERTIFICATES}
}

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "GENERATE DYNAMIC CONFIGURATION"
###### -----------------------------------------------

########## ------------------------------------------------
header2     "Generate Gossip configuration"
###### -----------------------------------------------

log "Generate gossip encryption key"

echo encrypt = \"$(consul keygen)\" > ${ASSETS}/agent-gossip-encryption.hcl

########## ------------------------------------------------
header2     "Generate TLS configuration"
###### -----------------------------------------------

sleep 2

log "Generate TLS certificates using Vault"

########## ------------------------------------------------
header3     "Generate Root CA"
###### -----------------------------------------------

vault secrets enable pki

vault secrets tune -max-lease-ttl=${VAULT_MAX_LEASE_ROOT_CA} pki

vault write -field=certificate \
  pki/root/generate/internal \
  common_name=${DOMAIN} \
  ttl=${VAULT_MAX_LEASE_ROOT_CA} > ${ASSETS}/vault_root_CA_cert.crt

log_certificate "${ASSETS}/vault_root_CA_cert.crt" "Vault Root CA certificate"

vault write pki/config/urls \
  issuing_certificates="http://vault${FQDN_SUFFIX}:8200/v1/pki/ca" \
  crl_distribution_points="http://vault${FQDN_SUFFIX}:8200/v1/pki/crl"

########## ------------------------------------------------
header3     "Generate Intermediate CAs"
###### -----------------------------------------------

  log "Configure intermediate CA for ${DOMAIN}"

  vault secrets enable -path=pki_int pki

  vault secrets tune -max-lease-ttl=${VAULT_MAX_LEASE_INT_CA} pki_int

  log "Sign intermediate cert"
  vault write -format=json \
    pki_int/intermediate/generate/internal \
    common_name="${DOMAIN}_intermediate_authority" \
    | jq -r '.data.csr' > ${ASSETS}/pki_intermediate.csr

  vault write -format=json pki/root/sign-intermediate \
    csr=@${ASSETS}/pki_intermediate.csr \
    format=pem_bundle ttl=${VAULT_MAX_LEASE_INT_CA} \
    | jq -r '.data.certificate' > ${ASSETS}/intermediate.cert.pem

  vault write pki_int/intermediate/set-signed \
    certificate=@${ASSETS}/intermediate.cert.pem

  log_certificate "${ASSETS}/intermediate.cert.pem" "Vault intermediate certificate"

  log "Configure server role"
  vault write pki_int/roles/${DOMAIN} \
    allowed_domains=${DOMAIN} \
    allow_subdomains=true \
    generate_lease=true \
    max_ttl=${VAULT_MAX_LEASE_CERT}

########## ------------------------------------------------
header3     "Generate Server Certificates"
###### -----------------------------------------------

for dc in "${DATACENTERS[@]}" ; do

  log "Generate server certificates for ${dc}"

  for ((srv = 1 ; srv <= ${SERVER_NUMBER} ; srv++)); do

    # Generates SANs for Server certificates
    # https://learn.hashicorp.com/tutorials/consul/deployment-guide#create-the-certificates

    # ALLOW_SANS=`get_sans ${dc}`
    # log "Allowed sans: $ALLOW_SANS"
    SERVER_SANS=`get_server_sans ${dc}`
    # log "Allowed sans: $SERVER_SANS"

    ## Create certificates
    vault write -format=json \
      pki_int/issue/${DOMAIN} \
      common_name=server.${dc}.${DOMAIN} \
      alt_names="${SERVER_SANS}" \
      ttl=24h | jq -j '.data.certificate, "\u0000", .data.private_key, "\u0000", .data.issuing_ca, "\u0000"' \
      | { IFS= read -r -d '' cert && printf '%s\n' "$cert" > ${ASSETS}/server.${srv}.${dc}.${DOMAIN}.crt;
          IFS= read -r -d '' key && printf '%s\n' "$key" > ${ASSETS}/server.${srv}.${dc}.${DOMAIN}.key;
          IFS= read -r -d '' ca && printf '%s\n' "$ca" > ${ASSETS}/consul-agent-ca-${dc}.pem; }

    log_certificate "${ASSETS}/server.${srv}.${dc}.${DOMAIN}.crt" "Certificate for server.${srv}.${dc}.${DOMAIN}"

    ## Create configuration files
    tee ${ASSETS}/agent-server-${dc}-$srv-tls.hcl > /dev/null << EOF
ca_file   = "${WORKDIR}/consul/config/consul-agent-ca-${dc}.pem"
cert_file = "${WORKDIR}/consul/config/server.${srv}.${dc}.${DOMAIN}.crt"
key_file  = "${WORKDIR}/consul/config/server.${srv}.${dc}.${DOMAIN}.key"
EOF

  done

done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files
