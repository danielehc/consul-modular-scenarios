#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

########## ------------------------------------------------
header1     "CONSUL - CONFIGURE CLIENT CONFIGURATION"
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

        log "Generate token for agent"

        log "Generate node specific configuration"

        log "Copy configuration on agent"

    done
done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files --verbose

