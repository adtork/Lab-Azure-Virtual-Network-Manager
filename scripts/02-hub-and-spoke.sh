#!/usr/bin/env bash
set -euo pipefail

RG=${RG:-avnm-lab-microhack}
LOC=${LOC:-westus2}
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
ensure_network_group hubspokedirect "network group for direct connect"
ensure_network_group hubspoke "network group for hub & spoke"

header "Creating hub-and-spoke VNets vnetG-vnetK"
ensure_vnet vnetG 172.16.6.0/24 172.16.6.0/27 "$LOC"
ensure_vnet vnetH 172.16.7.0/24 172.16.7.0/27 "$LOC"
ensure_vnet vnetI 172.16.8.0/24 172.16.8.0/27 "$LOC"
ensure_vnet vnetJ 172.16.9.0/24 172.16.9.0/27 "$LOC"
ensure_vnet vnetK 172.16.10.0/24 172.16.10.0/27 "$LOC"

header "Adding spokes to AVNM network groups"
for vnet in vnetH vnetI; do
  ensure_static_member hubspoke "$vnet"
done
for vnet in vnetJ vnetK; do
  ensure_static_member hubspokedirect "$vnet"
done

header "Creating hub-and-spoke connectivity configurations"
hub_vnet=$(az network vnet show -g "$RG" -n vnetG --query id -o tsv)
direct_group_id=$(az network manager group show --network-group-name hubspokedirect --network-manager-name "$AVNM_NAME" --resource-group "$RG" --query id -o tsv)
if ! az network manager connect-config show --configuration-name "HubSpokeConnectivityConfig" -g "$RG" -n "$AVNM_NAME" --output none 2>/dev/null; then
  az network manager connect-config create --configuration-name "HubSpokeConnectivityConfig" \
    --description "avnm microhack hub and spoke direct" \
    --applies-to-groups group-connectivity=DirectlyConnected network-group-id="$direct_group_id" \
    --connectivity-topology "HubAndSpoke" \
    --display-name "microhack hub and spoke direct" \
    --hub resource-id="$hub_vnet" resource-type="Microsoft.Network/virtualNetworks" \
    --network-manager-name "$AVNM_NAME" \
    --resource-group "$RG" \
    --output none
fi

nondirect_group_id=$(az network manager group show --network-group-name hubspoke --network-manager-name "$AVNM_NAME" --resource-group "$RG" --query id -o tsv)
if ! az network manager connect-config show --configuration-name "HubSpokeConnectivityConfig-nondirect" -g "$RG" -n "$AVNM_NAME" --output none 2>/dev/null; then
  az network manager connect-config create --configuration-name "HubSpokeConnectivityConfig-nondirect" \
    --description "avnm microhack hub and spoke" \
    --applies-to-groups network-group-id="$nondirect_group_id" \
    --connectivity-topology "HubAndSpoke" \
    --display-name "microhack hub and spoke" \
    --hub resource-id="$hub_vnet" resource-type="Microsoft.Network/virtualNetworks" \
    --network-manager-name "$AVNM_NAME" \
    --resource-group "$RG" \
    --output none
fi

header "Committing hub-and-spoke configurations"
conf=$(az network manager connect-config show --configuration-name "HubSpokeConnectivityConfig" -g "$RG" -n "$AVNM_NAME" --query id -o tsv)
confnondirect=$(az network manager connect-config show --configuration-name "HubSpokeConnectivityConfig-nondirect" -g "$RG" -n "$AVNM_NAME" --query id -o tsv)
commit_configs "[\"$LOC\"]" "[\"$conf\",\"$confnondirect\"]"

header "Creating hub-and-spoke test VMs"
ensure_vm vnetGVM vnetG "$LOC"
ensure_vm vnetHVM vnetH "$LOC"
ensure_vm vnetIVM vnetI "$LOC"
ensure_vm vnetJVM vnetJ "$LOC"
ensure_vm vnetKVM vnetK "$LOC"

header "Hub-and-spoke scenario submitted"
printf 'Use Azure Serial Console and scripts/verify.sh to validate connectivity.\n'
