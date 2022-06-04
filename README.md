## Azure-Virtual-Network-Manager Microhack


## Introduction

AVNM in a nutshell is the ability to quickly mangage networks at scale within a tenant or cross tenant. It gives you the ability to deploy, configure, group and manage networks at a thousand foot view. From there, you can tune the networks at a more granular view, and segment them based on your requirements. At the time of this writing, only certain regions are available for AVNM. More info and public article can be found here: https://docs.microsoft.com/en-us/azure/virtual-network-manager/overview

## Goals

The goal of this Microhack is to step through some of the common configuration scnearios that AVNM provides and see how that affects not only the topology behavior, but also security and resources inside those VNETs. This Microhack will continue to be updated as more scenarios become available. The username for all vms is azureuser and passowrd is MyP@SSword123! The lab does not cover enabling serial console to test connectivity between VMs.  We will start off with stepping through three scenarios:

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
    
#Create the VMs in each VNET
#Once created enable serial console on each VM to test connectivity between each.

vmsize=Standard_D2_v2
username=azureuser
password="MyP@SSword123!"

az vm create -n vnetaVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vneta --admin-username $username --admin-password $password --no-wait
az vm create -n vnetbVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetb --admin-username $username --admin-password $password --no-wait
az vm create -n vnetcVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetc --admin-username $username --admin-password $password --no-wait
az vm create -n vnetdVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetd --admin-username $username --admin-password $password --no-wait
az vm create -n vneteVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnete --admin-username $username --admin-password $password --no-wait 
az vm create -n vnetfVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetf --admin-username $username --admin-password $password --no-wait

#Check the effective routes on the NIC to confirm next HOP via CLI or UI. Replace with your VM nic name!
az network nic show-effective-route-table -n "vnetaVMVMNic" -g $rg
{
      "addressPrefix": [
        "172.16.5.0/24",
        "172.16.4.0/24",
        "172.16.3.0/24",
        "172.16.2.0/24",
        "172.16.1.0/24"
      ],
      "destinationServiceTags": [],
      "disableBgpRoutePropagation": false,
      "hasBgpOverride": false,
      "name": null,
      "nextHopIpAddress": [],
      "nextHopType": "ConnectedGroup",
      "source": "Default",
      "state": "Active",
      "tagMap": {}
    },
#Notice the next HOP type for our destination VNETs is "ConnectedGroup"

#Check to see if there are any VNET Peerings for our AVNM Vnets
az network vnet peering list -g --vnet-name vneta
# The value will be null

#Finally see that you can ping from say vneta to vnetb and from vneta to vnetc direcly from serial console

azureuser@vnetaVM:~$ ping 172.16.1.4
PING 172.16.1.4 (172.16.1.4) 56(84) bytes of data.
64 bytes from 172.16.1.4: icmp_seq=1 ttl=64 time=2.65 ms
64 bytes from 172.16.1.4: icmp_seq=2 ttl=64 time=1.01 ms
64 bytes from 172.16.1.4: icmp_seq=3 ttl=64 time=1.00 ms
64 bytes from 172.16.1.4: icmp_seq=4 ttl=64 time=1.59 ms
^C
--- 172.16.1.4 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.008/1.569/2.655/0.671 ms
azureuser@vnetaVM:~$ ping 172.16.2.4
PING 172.16.2.4 (172.16.2.4) 56(84) bytes of data.
64 bytes from 172.16.2.4: icmp_seq=1 ttl=64 time=2.53 ms
64 bytes from 172.16.2.4: icmp_seq=2 ttl=64 time=0.955 ms
64 bytes from 172.16.2.4: icmp_seq=3 ttl=64 time=1.07 ms
64 bytes from 172.16.2.4: icmp_seq=4 ttl=64 time=0.953 ms
```
                             
## Conclusion
We can see creating a mesh with AVNM with our six VNETs, we were able to logically group them, apply connectivty and security policy and ping the VMs as if they were peered directly using VNET peering. As we checked via CLI or the UI, there is actually no peering listed direcly on the Vnets. We can also see, AVNM creates a new next hop type as "connectedgroup" which is a new next hop type for this Azure service. Under the hood, there is likely Vnet peering here that is not displayed in the portal.

## Hub and Spoke Topology
![image](https://user-images.githubusercontent.com/55964102/171702994-0ea3d8c6-1033-4285-95d6-bb16911a0116.png)


## Commmands
This section assumes you kept the resource group and AVNM instance previously from Mesh configuration. If you deleted, re-create those two services again. We will start off with creating the new network groups for Hub+Spoke for "directly connected" and non bi directional peering. Then, we will add our new VNETs in question to each network group, followed by creating the configurations and applying the configurations for each. Finally, we will create the new VMs and test connectivity within the hub and spoke for directly connected and bi directional peered VMs and check the next hops.

```bash
#Pasting same paramaters again from above just in case
rg=avnm-lab-microhack
loc=westus2
avnmname=myavnm
avnmnetgroup=myavnmgroup

#Create the network manager in Hub+Spoke for connected group, aka connected mesh
az network manager group create --name "hubspokedirect" \
    --network-manager-name $avnmname \
    --description "network group for direct connect" \
    --display-name "hubspokedirect" \
    --member-type "Microsoft.Network/virtualNetworks" \
    --resource-group $rg \
    --output none
    
