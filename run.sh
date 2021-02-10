#!/bin/bash

set -o errexit
set -o pipefail
#set -o nounset     ;handling unset environment variables manually
#set -x             ;debugging

YELLOW=
CYAN=
RED=
NC=
K3D_URL=https://raw.githubusercontent.com/rancher/k3d/main/install.sh
K3D_VERSION=v4.2.0
K3S_VERSION=docker.io/rancher/k3s:v1.20.2-k3s1
DEFAULT_NETWORK=k3d-action-bridge-network
DEFAULT_SUBNET=172.16.0.0/24
DEFAULT_REGISTRY_PORT=5000
NOT_FOUND=k3d-not-found-network
REGISTRY_LOCAL="registry-localhost"

#######################
#
#     FUNCTIONS
#
#######################
usage(){
  cat <<EOF

  Usage: $(basename "$0") <COMMAND>
  Commands:
      deploy            deploy custom k3d cluster
      test-registry     test container registry

  Environment variables:
      deploy
                        CLUSTER_NAME (Required) k3d cluster name.

                        ARGS (Optional) k3d arguments.

                        NETWORK (Optional) If not set than default k3d-action-bridge-network is created
                                               and all clusters share that network.

                        SUBNET_CIDR (Optional) If not set than default 172.16.0.0/24 is used. Variable requires
                                              NETWORK to be set.

                        USE_DEFAULT_REGISTRY (Optional) If not set than default false. If true provides local docker registry
                                              registry.localhost:5000 without TLS and authentication.

                        REGISTRY_PORT (Optional) Registry port. Default value 5000.

    test-registry
                        REGISTRY_PORT (Optional) Registry port. Default value 5000.
EOF
}

panic() {
  (>&2 echo -e " - ${RED}$*${NC}")
  usage
  exit 1
}

deploy(){
    local name=${CLUSTER_NAME}
    local arguments=${ARGS:-}
    local network=${NETWORK:-$DEFAULT_NETWORK}
    local subnet=${SUBNET_CIDR:-$DEFAULT_SUBNET}
    local registryName="${network}-${REGISTRY_LOCAL}"
    local registry=${USE_DEFAULT_REGISTRY:-}
    local registryPort=${REGISTRY_PORT:-$DEFAULT_REGISTRY_PORT}
    local registryArg

    if [[ -z "${CLUSTER_NAME}" ]]; then
      panic "CLUSTER_NAME must be set"
    fi

    existing_network=$(docker network list | awk '   {print $2 }' | grep -w "^$network$" || echo $NOT_FOUND)

    if [[ ($network == "$DEFAULT_NETWORK") && ($subnet != "$DEFAULT_SUBNET") ]]
    then
      panic "You can't specify custom subnet for default network."
    fi

    if [[ ($network != "$DEFAULT_NETWORK") && ($subnet == "$DEFAULT_SUBNET") ]]
    then
      if [[ "$existing_network" == "$NOT_FOUND" ]]
      then
        panic "Subnet CIDR must be specified for custom network"
      fi
    fi

    echo

    # create network if doesn't exists
    if [[ "$existing_network" == "$NOT_FOUND" ]]
    then
      echo -e "${YELLOW}create new network ${CYAN}$network $subnet ${NC}"
      docker network create --driver=bridge --subnet="$subnet" "$network"
    else
      echo -e "${YELLOW}attaching nodes to existing ${CYAN}$network ${NC}"
      subnet=$(docker network inspect "$network" -f '{{(index .IPAM.Config 0).Subnet}}')
    fi

    # Setup GitHub Actions outputs
    echo "::set-output name=network::$network"
    echo "::set-output name=subnet-CIDR::$subnet"

    echo -e "${YELLOW}Downloading ${CYAN}k3d@${K3D_VERSION} ${NC}see: ${K3D_URL}"
    curl --silent --fail ${K3D_URL} | TAG=${K3D_VERSION} bash

    if [[ "$registry" == "true" ]]
    then
      echo -e "${YELLOW}Creating registry ${CYAN}k3d-${registryName}:${registryPort}${NC}"
      init_registry "${registryPort}" "${registryName}"
      registryArg="--registry-use=k3d-${registryName}"
    fi

    echo -e "\existing_network${YELLOW}Deploy cluster ${CYAN}$name ${NC}"
    eval "k3d cluster create $name --wait $arguments --image ${K3S_VERSION} --network $network $registryArg"
}

init_registry(){
    # create registry if not exists
    local port=$1
    local registryName=$2
    if [ ! "$(docker ps -q -f name=k3d-"${registryName}")" ];
    then
      k3d registry create "${registryName}" --image=docker.io/library/registry:2 --port="${port}"
    fi
}

test_registry(){
  local registryPort=${REGISTRY_PORT:-$DEFAULT_REGISTRY_PORT}
  local tag=localhost:${registryPort}/k3d-action-dummy:v0.0.1
  echo -e "${CYAN}Test whether local registry is running${NC}"
  echo -e "${YELLOW}push and remove image${CYAN} ${tag}${NC}"
  docker build -t "${tag}" -f- . &> /dev/null <<EOF
FROM scratch
LABEL type=dummy
EOF
  docker push "${tag}"
  docker image rm "${tag}" &> /dev/null
  echo -e "${YELLOW}pull${CYAN} ${tag}${NC}"
  docker pull "${tag}"
  docker images
}

#######################
#
#     GUARDS SECTION
#
#######################
if [[ "$#" -lt 1 ]]; then
  usage
  exit 1
fi
if [[ -z "${NO_COLOR}" ]]; then
      YELLOW="\033[0;33m"
      CYAN="\033[1;36m"
      NC="\033[0m"
      RED="\033[0;91m"
fi


#######################
#
#     COMMANDS
#
#######################
case "$1" in
    "deploy")
       deploy
    ;;
    "test-registry")
       test_registry
    ;;
#    "<put new command here>")
#       command_handler
#    ;;
      *)
  usage
  exit 0
  ;;
esac
