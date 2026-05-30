#!/usr/bin/env bash
set -euo pipefail

RG=${RG:-avnm-lab-microhack}
AVNM_NAME=${AVNM_NAME:-myavnm}

header() {
  printf '\n==> %s\n' "$1"
}

header "Azure account"
az account show --query "{subscription:name, id:id, user:user.name}" -o table

header "AVNM network groups"
az network manager group list --network-manager-name "$AVNM_NAME" --resource-group "$RG" -o table

header "AVNM connectivity configurations"
az network manager connect-config list --network-manager-name "$AVNM_NAME" --resource-group "$RG" -o table

header "VNets in $RG"
az network vnet list -g "$RG" --query "[].{name:name, location:location, addressSpace:addressSpace.addressPrefixes}" -o table

header "Per-VNet peerings"
mapfile -t vnets < <(az network vnet list -g "$RG" --query "[].name" -o tsv)
for vnet in "${vnets[@]}"; do
  printf '\n--- %s ---\n' "$vnet"
  az network vnet peering list -g "$RG" --vnet-name "$vnet" --query "[].{name:name, state:peeringState, remote:remoteVirtualNetwork.id, allowForwardedTraffic:allowForwardedTraffic, allowGatewayTransit:allowGatewayTransit, useRemoteGateways:useRemoteGateways}" -o table
done
