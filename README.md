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

Currently it looks like both CLI/PS commands are incomplete for AVNM. At this time, the labs steps here will be mostly Azure portal, with some mix of CLI.

## Mesh
1. Create the AVNM Instance
![image](https://user-images.githubusercontent.com/55964102/171273823-fb3f485a-b605-42c7-9d5f-9acb5926a38f.png)
2. Create the Network Group for AVNM
![image](https://user-images.githubusercontent.com/55964102/171274267-7caa8991-0894-4c6f-95c7-2d7e3613ced9.png)
3. Create the VNETs to be added to your AVNM Net Group (This part will be done via CLI)
```bash
#Parameters
rg=avnm-lab-microhack
loc=westus2

#Create the Vnets
az network vnet create --address-prefixes 172.16.0.0/24 -n vneta -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.0.0/27 --output none
az network vnet create --address-prefixes 172.16.1.0/24 -n vnetb -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.1.0/27 --output none
az network vnet create --address-prefixes 172.16.2.0/24 -n vnetc -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.2.0/27 --output none
az network vnet create --address-prefixes 172.16.3.0/24 -n vnetd -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.3.0/27 --output none
az network vnet create --address-prefixes 172.16.4.0/24 -n vnete -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.4.0/27 --output none
az network vnet create --address-prefixes 172.16.5.0/24 -n vnetf -g $rg -l $loc --subnet-name default --subnet-prefixes 172.16.5.0/27 --output none
```
4. Add the Vnets to the network group
![image](https://user-images.githubusercontent.com/55964102/171277106-dc058d99-4334-41ff-ab2c-11e479ca0273.png)
![image](https://user-images.githubusercontent.com/55964102/171277255-5dd6039e-abac-4de8-90d6-693c7b4e2fe3.png)
![image](https://user-images.githubusercontent.com/55964102/171277338-aad243b3-b704-4bfb-9997-750a58fc0843.png)
5. Create the connectivity config for the network group
![image](https://user-images.githubusercontent.com/55964102/171277786-d719748b-8c63-4f21-892f-ae6a35eac17d.png)
![image](https://user-images.githubusercontent.com/55964102/171277993-1702cc07-f680-4c0f-b9f9-a6a199896145.png)
6. Deploy the configuration for the network group
![image](https://user-images.githubusercontent.com/55964102/171278787-8d0e0d9b-90ce-41c8-8205-62c45c2e7d70.png)
7. Deploy VMs in each VNET and see that they can ping since they are directly connected. Note, if you click on the VMs there are no peerings, but next hop via effective routes shows "connectedgroup"... This will be done via CLI.
```bash
#Paramaters
vmsize=Standard_D2_v2
username=azureuser
password="MyP@SSword123!"

#Create the VMs in each mesh VNET
az vm create -n spoke1VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vneta --admin-username $username --admin-password $password --no-wait
az vm create -n spoke2VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetb --admin-username $username --admin-password $password --no-wait
az vm create -n spoke3VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetc --admin-username $username --admin-password $password --no-wait
az vm create -n spoke4VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetd --admin-username $username --admin-password $password --no-wait
az vm create -n spoke5VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnete --admin-username $username --admin-password $password --no-wait 
az vm create -n spoke6VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $loc --subnet default --vnet-name vnetf --admin-username $username --admin-password $password --no-wait
```
8. Test connectivity between few VNETs and check next hop via VM effective routes



