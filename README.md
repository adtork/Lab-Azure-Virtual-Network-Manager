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

Currently it looks like both CLI/PS commands are incomplete for AVNM. At this time, the labs steps here will be via Azure Portal Only 

## Mesh
1. Create the AVNM Instance
![image](https://user-images.githubusercontent.com/55964102/171273823-fb3f485a-b605-42c7-9d5f-9acb5926a38f.png)
2. Create the Network Group for AVNM
![image](https://user-images.githubusercontent.com/55964102/171274267-7caa8991-0894-4c6f-95c7-2d7e3613ced9.png)
3. Create the VNETs to be added to your AVNM Net Group (This part will be done via CLI)