#Create the network manager in Hub+Spoke for bi-directional peering only
az network manager group create --name "hubspoke" \
    --network-manager-name $avnmname \
    --description "network group for hub & spoke" \
    --display-name "hubspoke" \
    --member-type "Microsoft.Network/virtualNetworks" \
    --resource-group $rg \
    --output none
    
#Create the vNets for each
az network vnet create --address-prefixes 172.16.6.0/24 -n vnetG -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.6.0/27 --output none
az network vnet create --address-prefixes 172.16.7.0/24 -n vnetH -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.7.0/27 --output none
az network vnet create --address-prefixes 172.16.8.0/24 -n vnetI -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.8.0/27 --output none
az network vnet create --address-prefixes 172.16.9.0/24 -n vnetJ -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.9.0/27 --output none
az network vnet create --address-prefixes 172.16.10.0/24 -n vnetK -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.10.0/27 --output none

#Add the static vNETs for bi-directional peering and direct connect (mesh) for Hub+Spoke

#For hub+Spoke
vnetH=$(az network vnet show -g $rg -n vnetH --query id -o tsv) #repeat same steps for vnetI
az network manager group static-member create --network-group-name hubspoke \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --static-member-name "vnetH" \
    --resource-id=$vnetH \
    --output none
    
#For direct peering
vnetJ=$(az network vnet show -g $rg -n vnetJ --query id -o tsv) #repeat same steps for vnetK
az network manager group static-member create --network-group-name "hubspokedirect" \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --static-member-name "vnetJ" \
    --resource-id=$vnetJ \
    --output none
    
#Create the configs for each one for hub+Spoke and the other for Hub+Spoke with direct peering
hubVnet=$(az network vnet show -g $rg -n vnetG --query 'id' -o tsv)
groupid=$(az network manager group show --network-group-name "hubspokedirect" --network-manager-name $avnmname --resource-group $rg --query 'id' -o tsv)
az network manager connect-config create --configuration-name "HubSpokeConnectivityConfig" \
    --description "avnm microhack hub and spoke direct" \
    --applies-to-groups group-Connectivity=DirectlyConnected network-group-id=$groupid
    --connectivity-topology "HubAndSpoke" \
    --display-name "microhack hub and spoke direct" \
    --hub resource-id=$hubVnet resource-type="Microsoft.Network/virtualNetworks" \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --output none
    
hubVnet=$(az network vnet show -g $rg -n vnetG --query 'id' -o tsv)
groupid=$(az network manager group show --network-group-name "hubspoke" --network-manager-name $avnmname --resource-group $rg --query 'id' -o tsv)
az network manager connect-config create --configuration-name "HubSpokeConnectivityConfig-nondirect" \
    --description "avnm microhack hub and spoke" \
    --applies-to-groups group network-group-id=$groupid 
    --connectivity-topology "HubAndSpoke" \
    --display-name "microhack hub and spoke" \
    --hub resource-id=$hubVnet resource-type="Microsoft.Network/virtualNetworks" \
    --network-manager-name $avnmname \
    --resource-group $rg \
    --output none
    
#Apply the config, referencing both config groups
conf=$(az network manager connect-config show --configuration-name 'HubSpokeConnectivityConfig' -g $rg -n $avnmname --query 'id' -o tsv)
confnondirect=$(az network manager connect-config show --configuration-name 'HubSpokeConnectivityConfig-nondirect' -g $rg -n $avnmname --query 'id' -o tsv)
subid=$(az account show --query 'id' -o tsv)
url='https://management.azure.com/subscriptions/'$subid'/resourceGroups/'$rg'/providers/Microsoft.Network/networkManagers/'$avnmname'/commit?api-version=2021-02-01-preview'
json='{
  "targetLocations": [
    "'$loc'"
  ],
  "configurationIds": [
    "'$conf'",
    "'$confnondirect'"
  ],
  "commitType": "Connectivity"
}'

az rest --method POST \
    --url $url \
    --body "$json" \
    --output none
    

#Create the VMs in the vNETS for testing
az vm create -n vnetGVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetG --admin-username $username --admin-password $password --no-wait
az vm create -n vnetHVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetH --admin-username $username --admin-password $password --no-wait
az vm create -n vnetIVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetI --admin-username $username --admin-password $password --no-wait
az vm create -n vnetJVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetJ --admin-username $username --admin-password $password --no-wait
az vm create -n vnetKVM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetK --admin-username $username --admin-password $password --no-wait
```

## Conclusion
From this Hub and Spoke section, we can see that we were able to create a bi-diretional peering with Vnets (H and I) and direct mesh peering with Vnets (J and K). Vnet G in this scenario is our hub. For Vnets H and I, those are bi directionaly peered to our hub VNET and those VMs can only ping the hub VM, but not each other since they are non-connected group. For Vnets J and K, since those are part of the connected group, those VMs can ping each other and also ping the hub VM. When we check the next hop affected routes on our VMs, we can see VMs H and I have "Vnet peering" listed as next hop, and VMs J and K have "conneted group", which matches our topology. For VMG, that has peering to all the Vnets in question since its our hub. For the next section, we are going to explore a hybrid hub+spoke scenario. 
