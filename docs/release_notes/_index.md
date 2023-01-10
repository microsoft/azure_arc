---
type: docs
title: "Jumpstart Release Notes"
linkTitle: "Jumpstart Release Notes"
weight: 5
---

# Azure Arc Jumpstart release notes

**Release notes will be released around the first week of each month and will cover the previous month.**

## 2022

### December 2022

#### Release highlights

- Azure Arc-enabled data services December release and a few enhancements and version's bumps
- Jumpstart HCIBox additional modularity added

#### Azure Arc-enabled Kubernetes

- [New scenario: Using Cluster Connect to connect to an Azure Arc-enabled Kubernetes cluster via service account token authentication](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/connected_cluster/)
- [Enhancement: Bump CAPI, K3s, and kubeadm automation to support k8s 1.25 #1571](https://github.com/microsoft/azure_arc/issues/1571)

#### Azure Arc-enabled data services

- [Enhancement: Azure Arc-enabled data services - December release #1578](https://github.com/microsoft/azure_arc/issues/1578)
- [Enhancement: Custom Location RP OID update for Azure Arc-enabled data services Cluster API-based scenario #1552](https://github.com/microsoft/azure_arc/issues/1551)
- [Enhancement: Upgrade K8s version (AKS and Microk8s Azure Arc-enabled data services scenarios) #1574](https://github.com/microsoft/azure_arc/issues/1574)
- [Enhancement: Bump CAPI, K3s, and kubeadm automation to support k8s 1.25 #1571](https://github.com/microsoft/azure_arc/issues/1571)
- [Enhancement: Upgrade K8s version Microk8s Azure Arc-enabled data services scenario #1583](https://github.com/microsoft/azure_arc/issues/1583)

#### Azure Arc-enabled app services

- [Enhancement: Bump CAPI, K3s, and kubeadm automation to support k8s 1.25 #1571](https://github.com/microsoft/azure_arc/issues/1571)
- [Bug fix: ModuleNotFoundError: No module named 'azure.mgmt.web.v2021_01_01' #1549](https://github.com/microsoft/azure_arc/issues/1549)
- [Bug fix: Could not fund a runtime version for runtime {} with functions version {} and os {} #1579](https://github.com/microsoft/azure_arc/issues/1579)

#### Jumpstart ArcBox

- [Enhancement: Bump CAPI, K3s, and kubeadm automation to support k8s 1.25 #1571](https://github.com/microsoft/azure_arc/issues/1571)

#### Jumpstart HCIBox

- [Enhancement: Add a way to toggle deploying cluster registration, AKS HCI, and Arc Resource bridge automatic configuration #1554](https://github.com/microsoft/azure_arc/issues/1554)

### November 2022

#### Release highlights

- One Azure Arc-enabled servers updated scenario
- 3 Azure Arc-enabled Kubernetes updated scenarios
- 6 Azure Arc-enabled data services updated scenarios
- Security enhancements across Azure Arc-enabled servers, SQL Server, data services, and app services scenarios
- ArcBox usability enhancements
- [Enhancement: Optimized language for SSH public key prerequisite #1542](https://github.com/microsoft/azure_arc/issues/1542)

#### Azure Arc-enabled servers

- [Updated scenario: Use Azure Private Link to securely connect networks to Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_privatelink/)
- [Enhancement: Secure access to Client VM - Servers jumpstart scenarios #1513](https://github.com/microsoft/azure_arc/issues/1513)

#### Azure Arc-enabled SQL server

- [Enhancement: Secure access to Client VM - Servers jumpstart scenarios #1513](https://github.com/microsoft/azure_arc/issues/1513)

#### Azure Arc-enabled Kubernetes

- [Updated scenario: Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Azure ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/rancher_k3s/azure_arm_template/)
- [Updated scenario: Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/rancher_k3s/azure_terraform/)
- [Updated scenario: Deploy Rancher k3s on a VMware vSphere VM and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/rancher_k3s/vmware_terraform/)
- [Enhancement: Switch from k3sup to upstream Rancher K3s installation in Azure Arc-enabled Kubernetes scenarios #1490](https://github.com/microsoft/azure_arc/issues/1490)

#### Azure Arc-enabled data services

- [Updated scenario: Deploy an Azure Arc Data Controller (Vanilla) on GKE using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_dc_vanilla_terraform/)
- [Updated scenario: Deploy an Azure Arc-enabled SQL Managed Instance on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)
- [Updated scenario: Deploy an Azure Arc-enabled PostgreSQL Deployment on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_terraform/)
- [Updated scenario: Deploy a vanilla Azure Arc Data Controller on a Microk8s Kubernetes cluster in an Azure VM using ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/dc_vanilla/)
- [Updated scenario: Deploy Azure Arc-enabled SQL Managed Instance on a Microk8s Kubernetes cluster in an Azure VM using ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/mssql_mi/)
- [Updated scenario: Deploy Azure Arc-enabled PostgreSQL on a Microk8s Kubernetes cluster in an Azure VM using ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/postgresql/)
- [Enhancement: Azure Arc-enabled data services - November release #1544](https://github.com/microsoft/azure_arc/issues/1544)
- [Enhancement: Secure access to Client VM - Data services jumpstart scenarios #1507](https://github.com/microsoft/azure_arc/issues/1507)
- [Enhancement: Custom Location RP OID update for Azure Arc-enabled data services Kubeadm-based scenario #1547](https://github.com/microsoft/azure_arc/issues/1547)
- [Bug fix: Data services Jumpstart (Postgres) fails for microk8s #1456](https://github.com/microsoft/azure_arc/issues/1456)

#### Azure Arc-enabled app services

- [Enhancement: Secure access to Client VM - App services jumpstart scenarios #1500](https://github.com/microsoft/azure_arc/issues/1500)

#### Jumpstart ArcBox

- [Enhancement: ArcBox for DataOps logs separation #1536](https://github.com/microsoft/azure_arc/issues/1536)
- [Bug fix: ArcBox - Workbook missing data in some tabs (review queries and parameters) #1508](https://github.com/microsoft/azure_arc/issues/1508)

#### Jumpstart HCIBox

- [README update: Jumpstart HCIBox - hardcoded azure location for registration #1474](https://github.com/microsoft/azure_arc/issues/1474)
- [README update: Screenshot in HCIBox guide incorrectly highlights the wrong vcpu family #1487](https://github.com/microsoft/azure_arc/issues/1487)

### October 2022

#### Release highlights

- Jumpstart ArcBox for DataOps general availability - [Blog post](https://aka.ms/ArcBoxDataOpsBlog)
- Jumpstart HCI public preview - [Blog post](https://aka.ms/JumpstartHCIBoxBlog)
- New Azure Arc-enabled servers scenarios
- Removing CentOS 8 Stream from ArcBox
- Switch from k3sup to upstream Rancher K3s installation

#### Azure Arc-enabled servers

- [New scenario: Dashboard visualization on Azure Arc-enabled servers with Azure Managed Grafana and Azure Monitor Agent](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_grafana/#dashboard-visualization-on-azure-arc-enabled-servers-with-azure-managed-grafana-and-azure-monitor-agent) - Community contribution from [@stalejohnsen](https://github.com/stalejohnsen)
- [Bug fix: Fix broken urls Update Management Center scenario #1407](https://github.com/microsoft/azure_arc/issues/1407)

#### Azure Arc-enabled SQL Server

- [Bug fix: Deploy an Azure Virtual Machine with Windows Server & Microsoft SQL Server failing #1393](https://github.com/microsoft/azure_arc/issues/1393)
- [Bug fix: Automation Script not working #1394](https://github.com/microsoft/azure_arc/issues/1394)

#### Azure Arc-enabled Kubernetes

- [Enhancement: CAPI versions bump and _wait-providers_ flag #1472](https://github.com/microsoft/azure_arc/issues/1472)
- [Bug fix: CAPI Vanilla scenario failing #1457](https://github.com/microsoft/azure_arc/issues/1457)
- [Bug fix: Update CAPI basic GitOps scenario #1469](https://github.com/microsoft/azure_arc/issues/1469)
- [Bug fix: Update CAPI GitOps Basic Readme #1481](https://github.com/microsoft/azure_arc/issues/1481)

#### Azure Arc-enabled data services

- [Enhancement: Switch from k3sup to upstream Rancher K3s installation in Azure Arc-enabled data services scenarios #1489](https://github.com/microsoft/azure_arc/issues/1489)

#### Azure Arc-enabled app services

- [Enhancement: Switch from k3sup to upstream Rancher K3s installation in Azure Arc-enabled app services scenarios #1491](https://github.com/microsoft/azure_arc/issues/1491)

#### Azure Arc-enabled machine learning

- [Bug fix: The ML scenario is broken because the URI for Weave Scope has changed #1475](https://github.com/microsoft/azure_arc/issues/1475)

#### Jumpstart ArcBox

- [New ArcBox flavor: Jumpstart ArcBox for DataOps [general availability](https://github.com/microsoft/azure_arc/issues/1428)
  - [Product page](https://aka.ms/ArcBoxDataOps)
  - [Blog post](https://aka.ms/ArcBoxDataOpsBlog)
- [Enhancement: CAPI versions bump and _wait-providers_ flag #1472](https://github.com/microsoft/azure_arc/issues/1472)
- [Enhancement: Remove CentOS 8 Stream from ArcBox #1484](https://github.com/microsoft/azure_arc/issues/1484)
- [Enhancement: Switch from k3sup to upstream Rancher K3s installation in ArcBox #1488](https://github.com/microsoft/azure_arc/issues/1488)
- [Bug fix: "MyIpAddress" parameter not available in ArcBox #1395](https://github.com/microsoft/azure_arc/issues/1395)
- [Bug fix: azure_jumpstart_hcibox/artifacts/Deploy-GitOps.ps1 errors #1464](https://github.com/microsoft/azure_arc/issues/1464)

#### Jumpstart HCIBox

- Jumpstart HCIBox public preview
  - [Product page](https://aka.ms/JumpstartHCIBox)
  - [Blog post](https://aka.ms/JumpstartHCIBoxBlog)
- [Enhancement: Update HCIBox to use 22H2 image #1465](https://github.com/microsoft/azure_arc/issues/1465)

### September 2022

#### Release highlights

- New and updated Azure Arc-enabled servers scenarios
- New and updated Azure Arc-enabled data services scenarios
- Bug fixes

#### Azure Arc-enabled servers

- [New scenario: Onboard Azure Arc-enabled servers to Update Management Center](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_updatemanagementcenter/)

#### Azure Arc-enabled data services

- [Updated scenario: Deploy a vanilla Azure Arc Data Controller in directly connected mode on Kubeadm Kubernetes cluster with Azure provider using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/kubeadm/kubeadm_azure_dc_vanilla_arm_template/)
- [New scenario: Deploy Azure Arc-enabled SQL Managed Instance in directly connected mode on Kubeadm Kubernetes cluster with Azure provider using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/kubeadm/kubeadm_azure_mssql_mi_arm_template/)
- [New scenario: Deploy Azure Arc-enabled PostgreSQL in directly connected mode on Cluster API Kubernetes cluster with Azure provider using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/kubeadm/kubeadm_azure_postgresql_arm_template/)
- [Bug fix: Bootstrapping through yaml fails #1346](https://github.com/microsoft/azure_arc/issues/1346)

#### Azure Arc-enabled app services

- [Bug fix: App Service (Container) ARM Template: AppServicesLoginScript stuck waiting for log processor #1320](https://github.com/microsoft/azure_arc/issues/1320)

#### Jumpstart ArcBox

- [Bug fix: "MyIpAddress" parameter not available in ArcBox #1395](https://github.com/microsoft/azure_arc/issues/1395)

### August 2022

#### Release highlights

- Added Azure Arc-enabled Kubernetes correlation-id for onboarding tracking
- Updated Azure Arc-enabled Kubernetes scenarios
- Cluster API-related versions bump
- Bug fixes
- Doc fixes

#### Azure Arc-enabled servers

- [Doc fix: Link under Unified Operations doc broken #1324](https://github.com/microsoft/azure_arc/issues/1324)

#### Azure Arc-enabled SQL Server

- [Bug fix: SQL VM On-Boarding Fixes v3 #1328](https://github.com/microsoft/azure_arc/pull/1328)

#### Azure Arc-enabled Kubernetes

- [Updated scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on MicroK8s as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/microk8s/local_microk8s_gitops_helm/)
- [Enhancement: Add Deploy to Azure button to ARO scenario #1310](https://github.com/microsoft/azure_arc/issues/1310)
- [Enhancement: Added Deploy to Azure Button to K3s scenario #1312](https://github.com/microsoft/azure_arc/issues/1312)
- [Enhancement: correlation-id for tracking #1314](https://github.com/microsoft/azure_arc/issues/1314)

#### Jumpstart ArcBox

- [Enhancement: CAPI versions bump #1315](https://github.com/microsoft/azure_arc/issues/1315)
  - Versions bump
    - clusterctrl: v1.1.5 --> v1.2.0
    - CAPZ K8s: v1.24.2 --> v1.24.3
    - Azure Disk CSI Driver: v1.19.9 --> 1.21.0
- [Enhancement: correlation-id for tracking #1314](https://github.com/microsoft/azure_arc/issues/1314)

### July 2022

#### Release highlights

- New ["Azure Arc Jumpstart commitment to open-source software"](https://azurearcjumpstart.io/oss/) page added
- New Azure Arc-enabled servers scenarios
- New and Updated Azure Arc-enabled Kubernetes scenarios
- Updated Azure Arc-enabled data services scenarios
- Multiple ArcBox enhancements
- Bug fixes

#### Azure Arc-enabled servers

- [New scenario: Deploy the Azure Monitor Agent (AMA) on Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_azuremonitoragent/)

#### Azure Arc-enabled Kubernetes

- [New scenario: Deploy an application using the Dapr Cluster extension for Azure Arc-enabled Kubernetes cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/developer/dapr/dapr_statestore/)
- [Updated scenario: Deploy AKS cluster and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks/aks_terraform/)
- [Updated scenario: Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/rancher_k3s/azure_terraform/)
- [Bug fix: AKS 1.23.3 is not supported anymore #1293](https://github.com/microsoft/azure_arc/issues/1293)

#### Azure Arc-enabled data services

- [Updated scenario: Deploy a vanilla Azure Arc Data Controller in a directly connected mode on EKS using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/eks/eks_dc_vanilla_terraform/)
- [Updated scenario: Deploy Azure SQL Managed Instance in directly connected mode on EKS using a Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/eks/eks_mssql_mi_terraform/)
- [Updated scenario: Deploy Azure PostgreSQL in directly connected mode on EKS using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/eks/eks_postgres_terraform/)
- [Bug fix: AKS 1.23.3 is not supported anymore #1293](https://github.com/microsoft/azure_arc/issues/1293)

#### Jumpstart ArcBox

- [Enhancement: CAPZ/ArcBox Optimizations #1277](https://github.com/microsoft/azure_arc/pull/1277)
  - Versions bump
    - clusterctrl -> 1.1.5
    - CAPZ provider -> 1.4.0
    - CAPZ K8s -> 1.24.2
  - Kubernetes CSI driver implementation (1.19.0) + Updated StorageClass yaml
  - Reversing Azure Arc-enabled Kubernetes cluster extensions installation order on CAPZ cluster
  - Switching to Azure to B-series virtual machines from previous D-series. Keeping ArcBox Full/ITPro Client VM as D16s_v4 for nested virtualization support
  - Bump control plane nodes from 1 to 3
  - ARM/Bicep API versions bump
  - Docs updates to reflect capacity requirements

### June 2022

#### Release highlights

- Updated Azure Arc-enabled servers scenarios
- Updated Azure Arc-enabled SQL server scenario
- New and Updated Azure Arc-enabled Kubernetes scenarios
- New Azure Arc-enabled data services scenarios
- [Bump Azure Arc Data Controller images to May 2022 release](https://github.com/microsoft/azure_arc/pull/1247)
- Bug fixes

#### Azure Arc-enabled servers

- [Updated scenario: Monitoring, Alerting, and Visualization on Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_monitoring/)
- [Updated scenario: Added Azure Bastion support for Deploy an Azure Virtual Machine with Windows Server & Microsoft SQL Server and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_sqlsrv/azure/azure_arm_template_winsrv/)
- [Updated scenario: Deploy a GCP Ubuntu instance and connect it to Azure Arc using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)
- [Updated scenario: Deploy a GCP Windows instance and connect it to Azure Arc using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)
- [Enhancement: Add Deploy to Azure button to ARM based deployments for Azure Arc-enabled servers #1249](https://github.com/microsoft/azure_arc/issues/1249)

#### Azure Arc-enabled VMware vSphere

- [New scenario: Create a Windows VMware VM to an Azure Arc-enabled vSphere cluster using ARM templates](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_vsphere/day2/vmware_arm_template_win/)

#### Azure Arc-enabled Kubernetes

- [New scenario: Integrate Azure Monitor Container Insights and recommended alerts with an Azure Arc-enabled K8s cluster using extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/container_insights/)
- [New scenario: Integrate Azure Policy with an Azure Arc-enabled K8s cluster using extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/azure_policy/)
- [Updated scenario: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_gitops_basic/)
- [Updated scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on GKE as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_gitops_helm/)
- [Updated scenario: Deploy GKE cluster and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/gke/gke_terraform/)

#### Azure Arc-enabled data services

- [New scenario: Deploy Azure SQL Managed Instance with AD authentication support using Customer-managed keytab in directly connected mode on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/aks/aks_mssql_mi_ad_auth_arm_template/)
- [New scenario: Migrate to Azure Arc-enabled SQL Managed Instance on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/aks/aks_mssql_migrate/)
- [Feature: June 2022 image update](https://github.com/microsoft/azure_arc/pull/1247)

#### Jumpstart ArcBox

- Bug fixes: [#1253](https://github.com/microsoft/azure_arc/pull/1253), [#1264](https://github.com/microsoft/azure_arc/pull/1264)

### May 2022

#### Release highlights

- [Announcing ArcBox for DevOps](https://aka.ms/ArcBoxDevOpsBlog)
  - Added Azure Bastion support
  - Added Azure Just-in-Time (JIT) support
  - New sample applications for GitOps, Open Service Mesh (OSM), and Azure Key Vault integration
  - New automated GitOps configuration
  - New Azure Monitor workbook
  - Updated Microsoft Defender for Cloud experience
  - Bump Kubernetes version to v1.22.8
  - Bump Cluster API Azure provider version to v1.2.1
  - Bump Clusterctl version to v1.1.3
  - API bumps across all ARM and Bicep templates
  - Optimized Azure VM SKUs
  - Added [FAQ](https://aka.ms/ArcBox-FAQ) and a sample ArcBox cost estimator with Azure Pricing Calculator
  - Additional misc optimizations, enhancements and bug fixes
- New Azure Arc-enabled servers scenarios
- New Azure Arc-enabled VMware vSphere scenarios
- Updated Azure Arc-enabled SQL Server scenario
- Updated Azure Arc-enabled Kubernetes scenarios
- New and updated Azure Arc-enabled data services scenarios
- [Bump AzCli 2.36.0 prerequisite across all READMEs](https://github.com/microsoft/azure_arc/pull/1188)
- [Bump Azure Arc Data Controller images to May 2022 release](https://github.com/microsoft/azure_arc/pull/1205)

#### Azure Arc-enabled servers scenarios

- [New Scenario: Enable SSH access to Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_ssh/#enable-ssh-access-to-azure-arc-enabled-servers)
- [New Scenario: Azure Arc-enabled servers connectivity behind a proxy server](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_proxy/#azure-arc-enabled-servers-connectivity-behind-a-proxy-server)
- [Updated Scenario: Azure Arc-enabled servers inventory management using Resource Graph Explorer](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_inventory_management/)
- [Bug fix: Azure Automanage - incorrect description #1193](https://github.com/microsoft/azure_arc/issues/1193)
- [Bug fix: Updated private link scenario to show private connection #1219](https://github.com/microsoft/azure_arc/pull/1219)

#### Azure Arc-enabled VMware vSphere scenarios

- [New Scenario: Connect VMware vCenter Server to Azure Arc using PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_vsphere/resource_bridge/powershell/)

#### Azure Arc-enabled SQL Server scenarios

- [Updated Scenario: Deploy an Azure Virtual Machine with Windows Server & Microsoft SQL Server and connect it to Azure Arc using Terraform #1212](https://github.com/microsoft/azure_arc/pull/1212)

#### Azure Arc-enabled Kubernetes scenarios

- [Updated Scenario: Updated AKS Onboarding ARM Template Scenario #1152](https://github.com/microsoft/azure_arc/issues/1152)
- [Updated Scenario: Updated AKS Onboarding Scenario - Terraform #1160](https://github.com/microsoft/azure_arc/issues/1160)
- [Updated Scenario: Updated AKS Basic GitOps Scenario #1169](https://github.com/microsoft/azure_arc/issues/1169)
- [Updated Scenario: Updated AKS GitOps Helm Scenario #1177](https://github.com/microsoft/azure_arc/issues/1177)
- [Updated Scenario: Updated CAPI GitOps Helm Scenario #1186](https://github.com/microsoft/azure_arc/issues/1186)

#### Azure Arc-enabled data services

- [New Scenario: Configure disaster recovery in Azure Arc-enabled SQL Managed Instance on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/aks/aks_mssql_dr/#configure-disaster-recovery-in-azure-arc-enabled-sql-managed-instance-on-aks-using-an-arm-template)
- [Feature: May 2022 image update](https://github.com/microsoft/azure_arc/pull/1205)
- [Bug fix: Azure ArcBox CSI Driver not installed #1150](https://github.com/microsoft/azure_arc/issues/1150)

#### Jumpstart ArcBox

- [New flavor: ArcBox for DevOps](https://aka.ms/ArcBoxDevOpsBlog)
- [Feature: ArcBox-Client VM custom script extension should use protectedSettings instead of settings #1209](https://github.com/microsoft/azure_arc/issues/1209)
- [Bug fix: Owner Role But No Write permission #1165](https://github.com/microsoft/azure_arc/issues/1165)
- [Bug fix: Please change the way ServicePrincipal name is given in example #1176](https://github.com/microsoft/azure_arc/issues/1176)
- [Bug fix: Log Analytics Workspace needs to be in different region to Automation Account #1187](https://github.com/microsoft/azure_arc/issues/1187)

### April 2022

#### Release highlights

- [Updated Azure Arc Jumpstart Scenario Write-up Guidelines](https://azurearcjumpstart.io/scenario_guidelines/)
- New and updated Azure Arc-enabled servers scenarios
- New and updated Azure Arc-enabled Kubernetes scenarios
- New and updated Azure Arc-enabled data servers scenarios
- Updated Azure Arc-enabled app services scenarios
- Multiple Jumpstart ArcBox optimizations, enhancements and bug fixes

#### Azure Arc-enabled servers scenarios

- [New Scenario: Use Azure Private Link to securely connect networks to Azure Arc](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_privatelink/)

#### Azure Arc-enabled SQL Server scenarios

- [Bug fix: Arc enabled SQL Servers - missing registration for Microsoft.HybridCompute #1105](https://github.com/microsoft/azure_arc/issues/1105)
- [Bug fix: Arc enables SQL Server - missing --scopes from az ad sp create-for-rbac #1106](https://github.com/microsoft/azure_arc/issues/1106)

#### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Use GitOps in an Azure Arc-enabled Kubernetes cluster for managing Calico Network Policy](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/gitops/)
- [Updated Scenario: Integrate Open Service Mesh (OSM) with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_osm_extension/)
- [Updated Scenario: Deploy AKS cluster on Azure Stack HCI and connect it to Azure Arc using PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_stack_hci/aks_hci_powershell/)
- [Bug fix: az connectedk8s fails on Ubuntu20.04 (Microk8s) - InternalError: Unable to install helm release: WARNING: Kubernetes configuration file is group-readable #1047](https://github.com/microsoft/azure_arc/issues/1047)
- [Bug fix: Missing RBAC permission in docs for ARO #1052](https://github.com/microsoft/azure_arc/issues/1052)

#### Azure Arc-enabled data services

- [New Scenario: Deploy a vanilla Azure Arc Data Controller in a directly connected mode on ARO using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aro/aro_dc_vanilla_arm_template/)
- [New Scenario: Deploy Azure SQL Managed Instance in directly connected mode on ARO using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aro/aro_mssql_mi_arm_template/)
- [New Scenario: Deploy Azure PostgreSQL in directly connected mode on ARO using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aro/aro_postgresql_arm_template/)
- [Updated Scenario: Deploy Azure SQL Managed Instance on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_arm_template_ado/)
- [Updated Scenario: Deploy Azure PostgreSQL on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_arm_template_ado/)
- [Bug fix: The post deployment scripts inside the VM fails with the following error : "The resource 'Arc-Data-AKS' under the resource group 'Arc-Data-Demo' NOT FOUND #1050](https://github.com/microsoft/azure_arc/issues/1050)

#### Azure Arc-enabled app services scenarios

- [Updated Scenario: Deploy an App Service app using custom container on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_app_service_arm_template/)
- [Updated Scenario: Deploy Azure Function application on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_azure_function_arm_template/)
- [Updated Scenario: Deploy an App Service app using custom container on Cluster API using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/apps_service_arm_template/)
- [Updated Scenario: Deploy Azure Function application on Cluster API using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/azure_function_arm_template/)

#### Jumpstart ArcBox

- [Bump clusterctl to v1.1.3](https://github.com/microsoft/azure_arc/pull/1126)
- [Bump CAPZ to v1.2.1](https://github.com/microsoft/azure_arc/pull/1126)
- [Bump CAPI to 1.22.8](https://github.com/microsoft/azure_arc/pull/1126)
- [Updating storageclass provisioner](https://github.com/microsoft/azure_arc/pull/1126)
- [Remove debug flag](https://github.com/microsoft/azure_arc/pull/1126)

### March 2022

#### Release highlights

- New and updated Azure Arc-enabled servers scenarios
- New and updated Azure Arc-enabled Kubernetes scenario
- Azure Bastion support for Azure Arc-enabled servers and data services
- Updated Arc-enabled data services enhancements

#### Azure Arc-enabled servers scenarios

- [New Scenario: Monitoring, Alerting, and Visualization on Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_monitoring/)
- [Updated Scenario: Update Azure Automanage with new ARM template #1017](https://github.com/microsoft/azure_arc/issues/1017)
- [Feature: Adding Azure Bastion as an optional RDP/SSH method - Azure Arc-enabled servers #985](https://github.com/microsoft/azure_arc/issues/985)

#### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy an Azure Red Hat OpenShift cluster and connect it to Azure Arc using an Azure ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aro/aro_arm_template/)
- [Updated Scenario: Deploy EKS cluster and connect it to Azure Arc using Terraform #870](https://github.com/microsoft/azure_arc/issues/870)
- [Feature: Hardening NSG inbound rule - Azure Arc-enabled Kubernetes #1000](https://github.com/microsoft/azure_arc/issues/1000)

#### Azure Arc-enabled data services scenarios

- [Updated Scenario: Refactoring - Azure Arc-enabled data services scenarios (Cluster API) #1021](https://github.com/microsoft/azure_arc/issues/1021)
- [Updated Scenario: Refactoring - Azure Arc-enabled data services scenarios (AKS) #1019](https://github.com/microsoft/azure_arc/issues/1019)
- [Feature: Adding Azure Bastion as an optional RDP/SSH method - Azure Arc-enabled data services #987](https://github.com/microsoft/azure_arc/issues/987)

### February 2022

#### Release highlights

- In this release, we reached 100 individual Jumpstart scenarios!
- New Azure Arc-enabled servers scenario
- New Azure Arc-enabled Kubernetes scenarios
- Azure Arc-enabled data services enhancements
- Multiple Jumpstart ArcBox optimizations, enhancements and bug fixes

#### Azure Arc-enabled servers scenarios

- [New Scenario: Use Azure Policy to audit if Azure Arc-enabled servers meet security baseline requirements](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_security_baseline/)
- [Bug fix: CentOS VM Arc Onboarding Failure #957](https://github.com/microsoft/azure_arc/issues/957)
- [Bug fix: VMware vSphere Windows Server VMs VMTools update #940](https://github.com/microsoft/azure_arc/issues/940)

#### Azure Arc-enabled Kubernetes scenarios

- [Updated Scenario: Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider #980](https://github.com/microsoft/azure_arc/issues/980)
- [New Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on Cluster API as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_gitops_helm/)
- [New Scenario: Use Azure Policy on an Azure-Arc enabled Kubernetes cluster for applying ingress/egress rules with Calico network policy](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/calico/)

#### Azure Arc-enabled data services scenarios

- [Enhancement: Updates to Arc Data Services for Feb 2022 release #993](https://github.com/microsoft/azure_arc/pull/993)

#### Jumpstart ArcBox

- [ArcBox optimizations #965](https://github.com/microsoft/azure_arc/pull/965)
  - Replacing _sed_ with Kustomize functionality
  - Adding _templateBaseUrl_ parameter to the _installCAPI.sh_ script
  - Adding kubeconfig copy functionality for easy CAPI Management cluster (k3s) operations
  - Adding cluster naming "fail safe" functionality around CAPI Arc K8s onboarding
  - Bumping _ArcBox-CAPI-MGMT_ and _ArcBox-K3s_ OS to Ubuntu 20.04
  - Bumping CAPI K8s version to 1.22.6
  - Bumping CAPZ version to 1.1.1
  - Bumping data controller version docker images version to v1.3.0_2022-01-27
  - Enhanced Troubleshooting section + screenshots
  - Updating all VMs SKU to v4

### January 2022

#### Release highlights

- [Announcing Jumpstart ArcBox 2.0 release](https://aka.ms/ArcBox2Blog)

- New Azure Arc-enabled servers scenarios

- New Azure Arc-enabled Kubernetes scenarios

- Azure Arc-enabled data services enhancements

- [Product rebranding: Microsoft Defender for Cloud and Microsoft Container Registry #927](https://github.com/microsoft/azure_arc/issues/925)

#### Azure Arc-enabled servers scenarios

- [New Scenario: Connect an existing Windows server to Azure Arc using Configuration Manager with PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/scaled_deployment/configuration_manager_scaled_runscript/)

- [New Scenario: Connect an existing Windows server to Azure Arc using Configuration Manager with a Task Sequence](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/scaled_deployment/configuration_manager_scaled_tasksequence/)

- [Updated Scenario: Update Sentinel scenario with the new onboarding method #933](https://github.com/microsoft/azure_arc/issues/933)

- [Bug fix: Windows Server Virtual Machine won't register to Azure Arc #918](https://github.com/microsoft/azure_arc/issues/918)

- [VMware vSphere Windows Server VMs VMTools update #940](https://github.com/microsoft/azure_arc/issues/940)

#### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy GitOps configurations and perform basic GitOps flow on Cluster API as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_gitops_basic/)

- [Bug fix: Service principle azure role doesn't have proper rights configured #861](https://github.com/microsoft/azure_arc/issues/861)

- [Bug fix: k3s Azure ARM template #885](https://github.com/microsoft/azure_arc/issues/885)

- [Bug fix: Cloud Defender K8s extension failing to install #900](https://github.com/microsoft/azure_arc/issues/900)

#### Azure Arc-enabled data services scenarios

- [Enhancement: Add support for data controller auto-upload logs and metrics #901](https://github.com/microsoft/azure_arc/issues/901)

- [Bug fix: Creating data controller for the November release using kubectl #876](https://github.com/microsoft/azure_arc/issues/876)

## 2021

2021 archived release notes can be found [here](https://github.com/microsoft/azure_arc/tree/main/docs/release_notes/archive/2021.md).
