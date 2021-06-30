---
type: docs
title: "Jumpstart Release Notes"
linkTitle: "Jumpstart Release Notes"
weight: 3
---

# Azure Arc Jumpstart release notes

**Release notes will be released on the first week of each month and will cover the previous month.**

## June 2021

### General Jumpstart enhancements

* In this milestone, we introduced our new hosting show ["Jumpstart Lightning"](https://aka.ms/JumpstartLightning-blog), show where you get a chance to share with our team and the world your Azure Arc, Jumpstart contribution and Hybrid cloud awesome stories.

### Azure Arc enabled servers scenarios

* [New Scenario: Deploying Windows Server virtual machine in Azure Stack HCI and connect it to Azure Arc using Powershell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure_stack_hci/azure_stack_hci_windows/)

* [Bug fix: existing linux server onboarding fails #570](https://github.com/microsoft/azure_arc/issues/570)

### Azure Arc enabled Kubernetes scenarios

* [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster #552](https://github.com/microsoft/azure_arc/issues/552)

* [Bug fix: AKS on Azure Stack HCI PowerShell - Preview Note #583](https://github.com/microsoft/azure_arc/issues/583)

* [Bug fix: existing kube config is overwritten instead of merged #586](https://github.com/microsoft/azure_arc/issues/586)

* [Bug fix: Cluster API fails with no "cluster" resource available #617](https://github.com/microsoft/azure_arc/issues/617)

### Azure Arc enabled data services scenarios

* [New Scenario: Deploying vanilla Azure Arc enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/dc_vanilla/)

* [New Scenario: Deploying SQLMI Azure Arc enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/mssql_mi/)

* [New Scenario: Deploying PostgreSQL Hyperscale Azure Arc enabled data services in directly connected mode using Cluster API](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/cluster_api/capi_azure/arm_template/postgresql_hyperscale/)

* [New Scenario: Deploying vanilla Azure Arc enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/dc_vanilla/)

* [New Scenario: Deploying SQLMI Azure Arc enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/mssql_mi/)

* [New Scenario: Deploying PostgreSQL Hyperscale Azure Arc enabled data services in directly connected mode using MicroK8s](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/microk8s/azure/arm_template/postgresql_hyperscale/)

* [Updated Scenario: Deploying vanilla Azure Arc enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_dc_vanilla_arm_template/)

* [Updated Scenario: Deploying SQLMI Azure Arc enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_mi_arm_template/)

* [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc enabled data services in directly connected mode using AKS](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_hyperscale_arm_template/)

* [Updated Scenario: Deploying vanilla Azure Arc enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_dc_vanilla_terraform/)

* [Updated Scenario: Deploying SQLMI Azure Arc enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)

* [Updated Scenario: Deploying PostgreSQL Hyperscale Azure Arc enabled data services in directly connected mode using GKE](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_hs_terraform/)

* [Bug fix: SQL MI Server alias for connection contains wrong value #561](https://github.com/microsoft/azure_arc/issues/561)

### Jumpstart ArcBox

* Azure Arc-enabled data services components of ArcBox have been updated to use [directly connected mode](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity#connectivity-modes).
* Required resource providers are now enabled automatically as part of the automation scripts.
* Per updated Azure Arc-enabled data services requirements, ArcBox region support is restricted to East US, Northern Europe, and Western Europe.
* Incorporated streamlined modular automation approach for Azure Arc-enabled data services used by the primary Jumpstart data services scenarios.

### Azure Arc Jumpstart YouTube channel demos

[New Demo: Deploy SQL Managed Instance on GKE with Azure Arc enabled data services](https://youtu.be/1jjPmaTa3oc)

## May 2021

### General Jumpstart enhancements

* In this milestone, we released the ["Jumpstart ArcBox" solution](https://azurearcjumpstart.io/azure_jumpstart_arcbox/), a sandbox environment that allows users to explore all the major capabilities of Azure Arc.

* A new ["Azure Arc and Azure Lighthouse"](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_lighthouse/) was added.

* [Added new disclaimer security best practices](https://github.com/microsoft/azure_arc/pull/531)

* All Terraform-based automation's were updated to support v0.15

### Azure Arc enabled servers scenarios

* [Jumpstart enhancement: Added correlation ID to Arc server onboarding scripts](https://github.com/microsoft/azure_arc/pull/537)

### Azure Arc enabled Kubernetes scenarios

* [New Scenario: Integrate Azure Defender with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_defender_extension/)

* [New Scenario: Deploy AKS cluster on Azure IoT Edge and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/iot_uses_cases/aks/)

* [New Scenario: Integrate Open Service Mesh (OSM) with Cluster API as an Azure Arc Connected Cluster using Kubernetes extension](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_osm_extension/)

* [Bug fix: EKS cluster Terraform plan #521](https://github.com/microsoft/azure_arc/issues/521)

### Azure Arc enabled data services scenarios

* [Bug fix: adding psql to client vm #519](https://github.com/microsoft/azure_arc/issues/519)

* [Bug fix: Arc DataService on GCP-GKE - no successful deployment - free account is not enough #520](https://github.com/microsoft/azure_arc/issues/520)

* [Bug fix: SQL MI Server alias for connection contains wrong value #561](https://github.com/microsoft/azure_arc/issues/561)

* [Jumpstart enhancement: fetching data services IP's based on kubectl #566](https://github.com/microsoft/azure_arc/issues/566)

### Azure Arc Jumpstart YouTube channel demos

[New Demo: Azure Defender extension on Azure Arc enabled Kubernetes](https://www.youtube.com/watch?v=-B1-X4hCR98)

## April 2021

### Azure Arc enabled Kubernetes scenarios

* [New Scenario: Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster using Kubernetes extension](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_monitor_extension/)

* [New Scenario: Deploy Alibaba Cloud Container Service for Kubernetes cluster and connect it to Azure Arc using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/alibaba/alibaba_terraform/)

* [Bug fix: GKE cluster Terraform plan - az_connect_gke.sh link #455](https://github.com/microsoft/azure_arc/issues/455)

* [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Fork vs Clone #459](https://github.com/microsoft/azure_arc/issues/459)

* [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Helm Endpoint #460](https://github.com/microsoft/azure_arc/issues/460)

* [Bug fix: Create cluster with arc_capi_azure.sh hangs when vm SKU of control plane and node are not the same #480](https://github.com/microsoft/azure_arc/issues/480)

* [Bug fix: EKS cluster Terraform plan #521](https://github.com/microsoft/azure_arc/issues/521)

### Azure Arc enabled data services scenarios

* [New Scenario: Deploy Azure SQL Managed Instance on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_arm_template_ado/)

* [New Scenario: Deploy Azure PostgreSQL Hyperscale on AKS using Azure DevOps Release Pipeline](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_postgresql_hyperscale_arm_template_ado/)

* [New Scenario: Deploy a SQL Managed Instance on EKS using Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/eks/eks_mssql_mi/)

* [Bug fix: SECURITY Vulnerability : PostgreSQL port 5432 opened to * #396](https://github.com/microsoft/azure_arc/issues/396)

* [Bug fix: GKE default storage class #493](https://github.com/microsoft/azure_arc/issues/493)

* [Bug fix: Data Client VM ARM template has inbound ports open for MSSQL and PostGres #497](https://github.com/microsoft/azure_arc/issues/497)

* [Bug fix: wrong uri #511](https://github.com/microsoft/azure_arc/issues/511)

* [Bug fix: remove quotes in POSTGRES_DATASIZE and POSTGRES_WORKER_NODE_COUNT #512](https://github.com/microsoft/azure_arc/issues/512)

* [Feature request: Adding psql to client vm #519](https://github.com/microsoft/azure_arc/issues/519)

## March 2021

### General Jumpstart enhancements

* In this milestone, we released our [Jumpstart Scenario Write-up Guidelines](https://azurearcjumpstart.io/scenario_guidelines/) document to help our community with scenarios contribution.

* [Update the "Feature request" template to include new write-up guidelines #473](https://github.com/microsoft/azure_arc/issues/473)

### Azure Arc enabled Kubernetes scenarios

* [New Scenario: Deploy GitOps configurations and perform basic GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_basic/)

* [New Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on AKS on Azure Stack HCI as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_helm/)

* [New Scenario: Integrate Azure Monitor for Containers with MicroK8s as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/aks_stack_hci/aks_hci_gitops_helm/)

* [Bug fix: azure-arc-connectproxy-agent-deployment.yaml #429](https://github.com/microsoft/azure_arc/issues/429)

* [Bug fix: GKE cluster Terraform plan - az_connect_gke.sh link #455](https://github.com/microsoft/azure_arc/issues/455)

* [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Fork vs Clone #459](https://github.com/microsoft/azure_arc/issues/459)

* [Bug fix: Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster - Helm Endpoint #460](https://github.com/microsoft/azure_arc/issues/460)

### Azure Arc enabled data services scenarios

* [Bug fix: SQL MI AKS ARM Template #437](https://github.com/microsoft/azure_arc/issues/437)

## February 2021

### Azure Arc Jumpstart YouTube channel demos

In this milestone, we launched our new YouTube channel.

* [New Demo: Apply GitOps Configuration on a kind based cluster with Azure Arc enabled Kubernetes](https://youtu.be/w1ofpTnRuw4)

* [New Demo: Linux Custom Script Extension integration with Azure Arc enabled servers](https://youtu.be/srTA97rvOMc)

* [New Demo: Azure Key Vault integration with Azure Arc enabled servers](https://youtu.be/nKqIn-Cgh8g)

* [New Demo: Azure Arc enabled Kubernetes with Cluster API and the Azure provider](https://youtu.be/mhHELY6O3VI)

* [New Demo: PostgreSQL Hyperscale on AKS with Azure Arc enabled data services](https://youtu.be/jSogdbDRcpw)

* [New Demo: Inventory management with Azure Arc enabled servers](https://youtu.be/fM0WW08LUoQ)

* [New Demo: Onboard Azure Arc enabled Kubernetes Cluster using kind](https://youtu.be/Xb3mO5vhnGQ)

* [New Demo: Azure Defender integration with Azure Arc enabled servers](https://youtu.be/PS5YLEOenik)

* [New Demo: Azure Automation Update Management integration with Azure Arc enabled servers](https://youtu.be/J4WuQC6CmZo)

* [New Demo: Windows Server onboarding with Azure Arc enabled servers](https://youtu.be/F_0w_fEqx6Y)

* [New Demo: Unified Operations with Azure Arc](https://youtu.be/B2qn_nLDw0k)

* [New Demo: VMware vSphere scaled onboarding with Azure Arc enabled servers](https://youtu.be/AxmwHJ-w93I)

* [New Demo: Azure Arc enabled Kubernetes with Azure Red Hat OpenShift](https://youtu.be/928iWrK4QWo)

* [New Demo: AWS EC2 scaled onboarding with Azure Arc enabled servers using Ansible](https://youtu.be/0Eb2j8XlxUQ)

* [New Demo: Windows Server Custom Script Extension with Azure Arc enabled servers](https://youtu.be/0TYn5wgQXow)

* [New Demo: Manual Ubuntu server onboarding with Azure Arc enabled servers](https://youtu.be/0hOPluMVES4)

* [New Demo: Azure Kubernetes Service (AKS) on HCI with Azure Arc enabled Kubernetes](https://youtu.be/7U3CQnm9SPg)

* [New Demo: Azure Monitor for containers with Azure Arc enabled Kubernetes](https://youtu.be/8KNu2RSVwCs)

### Azure Arc enabled Kubernetes scenarios

* [New Scenario: Deploy AKS cluster on Azure Stack HCI and connect it to Azure Arc using PowerShell](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_stack_hci/aks_hci_powershell/)

### Azure Arc enabled data services scenarios

* [New Scenario: Deploy an Azure PostgreSQL Hyperscale Deployment on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_postgres_hs_terraform/)

### Bug fixes & alignments

* [Remove Azure Arc enabled Kubernetes preview disclaimer ]()

---
## January 2021

### Azure Arc enabled servers scenarios

* [New Scenario: Deploy Azure Key Vault Extension to Azure Arc enabled Ubuntu server and use a Key Vault managed certificate with Nginx](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_keyvault/)

* [Updated Scenario: Connect Azure Arc enabled servers to Azure Security Center](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_securitycenter/)

### Azure Arc enabled SQL Server scenarios

* [All the scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_sqlsrv/) in this section were updated to support new Azure Arc enabled SQL Server onboarding script.

### Azure Arc enabled Kubernetes scenarios

* [New Scenario: Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/cluster_api/capi_azure/)

* [Updated Scenario: Deploy GitOps configurations and perform Helm-based GitOps flow on GKE as an Azure Arc Connected Cluster](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_gitops_helm/)

### Azure Arc enabled data services scenarios

* [All the scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/) in this section were updated to support ["Directly connected"](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity) mode

* [New Scenario: Deploy an Azure SQL Managed Instance on GKE using a Terraform plan](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/gke/gke_mssql_mi_terraform/)

### Bug fixes & alignments

* [AKS Arc Disclaimer #336](https://github.com/microsoft/azure_arc/issues/336)
