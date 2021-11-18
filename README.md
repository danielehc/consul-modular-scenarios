# Consul Modular Scenario

Modular lab to spin-up a Consul datacenter using custom [Docker][docker] images.

**Warning:** The environment is not intended for production use. It is intended 
to mimic the behavior of a VM with a container and build test environments to 
test Consul functionalities without the overhead of deploying a full VM.

## Usage examples

You can blindly test the scenario by running

```shell-session
./prov_containers.sh && ./prov_containers.sh operate
```

inside the repository root.

Read the following sections to more details on what the script does.

### Containers naming conventions

* Consul servers will be named `consul-server-${DATACENTER}-${NUMBER}`
* Consul clients hosing services will be named `svc-${DATACENTER}-${SERVICE}`

### Configure scenario

The file `ops/00_global_vars.env` contains the variables useful to tune the 
scenario configuration.

* `SERVER_NUMBER` (default `3`) - Number of servers to spin up per datacenter
* `DOMAIN` (default `consul`) - Cluster domain
* `PRIMARY_DATACENTER` (default `dc1`) - The name of the primary datacenter

* `DATACENTERS` (array) - And array of strings each one defines a datacenter name.
For each string in the array the script will create `SERVER_NUMBER` containers and
configure them as Consul servers in the datacenter named as the string.

**Example:** If `DATACENTERS=("dc1" "dc2")` then the script will create 6 Consul container.
3 named `consul-server-dc1-x` (with `1` <= `x` <= `${SERVER_NUMBER}`)
3 named `consul-server-dc2-x` (with `1` <= `x` <= `${SERVER_NUMBER}`)

> **Note:** All the datacenters created will automatically be federated using WAN federation

* `SERVICES` (array) - Still not completely defined
* `MESH_ELEMENTS` (array) - Still not completely defined

The file is used both in the infrastructure provision and in the deploy so it 
creates consistency in the outcome.

### Spin-up environment

```shell-session
./prov_containers.sh
```

Spins up containers for:

* Operator - Simulates a bastion host and is the node that runs all the commands that are necessary to complete the scenario setup.
* [Vault][vault] - Used to generate TLS certificates for Consul datacenters.
* [Consul][consul] servers.

You can verify the containers that are running after the script completes with:

```shell-session
docker ps -q --filter label=tag=instruqt | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' | sed 's/ \// /' | sort -V
```

Example output: 

```log
172.20.0.2 vault
172.20.0.3 operator
172.20.0.4 consul-server-dc1-1
172.20.0.5 consul-server-dc1-2
172.20.0.6 consul-server-dc1-3
172.20.0.7 consul-server-dc2-1
172.20.0.8 consul-server-dc2-2
172.20.0.9 consul-server-dc2-3
```

### Execute scenario

```shell-session
./prov_containers.sh operate
```

The command combines all the files in the `./ops` folder into a single script, 
copies it into the `operator` container and runs it.

```shell-session
for i in `find ops/*` ; do
    cat $i >> ${ASSETS}scripts/operate.sh
done

chmod +x ${ASSETS}scripts/operate.sh

# Copy script to operator container
docker cp ${ASSETS}scripts/operate.sh operator:/home/app/operate.sh

# Run script
# docker exec -it operator "chmod +x /home/app/operate.sh"
docker exec -it operator "/home/app/operate.sh"
```

The idea is to help development of complex scenarios in a sequential form and by 
splitting long procedures into more manageable scripts containing only a clear 
subset of actions.

## Instruqt compatibility

The script is deployed to have a testbed for Consul advanced scenarios but also 
as a kick-off for the creation of [Instruqt][https://play.instruqt.com/] scenarios.

The scripts use the internal Docker DNS to address containers but, if running in 
Instruqt uses the pre-populated `INSTRUQT_PARTICIPANT_ID` environment variable to
understand if the scenario is running on a self-hosted environment or in an 
Instruqt sandbox.


## Scenario files

During the scenario creation the script generates some files needed for the Consul
agent configuration, some to store secrets (that in a production environment should 
be stored in a safe location), and some other files that are used during the provision.

### Assets

Once the main scenario completed you can view the files created using:

```shell-session
docker exec -it operator /bin/bash -c "ls -1 /home/app/assets/"
```

### Logs

The scenario produces some logs (and will produce more of them in future versions).

To visualize the available logs:

```shell-session
docker exec -it operator /bin/bash -c "ls -1 /home/app/logs"
```

#### Notable log files

* `certificates.log` - All certificates generated for the scenario in readable format
* `files_created.log` - A summary of the different files created by the different sections


[vault]:https://www.vaultproject.io
[consul]:https://www.consul.io/
[envoy]:https://www.envoyproxy.io/
[docker]:https://www.docker.com/
[instruqt]:https://play.instruqt.com/