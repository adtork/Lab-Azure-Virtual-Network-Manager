## Azure-Virtual-Network-Manager Microhack


## Introduction

AVNM in a nutshell is the ability to quickly mangage networks at scale within a tenant or cross tenant. It gives you the ability to deploy, configure, group and manage networks at a thousand foot view. From there, you can tune the networks at a more granular view, and segment them based on your requirements. At the time of this writing, only certain regions are available for AVNM. More info and public article can be found here: https://docs.microsoft.com/en-us/azure/virtual-network-manager/overview

## Goals

The goal of this Microhack is to step through some of the common configuration scnearios that AVNM provides and see how that affects not only the topology behavior, but also security and resources inside those VNETs. This Microhack will continue to be updated as more scenarios become available. We will start off with stepping through three scenarios:

1. Mesh Configuration
2. Hub+Spoke Configuration and seperating that out with connected groups
3. Hybrid Hub+Spoke (Multiple connected Hub+Spoke groups)

## Mesh Configuration

![Mesh Topology](https://user-images.githubusercontent.com/55964102/170347376-dbe813ab-3e5a-48dd-8ea2-730a80cc16c0.png)

## Commands

```bash
#Parameters
rg=avnm-lab-microhack
loc=westus2
avnmname=myavnm
avnmnetgroup=myavnmgroup
subid=$(az account show --query 'id' -o tsv)

#List current default subscription you want to use for AVNM
az account show --query id --output tsv

#Create AVNM Resource Group
az group create -n $rg -l $loc --output none

#Create the AVNM instance
az network manager create --name $avnmname \
    --location $loc \
    --description "Network Manager for AVNM Microhack" \
    --display-name "myavnm" \
    --scope-accesses "SecurityAdmin" "Connectivity" \
    --network-manager-scopes subscriptions="/subscriptions/$subid" \
    --resource-group $rg \
    --output none
    
#Create Network Group for AVNM
az network manager group create --name $avnmnetgroup \
    --network-manager-name $avnmname \
    --description "AVNM Microhack Network Group" \
    --display-name $avnmnetgroup \
    --member-type "Microsoft.Network/virtualNetworks" \
    --resource-group $rg \
    --output none
   
#Create the VNETs for the network group 
az network vnet create --address-prefixes 172.16.0.0/24 -n vneta -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.0.0/27 --output none
az network vnet create --address-prefixes 172.16.1.0/24 -n vnetb -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.1.0/27 --output none
az network vnet create --address-prefixes 172.16.2.0/24 -n vnetc -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.2.0/27 --output none
az network vnet create --address-prefixes 172.16.3.0/24 -n vnetd -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.3.0/27 --output none
az network vnet create --address-prefixes 172.16.4.0/24 -n vnete -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.4.0/27 --output none
az network vnet create --address-prefixes 172.16.5.0/24 -n vnetf -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.5.0/27 --output none   

#Add the VNETs statically to the network group. For simplicty, repeat this for the other 5 VNETs and replace the variables for each vnet
vneta=$(az network vnet show -g $rg -n vneta --query id -o tsv) #Do the same for vnetb-vnetf, so that all six vnets are added statically 
az network manager group static-member create --network-group-name $avnmnetgroup \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --static-member-name "vneta" \
    --resource-id=$vneta \
    --output none
    
#Create the configuration for the network group
netgroup=$(az network manager group show --network-group-name $avnmnetgroup --network-manager-name $avnmname --resource-group $rg --query 'id' -o tsv)
az network manager connect-config create --configuration-name "Meshconnectivityconfig" \
    --description "Mesh config for AVNM Microhack" \
    --applies-to-groups group-Connectivity=DirectlyConnected network-group-id=$netgroup
    --connectivity-topology "Mesh" \
    --display-name "Mesh Connectivity" \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --output none
    
#Apply the configuration config
#Kudos to Bruce Cosden and Daniel Mauser. At this time, CLI commands not available so REST API call needed to apply configuration in CLI
config=$(az network manager connect-config show --configuration-name 'Meshconnectivityconfig' -g $rg -n $avnmname --query 'id' -o tsv)
subid=$(az account show --query 'id' -o tsv)
url='https://management.azure.com/subscriptions/'$subid'/resourceGroups/'$rg'/providers/Microsoft.Network/networkManagers/'$avnmname'/commit?api-version=2021-02-01-preview'
json='{
  "targetLocations": [
    "'$loc'"
  ],
  "configurationIds": [
    "'$config'"
  ],
  "commitType": "Connectivity"
}'

az rest --method POST \
    --url $url \
    --body "$json" \
    --output none   





