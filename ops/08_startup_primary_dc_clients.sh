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

done

# ++-----------------+
# || Output          |
# ++-----------------+

get_created_files

