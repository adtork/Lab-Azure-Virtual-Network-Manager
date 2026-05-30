#!/usr/bin/env bash
set -euo pipefail

RG=${RG:-avnm-lab-microhack}
LOC=${LOC:-westus2}
LOC2=${LOC2:-eastus2}
AVNM_NAME=${AVNM_NAME:-myavnm}
VM_SIZE=${VM_SIZE:-Standard_D2_v2}
USERNAME=${USERNAME:-azureuser}
PASSWORD=${PASSWORD:-MyP@SSword123!}

header() {
  printf '\n==> %s\n' "$1"
}

ensure_group() {
  az group create -n "$RG" -l "$LOC" --output none
}

ensure_avnm() {
  local subid
  subid=$(az account show --query id -o tsv)
  if ! az network manager show --name "$AVNM_NAME" --resource-group "$RG" --output none 2>/dev/null; then
    az network manager create --name "$AVNM_NAME" \
      --location "$LOC" \
      --description "Network Manager for AVNM Microhack" \
      --display-name "$AVNM_NAME" \
      --scope-accesses "SecurityAdmin" "Connectivity" \
      --network-manager-scopes subscriptions="/subscriptions/$subid" \
      --resource-group "$RG" \
      --output none
  fi
}

ensure_network_group() {
  local name=$1
  local description=$2
  if ! az network manager group show --network-group-name "$name" --network-manager-name "$AVNM_NAME" --resource-group "$RG" --output none 2>/dev/null; then
    az network manager group create --name "$name" \
      --network-manager-name "$AVNM_NAME" \
      --description "$description" \
      --display-name "$name" \
      --member-type "Microsoft.Network/virtualNetworks" \
      --resource-group "$RG" \
      --output none
  fi
}

ensure_vnet() {
  local name=$1
  local prefix=$2
  local subnet=$3
  local location=$4
  if ! az network vnet show -g "$RG" -n "$name" --output none 2>/dev/null; then
    az network vnet create --address-prefixes "$prefix" -n "$name" -g "$RG" -l "$location" --subnet-name default --subnet-prefixes "$subnet" --output none
  fi
}

ensure_static_member() {
  local group=$1
  local vnet=$2
  local vnet_id
  vnet_id=$(az network vnet show -g "$RG" -n "$vnet" --query id -o tsv)
  if ! az network manager group static-member show --network-group-name "$group" --network-manager-name "$AVNM_NAME" --resource-group "$RG" --static-member-name "$vnet" --output none 2>/dev/null; then
    az network manager group static-member create --network-group-name "$group" \
      --network-manager-name "$AVNM_NAME" \
      --resource-group "$RG" \
      --static-member-name "$vnet" \
      --resource-id "$vnet_id" \
      --output none
  fi
}

ensure_vm() {
  local vm=$1
  local vnet=$2
  local location=$3
  if ! az vm show -g "$RG" -n "$vm" --output none 2>/dev/null; then
    az vm create -n "$vm" -g "$RG" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$location" --subnet default --vnet-name "$vnet" --admin-username "$USERNAME" --admin-password "$PASSWORD" --no-wait
  fi
}

commit_configs() {
  local locations_json=$1
  local config_ids_json=$2
  local subid url json
  subid=$(az account show --query id -o tsv)
  url="https://management.azure.com/subscriptions/${subid}/resourceGroups/${RG}/providers/Microsoft.Network/networkManagers/${AVNM_NAME}/commit?api-version=2021-02-01-preview"
  json=$(cat <<JSON
{
  "targetLocations": ${locations_json},
  "configurationIds": ${config_ids_json},
  "commitType": "Connectivity"
}
JSON
)
  az rest --method POST --url "$url" --body "$json" --output none
}

header "Preparing resource group and Azure Virtual Network Manager"
ensure_group
ensure_avnm
ensure_network_group avnmnetgroupglobalmesh "Global Mesh Hub+Spoke"

header "Ensuring West US 2 hub-and-spoke VNets vnetG-vnetK"
ensure_vnet vnetG 172.16.6.0/24 172.16.6.0/27 "$LOC"
ensure_vnet vnetH 172.16.7.0/24 172.16.7.0/27 "$LOC"
ensure_vnet vnetI 172.16.8.0/24 172.16.8.0/27 "$LOC"
ensure_vnet vnetJ 172.16.9.0/24 172.16.9.0/27 "$LOC"
ensure_vnet vnetK 172.16.10.0/24 172.16.10.0/27 "$LOC"

header "Creating East US 2 global mesh VNets vnetL-vnetP"
ensure_vnet vnetL 172.16.11.0/24 172.16.11.0/27 "$LOC2"
ensure_vnet vnetM 172.16.12.0/24 172.16.12.0/27 "$LOC2"
ensure_vnet vnetN 172.16.13.0/24 172.16.13.0/27 "$LOC2"
ensure_vnet vnetO 172.16.14.0/24 172.16.14.0/27 "$LOC2"
ensure_vnet vnetP 172.16.15.0/24 172.16.15.0/27 "$LOC2"

header "Adding vnetG-vnetP to global mesh network group"
for vnet in vnetG vnetH vnetI vnetJ vnetK vnetL vnetM vnetN vnetO vnetP; do
  ensure_static_member avnmnetgroupglobalmesh "$vnet"
done

header "Creating hub-and-spoke global mesh connectivity configuration"
hub_vnet_global=$(az network vnet show -g "$RG" -n vnetL --query id -o tsv)
group_id=$(az network manager group show --network-group-name avnmnetgroupglobalmesh --network-manager-name "$AVNM_NAME" --resource-group "$RG" --query id -o tsv)
if ! az network manager connect-config show --configuration-name "HubSpokeGlobalMesh" -g "$RG" -n "$AVNM_NAME" --output none 2>/dev/null; then
  az network manager connect-config create --configuration-name "HubSpokeGlobalMesh" \
    --description "avnm hub+spoke globalmesh" \
    --applies-to-groups group-connectivity=DirectlyConnected is-global=true network-group-id="$group_id" \
    --connectivity-topology "HubAndSpoke" \
    --display-name "Hub+Spoke globalmesh" \
    --delete-existing-peering true \
    --hub resource-id="$hub_vnet_global" resource-type="Microsoft.Network/virtualNetworks" \
    --network-manager-name "$AVNM_NAME" \
    --resource-group "$RG" \
    --output none
fi

header "Committing global mesh configuration to both regions"
confglobalmesh=$(az network manager connect-config show --configuration-name "HubSpokeGlobalMesh" -g "$RG" -n "$AVNM_NAME" --query id -o tsv)
commit_configs "[\"$LOC2\",\"$LOC\"]" "[\"$confglobalmesh\"]"

header "Creating East US 2 global mesh test VMs"
ensure_vm vnetLVM vnetL "$LOC2"
ensure_vm vnetMVM vnetM "$LOC2"
ensure_vm vnetNVM vnetN "$LOC2"
ensure_vm vnetOVM vnetO "$LOC2"
ensure_vm vnetPVM vnetP "$LOC2"

header "Global mesh scenario submitted"
printf 'Use Azure Serial Console and scripts/verify.sh to validate cross-region connectivity.\n'
