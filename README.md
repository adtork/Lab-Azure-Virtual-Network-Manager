# Azure-Virtual-Network-Manager Microhack
<br>
<br>

**Introduction**:
<br>
<br>
AVNM in a nutshell is the ability to quickly mangage networks at scale within a tenant or cross tenant. It gives you the ability to deploy, configure, group and manage networks at a thousand foot view. From there, you can tune the networks at a more granular view, and segment them based on your requirements. At the time of this writing, only certain regions are available for AVNM. More info and public article can be found here: https://docs.microsoft.com/en-us/azure/virtual-network-manager/overview
<br>
<br>
<br>
**Goals**:
<br>
<br>
The goal of this Microhack is to step through some of the common configuration scnearios that AVNM provides and see how that affects not only the topology behavior, but also security and resources inside those VNETs. This Microhack will continue to be updated as more scenarios become available. We will start off with stepping through three scenarios:
<br>
<br>
1. Mesh Configuration
2. Hub+Spoke Configuration and seperating that out with connected groups
3. Hybrid Hub+Spoke (Multiple connected Hub+Spoke groups)
<br>
<br>

**Mesh Configuration**:
![Full Mesh](https://user-images.githubusercontent.com/55964102/170346167-34a8cf50-5611-4b08-9884-5aed6f138c68.jpg)
