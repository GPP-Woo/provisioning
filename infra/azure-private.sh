#!/bin/bash
#
# This uses a provisioned Azure Bastion with Linux VM to run a SOCKS5
# tunnel into an Azure private-vnet with direct access to private-AKS
# kubernetes API endpoint.
#
# Usage: azure-private.sh [tofu|terraform] <plan|apply|...> [-chdir=...] [options...]
#
# Unless specified, it will search for tofu or terraform binaries to use.
# It needs these critical items from Tofu/Terraform output:
# - BASTION_NAME: the Azure Bastion name ('bastion_name')
# - RG_NAME     : the Azure ResourceGroup name ('rg_name')
# - JUMPBOX_IP  : the internal IP address of a Linux VM ('vm1_ip')
# - SSH_USER    : the bastion VM username ('vm_username')
# - SSH_KEY     : the SSH private key identity for authenticating as SSH_USER ('vm_privkey')
# 
MAX_WAIT_SECONDS=60   # maximum time to wait for tunner setup, in seconds
SOCKS_PORT=8180       # port to listen() for SOCKS5 clients such as kubectl

# Exit script on any error
set -e

# Unless given as first argument, search for opentofu or terraform binary
if TF=$(expr "$1" : "^\(tofu\|terraform\)$"); then
  shift
fi
[ -n "$TF" ] || TF=$(which tofu) || TF=$(which terraform)
if [ -z "$TF" ]; then
    echo "Error: could not find terraform or opentofu binary - exiting"
    exit -1
fi

# Sniff optional "-chdir=..." argument for use with Terraform/Tofu commands
unset CHDIR
declare -a TF_ARGS
for arg in "$@"; do case $arg in
  -chdir=*) CHDIR="$arg"
            ;;
  *) TF_ARGS+=("$arg")
  esac
done

# Exit early if a (Socks5?) service is already listening
if fuser -sn tcp $SOCKS_PORT; then
echo "Warning: a service is already listening on the Socks5 port $SOCKS_PORT."
    echo "Please use a different port or stop a running service first."
    exit 0
fi

echo -n "## Getting required outputs from ${TF##*/}"
# Use terraform output to get the values you need.
# This assumes you have already run an initial apply to create the bastion and AKS.
# If running from scratch, you might need to parse the plan or apply in two steps.
BASTION_NAME=$($TF $CHDIR output -raw bastion_name); echo -n "."
RG_NAME=$($TF $CHDIR output -raw rg_name); echo -n "."
JUMPBOX_IP=$($TF $CHDIR output -raw vm1_ip); echo -n "."
SSH_USER=$($TF $CHDIR output -raw vm_username); echo -n "."
SSH_KEY=$(mktemp -p ${XDG_RUNTIME_DIR:-~/.ssh/})
$TF $CHDIR output -raw vm_privkey | install -m 0600 /dev/stdin "$SSH_KEY"; echo "."
# Tunnel arguments pre-flight-check
if [ -z "$BASTION_NAME" ]||[ -z "$RG_NAME" ]||[ -z "$JUMPBOX_IP" ]||[ -z "$SSH_USER" ]||[ ! -s "$SSH_KEY" ]; then
    echo "Error: Retrieval of one or more ${TF##*/} outputs failed:"
    echo "  BASTION_NAME: $BASTION_NAME; RG_NAME: $RG_NAME; JUMPBOX_IP: $JUMPBOX_IP; SSH_USER: $SSH_USER;"
    echo "  SSH_KEY $SSH_KEY details: $(ls -lsa "$SSH_KEY" 2>/dev/null)"
    echo "Please run a '${TF##*/} plan -target=module.bastion.azurerm_linux_virtual_machine.vm1[0] -out=...' and"
    echo "apply the base infrastructure first."
    exit 1
fi

echo "## Open Socks5 SSH tunnel on tcp/$SOCKS_PORT via Azure Bastion VM..."
echo Running: az network bastion ssh \
  --name $BASTION_NAME --resource-group $RG_NAME --target-ip-address $JUMPBOX_IP \
  --username $SSH_USER --auth-type ssh-key --ssh-key $SSH_KEY \
  --debug -- -D $SOCKS_PORT -N -q
az network bastion ssh \
  --name $BASTION_NAME --resource-group $RG_NAME --target-ip-address $JUMPBOX_IP \
  --username $SSH_USER --auth-type ssh-key --ssh-key $SSH_KEY \
  --debug -- -D $SOCKS_PORT -N -q &
  # --only-show-errors -- -D $SOCKS_PORT -N -q 2>/dev/null &
# Wait for the Socks5 SSH tunnel process to start listening
for ((i=$MAX_WAIT_SECONDS; i>0; i--)); do
  line=$(fuser -n tcp $SOCKS_PORT 2>&1) && break
  sleep 1
done
TUNNEL_PID="${line##* }"
if [ -z "$TUNNEL_PID" ]; then
  echo "Error: Socks5 SSH tunnel did not establish (in time) through Bastion."
  exit 1
fi
echo "## SOCKS Tunnel started with PID: ${TUNNEL_PID}"

# The 'trap' command ensures that the tunnel is closed when the script exits,
# whether it succeeds, fails, or is interrupted.
trap "echo '## Closing tunnel.'; fuser -skn tcp ${SOCKS_PORT}; unlink \"${SSH_KEY}\"" EXIT


echo "## (Demo) Get AKS cluster version & nodes:"
HTTPS_PROXY=socks5://localhost:$SOCKS_PORT kubectl version
HTTPS_PROXY=socks5://localhost:$SOCKS_PORT kubectl get nodes

# Pass all script arguments to the tofu/terraform command
echo "## Running '${TF##*/} $CHDIR ${TF_ARGS[@]}'..."
$TF $CHDIR "${TF_ARGS[@]}"


echo "## ${TF##*/} command completed."
# The trap will automatically kill the tunnel upon exit.