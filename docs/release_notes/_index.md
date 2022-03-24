---
type: docs
title: "Jumpstart Release Notes"
linkTitle: "Jumpstart Release Notes"
weight: 3
---

# Azure Arc Jumpstart release notes

**Release notes will be released on the first week of each month and will cover the previous month.**

## February 2022

### Release highlights and general Jumpstart enhancements

- In this release, we reached 100 individual Jumpstart scenarios!
- New Azure Arc-enabled servers scenario
- New Azure Arc-enabled Kubernetes scenarios
- Azure Arc-enabled data services enhancements
- Multiple Jumpstart ArcBox optimizations, enhancements and bug fixes

### Azure Arc-enabled servers scenarios

- [New Scenario: Use Azure Policy to audit if Azure Arc-enabled servers meet security baseline requirements](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_security_baseline/)
- [Bug fix: CentOS VM Arc Onboarding Failure #957](https://github.com/microsoft/azure_arc/issues/957)
- [Bug fix: VMware vSphere Windows Server VMs VMTools update #940](https://github.com/microsoft/azure_arc/issues/940)

### Azure Arc-enabled Kubernetes scenarios

- [Updated Scenario: Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider #980](https://github.com/microsoft/azure_arc/issues/980)
- [New Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on Cluster API as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_gitops_helm/)
- [New Scenario: Use Azure Policy on an Azure-Arc enabled Kubernetes cluster for applying ingress/egress rules with Calico network policy](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/multi_distributions/calico/)

### Azure Arc-enabled data services scenarios

- [Enhancement: Updates to Arc Data Services for Feb 2022 release #993](https://github.com/microsoft/azure_arc/pull/993)

### Jumpstart ArcBox

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

## January 2022

### Release highlights and general Jumpstart enhancements

- [Announcing Jumpstart ArcBox 2.0 release](https://aka.ms/ArcBox2Blog)

- New Azure Arc-enabled servers scenarios

- New Azure Arc-enabled Kubernetes scenarios

- Azure Arc-enabled data services enhancements

- [Product rebranding: Microsoft Defender for Cloud and Microsoft Container Registry #927](https://github.com/microsoft/azure_arc/issues/925)

### Azure Arc-enabled servers scenarios

- [New Scenario: Connect an existing Windows server to Azure Arc using Configuration Manager with PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/scaled_deployment/configuration_manager_scaled_runscript/)

- [New Scenario: Connect an existing Windows server to Azure Arc using Configuration Manager with a Task Sequence](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/scaled_deployment/configuration_manager_scaled_tasksequence/)

- [Updated Scenario: Update Sentinel scenario with the new onboarding method #933](https://github.com/microsoft/azure_arc/issues/933)

- [Bug fix: Windows Server Virtual Machine won't register to Azure Arc #918](https://github.com/microsoft/azure_arc/issues/918)

- [VMware vSphere Windows Server VMs VMTools update #940](https://github.com/microsoft/azure_arc/issues/940)

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy GitOps configurations and perform basic GitOps flow on Cluster API as an Azure Arc Connected Cluster (Flux v2)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_gitops_basic/)

- [Bug fix: Service principle azure role doesn't have proper rights configured #861](https://github.com/microsoft/azure_arc/issues/861)

- [Bug fix: k3s Azure ARM template #885](https://github.com/microsoft/azure_arc/issues/885)

- [Bug fix: Cloud Defender K8s extension failing to install #900](https://github.com/microsoft/azure_arc/issues/900)

### Azure Arc-enabled data services scenarios

- [Enhancement: Add support for data controller auto-upload logs and metrics #901](https://github.com/microsoft/azure_arc/issues/901)

- [Bug fix: Creating data controller for the November release using kubectl #876](https://github.com/microsoft/azure_arc/issues/876)

## December 2021

All of December 2021 release notes were consolidated to the January 2022 release notes.

## November 2021

### Release highlights and general Jumpstart enhancements

- New scenario for Azure Key Vault with Cluster API as an Azure Arc Connected Cluster

- Support for Cluster API with Azure Provider v1.0.0

- Support for Azure Arc-enabled data services 11/21 release

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Integrate Azure Key Vault with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_keyvault_extension/)

- [Enhancement: Update Kubernetes Cluster API scenario to support CAPZ v1.0.0 #862](https://github.com/microsoft/azure_arc/issues/862)

- [Bug fix: gitops scenario uses helm even in "basic" scenario #814](https://github.com/microsoft/azure_arc/issues/814)

### Azure Arc-enabled data services scenarios

- [Enhancement: Support for Azure Arc-enabled data services 11/21 release #839](https://github.com/microsoft/azure_arc/issues/839)

- [Enhancement: Support for CAPZ 1.0.0 #840](https://github.com/microsoft/azure_arc/issues/840)

### Azure Arc-enabled app service

- [Bug fix: Logic Apps on AKS scenario fails to complete on client VM #837](https://github.com/microsoft/azure_arc/issues/837)

### Jumpstart ArcBox

- [Bug fix: Jumpstart ArcBox deployment failure - mgmtArtifactsAndPolicyDeployment FAILED #813](https://github.com/microsoft/azure_arc/issues/813)

## October 2021

### Release highlights and general Jumpstart enhancements

- New Azure Arc-enabled servers scenario

- New Azure Arc-enabled app service scenario

- Updating all scenarios with Azure CLI version to 2.25.0 or higher prerequisite

- Reliability bugs and docs fixes

### Azure Arc-enabled servers scenarios

- [New Scenario: Using Managed Identity on an Ubuntu Azure Arc-enabled server](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_managed_identity/linux/)

- [Bug fix: Broken VHD blob link in Azure Arc-enabled servers for HCI scenario #802](https://github.com/microsoft/azure_arc/issues/802)

### Azure Arc-enabled Kubernetes scenarios

- [Bug fix: The GKE basic gitops scenario screenshots to not match the actual deployments #783](https://github.com/microsoft/azure_arc/issues/783)

- [Bug fix: k3s Azure ARM template - hardcoded iod #785](https://github.com/microsoft/azure_arc/issues/785)

- [Bug fix: EKS K8s onboarding scenario - environment variables mapping to Terraform variables need to be prefixed with TF_VAR #792](https://github.com/microsoft/azure_arc/issues/792)

- [Bug fix: gitops scenario uses helm even in "basic" scenario #814](https://github.com/microsoft/azure_arc/issues/814)

### Azure Arc-enabled data services scenarios

- [Bug fix: PostgreSQL Hyperscale ARM Template failing #765](https://github.com/microsoft/azure_arc/issues/765)

- [Bug fix: az cli 2.25 bump](https://github.com/microsoft/azure_arc/issues/805)

### Azure Arc-enabled app service

- [New Scenario: Deploy an Azure API Management gateway on Cluster API (CAPI) using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/apimgmt_arm_template/)

### Jumpstart ArcBox

- [Enhancement: Support for CAPZ 1.0.0 #840](https://github.com/microsoft/azure_arc/issues/840)

- [Bug fix: Azure ArcBox fail to deploy because of bad dependencies between nested templates #809](https://github.com/microsoft/azure_arc/issues/809)

## September 2021

### Release highlights and general Jumpstart enhancements

- New Azure Arc-enabled app service scenarios

- Multiple security and benchmark enhancements

- Updating all Azure-based scenarios to use Windows Server 2022

- In this release, we introduced open-source version of the [Azure Arc validated architecture diagrams and visualization](https://azurearcjumpstart.io/overview/#diagrams)

### Azure Arc-enabled Kubernetes scenarios

- [Bug fix: Terraform plan for GKE basic onboarding not compatible with TF 1.0 or with GKE clusters running 1.19 or higher #781](https://github.com/microsoft/azure_arc/issues/781)

### Azure Arc-enabled data services scenarios

- [Enhancement: Change SQL MI AKS LB port from 1433 to non-standard #763](https://github.com/microsoft/azure_arc/issues/763)

- [Enhancement: Upgrade Client-VM to Windows Server 2022 on Azure-based scenarios #740](https://github.com/microsoft/azure_arc/issues/740)

- [Enhancement: Benchmarking tools for Azure Arc-enabled data services scenarios #739](https://github.com/microsoft/azure_arc/issues/739)

- [Bug fix: PostgreSQL Hyperscale Deployment on EKS - data controller deployment failure #743](https://github.com/microsoft/azure_arc/issues/743)

### Azure Arc-enabled app service

- [Enhancement: Upgrade Client-VM to Windows Server 2022 on Azure-based scenarios #740](https://github.com/microsoft/azure_arc/issues/740)

- [New Scenario: Deploy an Azure API Management gateway on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_azure_apimgmt_arm_template/)

- [New Scenario: Deploy an App Service app using custom container on Cluster API using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/apps_service_arm_template/)

- [New Scenario: Deploy an App Service app using custom container on Cluster API using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/azure_function_arm_template/)

### Azure Arc-enabled machine learning scenarios

- [Enhancement: Upgrade Client-VM to Windows Server 2022 on Azure-based scenarios #740](https://github.com/microsoft/azure_arc/issues/740)

- [Bug fix: error when installing AZURE ML training model piece #758](https://github.com/microsoft/azure_arc/issues/758)

### Jumpstart ArcBox

- [Enhancement: Change SQL MI and PostgreSQL ports to non standard #767](https://github.com/microsoft/azure_arc/issues/767)

- [Enhancement: Upgrade Client-VM to Windows Server 2022 on Azure-based scenarios #740](https://github.com/microsoft/azure_arc/issues/740)

- [Enhancement: Benchmarking tools for Azure Arc-enabled data services scenarios #739](https://github.com/microsoft/azure_arc/issues/739)

- [Enhancement: Remove custom-locations-oid parameter from connected cluster onboarding scripts and adding _`--kubeconfig`_ parameter to custom location creation #778](https://github.com/microsoft/azure_arc/pull/778)

## August 2021

### Release highlights and general Jumpstart enhancements

- New version of Jumpstart ArcBox

- New scenarios for Azure Arc-enabled SQL Managed Instance high-availability

- New scenario for Azure Arc-enabled app services with Logic App

- First scenario for Azure Arc-enabled machine learning

- Critical enhancements for Cluster API based scenarios

### Azure Arc-enabled servers scenarios

- [New demo: Enable Azure Automanage on an Azure Arc-enabled server using an ARM template](https://www.youtube.com/watch?v=Tj1ypT516zM)

- [Bug fix: Update Management #725](https://github.com/microsoft/azure_arc/issues/725)

### Azure Arc-enabled Kubernetes scenarios

- [Bug fix: Azure Cluster API scenario for Azure Arc enabled Kubernetes script variables not matching #696](https://github.com/microsoft/azure_arc/issues/696)

### Azure Arc-enabled data services scenarios

- [New Scenario: Perform database failover with SQL Managed Instance Availability Groups on AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/aks/aks_mssql_ha/)

- [New Scenario: Perform database failover with SQL Managed Instance Availability Groups on Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/cluster_api/capi_azure/capi_mssql_ha/)

- [Bug fix: failed to get file "infrastructure-components.yaml" #688](https://github.com/microsoft/azure_arc/issues/688)

- [Bug fix: Azure Arc enabled data services for EKS: Failed to load state error #699](https://github.com/microsoft/azure_arc/issues/699)

- [Bug fix: Azure Arc enabled data services for EKS : logon script does not end #711](https://github.com/microsoft/azure_arc/issues/711)

### Azure Arc-enabled app service

- [New Scenario: Deploy Azure Logic App on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_logic_app_arm_template/)

### Azure Arc-enabled machine learning scenarios

- [New Scenario: Train, Deploy and call inference on an image classification model - MNIST dataset from Azure Blob Storage](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_ml/aks/aks_blob_mnist_arm_template/)

### Jumpstart ArcBox

- New [Azure Monitor workbook](https://azurearcjumpstart.io/azure_jumpstart_arcbox/workbook/) included that provides single pane of glass monitoring for all ArcBox resources.
- Remove port 22 from Cluster API control plane Network Security Group
- Update clusterctl to v0.4.2
- Update CAPZ provider to v0.5.2
- Update Kubernetes version to 1.20.10
- Automation optimizations
- Documentation revisions

## July 2021

### Release highlights and general Jumpstart enhancements

- First new scenarios for Azure Arc-enabled app services

- Major updates to support general availability of Azure Arc-enabled data services with SQL Managed Instance

- Critical bug fixes for Cluster API based scenarios

- Jumpstart ArcBox enhancements

### Azure Arc-enabled servers scenarios

- [New Scenario: Enable Azure Automanage on an Azure Arc-enabled server using an ARM template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_automanage/)

- [Updated Scenario: Enable Update Management on Azure Arc-enabled servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_updatemanagement/)

- [Bug fix: az_connect_linux.sh will not work as it is on RHEL/CentOS #613](https://github.com/microsoft/azure_arc/issues/613)

- [Bug fix: ARM Template fails deployment Update Management on Azure Arc-enabled servers #631](https://github.com/microsoft/azure_arc/issues/631)

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Integrate Azure Monitor for Containers with AKS on Azure Stack HCI as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_monitor/aks_hci_monitor_extension/)

- [Bug fix: Cluster API fails with no "cluster" resource available #617](https://github.com/microsoft/azure_arc/issues/617)

### Azure Arc-enabled data services scenarios

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/dc_vanilla/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/mssql_mi/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/postgresql_hyperscale/)

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/dc_vanilla/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/mssql_mi/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/postgresql_hyperscale/)

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_dc_vanilla_arm_template/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_mi_arm_template/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_hyperscale_arm_template/)

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_dc_vanilla_terraform/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_hs_terraform/)

- [Bug fix: Data Controller ARM Template - Failure when using a service principal scoped to a resource group #624](https://github.com/microsoft/azure_arc/issues/624)

- [Bug fix: Azure Arc using Cluster API Azure provider > 0.5.0 #664](https://github.com/microsoft/azure_arc/issues/664)

### Azure Arc-enabled app services scenarios

- [New Scenario: Deploy an App Service app using custom container on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_app_service_arm_template/)

- [New Scenario: Deploy Azure Function application on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_azure_function_arm_template/)

- [Bug fix: Error when checking initialize status of K8SE stamp with kubectl Unexpected output from kubectl.exe when getting pod statuses #621](https://github.com/microsoft/azure_arc/issues/621)

### Jumpstart ArcBox

- Improvements to Azure Policy experience. Updated policy names with (ArcBox) callout to easily identify policies created by ArcBox deployment. New policies to support onboarding Dependency Agents and Azure Defender for Kubernetes.
- Add Change Tracking, Security, VMInsights solutions to deployment.
- New troubleshooting section in documentation.
- Add automatic provisioning for Microsoft.HybridCompute and _Microsoft.GuestConfiguration_ resource providers.
- Various fixes to Cluster API and Data Services components.
- Automation optimizations and cleanup.

- [Bug fix: Jumpstart ArcBox - Subscription missing Azure ARC server resource providers pre-requisite #672](https://github.com/microsoft/azure_arc/issues/672)

- [Bug fix: Kubernetes Arc Namespace not created - along with resources #674](https://github.com/microsoft/azure_arc/issues/674)

- [Bug fix: failed to get file "infrastructure-components.yaml" #688](https://github.com/microsoft/azure_arc/issues/688)

## June 2021

### Release highlights and general Jumpstart enhancements

- In this milestone, we introduced our new hosting show ["Jumpstart Lightning"](https://aka.ms/JumpstartLightning-blog), show where you get a chance to share with our team and the world your Azure Arc, Jumpstart contribution and Hybrid cloud awesome stories.

### Azure Arc-enabled servers scenarios

- [New Scenario: Deploying Windows Server virtual machine in Azure Stack HCI and connect it to Azure Arc using PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure_stack_hci/azure_stack_hci_windows/)

- [Bug fix: existing linux server onboarding fails #570](https://github.com/microsoft/azure_arc/issues/570)

### Azure Arc-enabled Kubernetes scenarios

- [Updated Scenario: Deploy Alibaba Cloud Container Service for Kubernetes cluster and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/alibaba/alibaba_terraform/)

- [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster #552](https://github.com/microsoft/azure_arc/issues/552)

- [Bug fix: AKS on Azure Stack HCI PowerShell - Preview Note #583](https://github.com/microsoft/azure_arc/issues/583)

- [Bug fix: existing kube config is overwritten instead of merged #586](https://github.com/microsoft/azure_arc/issues/586)

- [Bug fix: Cluster API fails with no "cluster" resource available #617](https://github.com/microsoft/azure_arc/issues/617)

### Azure Arc-enabled data services scenarios

- [New Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/dc_vanilla/)

- [New Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/mssql_mi/)

- [New Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/postgresql_hyperscale/)

- [New Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/dc_vanilla/)

- [New Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/mssql_mi/)

- [New Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/postgresql_hyperscale/)

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_dc_vanilla_arm_template/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_mi_arm_template/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_hyperscale_arm_template/)

- [Updated Scenario: Deploying vanilla Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_dc_vanilla_terraform/)

- [Updated Scenario: Deploying SQLMI Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)

- [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc-enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_hs_terraform/)

- [Bug fix: SQL MI Server alias for connection contains wrong value #561](https://github.com/microsoft/azure_arc/issues/561)

### Jumpstart ArcBox

- Azure Arc-enabled data services components of ArcBox have been updated to use [directly connected mode](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity#connectivity-modes).
- Required resource providers are now enabled automatically as part of the automation scripts.
- Per updated Azure Arc-enabled data services requirements, ArcBox region support is restricted to East US, Northern Europe, and Western Europe.
- Incorporated streamlined modular automation approach for Azure Arc-enabled data services used by the primary Jumpstart data services scenarios.

### Azure Arc Jumpstart YouTube channel demos

[New Demo: Deploy SQL Managed Instance on GKE with Azure Arc-enabled data services](https://youtu.be/1jjPmaTa3oc)

## May 2021

### Release highlights and general Jumpstart enhancements

- In this milestone, we released the ["Jumpstart ArcBox" solution](https://azurearcjumpstart.io/azure_jumpstart_arcbox/), a sandbox environment that allows users to explore all the major capabilities of Azure Arc.

- A new ["Azure Arc and Azure Lighthouse"](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_lighthouse/) was added.

- [Added new disclaimer security best practices](https://github.com/microsoft/azure_arc/pull/531)

- All Terraform-based automation's were updated to support v0.15

### Azure Arc-enabled servers scenarios

- [Jumpstart enhancement: Added correlation ID to Arc server onboarding scripts](https://github.com/microsoft/azure_arc/pull/537)

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Integrate Azure Defender with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_defender_extension/)

- [New Scenario: Deploy AKS cluster on Azure IoT Edge and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/iot_uses_cases/aks/)

- [New Scenario: Integrate Open Service Mesh (OSM) with Cluster API as an Azure Arc Connected Cluster using Kubernetes extension](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_osm_extension/)

- [Bug fix: EKS cluster Terraform plan #521](https://github.com/microsoft/azure_arc/issues/521)

### Azure Arc-enabled data services scenarios

- [Bug fix: adding psql to client vm #519](https://github.com/microsoft/azure_arc/issues/519)

- [Bug fix: Arc DataService on GCP-GKE - no successful deployment - free account is not enough #520](https://github.com/microsoft/azure_arc/issues/520)

- [Bug fix: SQL MI Server alias for connection contains wrong value #561](https://github.com/microsoft/azure_arc/issues/561)

- [Jumpstart enhancement: fetching data services IP's based on kubectl #566](https://github.com/microsoft/azure_arc/issues/566)

### Azure Arc Jumpstart YouTube channel demos

[New Demo: Azure Defender extension on Azure Arc-enabled Kubernetes](https://www.youtube.com/watch?v=-B1-X4hCR98)

## April 2021

### Release highlights and general Jumpstart enhancements

- [New Scenario: Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster using Kubernetes extension](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_monitor_extension/)

- [New Scenario: Deploy Alibaba Cloud Container Service for Kubernetes cluster and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/alibaba/alibaba_terraform/)

- [Bug fix: GKE cluster Terraform plan - az_connect_gke.sh link #455](https://github.com/microsoft/azure_arc/issues/455)

- [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Fork vs Clone #459](https://github.com/microsoft/azure_arc/issues/459)

- [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Helm Endpoint #460](https://github.com/microsoft/azure_arc/issues/460)

- [Bug fix: Create cluster with arc_capi_azure.sh hangs when vm SKU of control plane and node are not the same #480](https://github.com/microsoft/azure_arc/issues/480)

- [Bug fix: EKS cluster Terraform plan #521](https://github.com/microsoft/azure_arc/issues/521)

### Azure Arc-enabled data services scenarios

- [New Scenario: Deploy Azure SQL Managed Instance on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_arm_template_ado/)

- [New Scenario: Deploy Azure PostgreSQL Hyperscale on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_hyperscale_arm_template_ado/)

- [New Scenario: Deploy a SQL Managed Instance on EKS using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/eks/eks_mssql_mi/)

- [Bug fix: SECURITY Vulnerability : PostgreSQL port 5432 opened to * #396](https://github.com/microsoft/azure_arc/issues/396)

- [Bug fix: GKE default storage class #493](https://github.com/microsoft/azure_arc/issues/493)

- [Bug fix: Data Client VM ARM template has inbound ports open for MSSQL and PostGres #497](https://github.com/microsoft/azure_arc/issues/497)

- [Bug fix: wrong uri #511](https://github.com/microsoft/azure_arc/issues/511)

- [Bug fix: remove quotes in POSTGRES_DATASIZE and POSTGRES_WORKER_NODE_COUNT #512](https://github.com/microsoft/azure_arc/issues/512)

- [Feature request: Adding psql to client vm #519](https://github.com/microsoft/azure_arc/issues/519)

## March 2021

### Release highlights and general Jumpstart enhancements

- In this milestone, we released our [Jumpstart Scenario Write-up Guidelines](https://azurearcjumpstart.io/scenario_guidelines/) document to help our community with scenarios contribution.

- [Update the "Feature request" template to include new write-up guidelines #473](https://github.com/microsoft/azure_arc/issues/473)

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy GitOps configurations and perform basic GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_basic/)

- [New Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_helm/)

- [New Scenario: Integrate Azure Monitor for Containers with MicroK8s as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_helm/)

- [Bug fix: azure-arc-connectproxy-agent-deployment.yaml #429](https://github.com/microsoft/azure_arc/issues/429)

- [Bug fix: GKE cluster Terraform plan - az_connect_gke.sh link #455](https://github.com/microsoft/azure_arc/issues/455)

- [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Fork vs Clone #459](https://github.com/microsoft/azure_arc/issues/459)

- [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Helm Endpoint #460](https://github.com/microsoft/azure_arc/issues/460)

### Azure Arc-enabled data services scenarios

- [Bug fix: SQL MI AKS ARM Template #437](https://github.com/microsoft/azure_arc/issues/437)

## February 2021

### Azure Arc Jumpstart YouTube channel demos

In this milestone, we launched our new YouTube channel.

- [New Demo: Apply GitOps Configuration on a kind based cluster with Azure Arc-enabled Kubernetes](https://youtu.be/w1ofpTnRuw4)

- [New Demo: Linux Custom Script Extension integration with Azure Arc-enabled servers](https://youtu.be/srTA97rvOMc)

- [New Demo: Azure Key Vault integration with Azure Arc-enabled servers](https://youtu.be/nKqIn-Cgh8g)

- [New Demo: Azure Arc-enabled Kubernetes with Cluster API and the Azure provider](https://youtu.be/mhHELY6O3VI)

- [New Demo: PostgreSQL Hyperscale on AKS with Azure Arc-enabled data services](https://youtu.be/jSogdbDRcpw)

- [New Demo: Inventory management with Azure Arc-enabled servers](https://youtu.be/fM0WW08LUoQ)

- [New Demo: Onboard Azure Arc-enabled Kubernetes Cluster using kind](https://youtu.be/Xb3mO5vhnGQ)

- [New Demo: Azure Defender integration with Azure Arc-enabled servers](https://youtu.be/PS5YLEOenik)

- [New Demo: Azure Automation Update Management integration with Azure Arc-enabled servers](https://youtu.be/J4WuQC6CmZo)

- [New Demo: Windows Server onboarding with Azure Arc-enabled servers](https://youtu.be/F_0w_fEqx6Y)

- [New Demo: Unified Operations with Azure Arc](https://youtu.be/B2qn_nLDw0k)

- [New Demo: VMware vSphere scaled onboarding with Azure Arc-enabled servers](https://youtu.be/AxmwHJ-w93I)

- [New Demo: Azure Arc-enabled Kubernetes with Azure Red Hat OpenShift](https://youtu.be/928iWrK4QWo)

- [New Demo: AWS EC2 scaled onboarding with Azure Arc-enabled servers using Ansible](https://youtu.be/0Eb2j8XlxUQ)

- [New Demo: Windows Server Custom Script Extension with Azure Arc-enabled servers](https://youtu.be/0TYn5wgQXow)

- [New Demo: Manual Ubuntu server onboarding with Azure Arc-enabled servers](https://youtu.be/0hOPluMVES4)

- [New Demo: Azure Kubernetes Service (AKS) on HCI with Azure Arc-enabled Kubernetes](https://youtu.be/7U3CQnm9SPg)

- [New Demo: Azure Monitor for containers with Azure Arc-enabled Kubernetes](https://youtu.be/8KNu2RSVwCs)

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy AKS cluster on Azure Stack HCI and connect it to Azure Arc using PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_stack_hci/aks_hci_powershell/)

### Azure Arc-enabled data services scenarios

- [New Scenario: Deploy an Azure PostgreSQL Hyperscale Deployment on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_hs_terraform/)

## January 2021

### Azure Arc-enabled servers scenarios

- [New Scenario: Deploy Azure Key Vault Extension to Azure Arc-enabled Ubuntu server and use a Key Vault managed certificate with Nginx](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_keyvault/)

- [Updated Scenario: Connect Azure Arc-enabled servers to Azure Security Center](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_securitycenter/)

### Azure Arc-enabled SQL Server scenarios

- [All the scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_sqlsrv/) in this section were updated to support new Azure Arc-enabled SQL Server onboarding script.

### Azure Arc-enabled Kubernetes scenarios

- [New Scenario: Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/cluster_api/capi_azure/)

- [Updated Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on GKE as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_gitops_helm/)

### Azure Arc-enabled data services scenarios

- [All the scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/) in this section were updated to support ["Directly connected"](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity) mode

- [New Scenario: Deploy an Azure SQL Managed Instance on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)

### Bug fixes & alignments

- [AKS Arc Disclaimer #336](https://github.com/microsoft/azure_arc/issues/336)
