# Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multi-cloud, [Azure Arc](https://azure.microsoft.com/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multi-cloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multi-cloud environments for your data estate.

## Azure Arc Jumpstart

The following guides will walk you through the process of setting up demos that show how to get started with Azure Arc. They are designed with a "zero to hero" approach in mind and with as much automation as possible. The goal is for you to have a working Azure Arc demo environment spun up in no time so you can focus on showing the core values of the solution.

**Disclaimer: The intention for this repo is to focus on the core Azure Arc capabilities, deployment scenarios, use-cases and ease of use. It does not focus on Azure best-practices or the other tech and OSS projects being leveraged in the guides and code.**

## Azure Arc Story Time

Fabrikam Global Manufacturing runs workloads on different hardware, across on-premises datacenters, and multiple public clouds, with Microsoft Azure being the primary cloud. They also support IoT workloads deployed on the edge. Workloads include very diverse services and are based on either virtual machines, managed Platform-as-a-Service (PaaS) services, and container-based applications.

As mentioned, Fabrikam’s R&D teams are well-invested in containerized workloads for their modernized applications. As a result, they are using Kubernetes as their container orchestration platform. Kubernetes is deployed both as self-managed Kubernetes clusters in their on-premises environments and managed Kubernetes deployments in the cloud.

As part of their cloud-native practices with Azure being the main hyper-scale cloud, Fabrikam’s operations teams are standardized and taking advantage of Azure Resource Manager (ARM) capabilities such as (but not limited to) tagging, Azure Monitoring for VMs and containers, logging and telemetry, policy and government, Desired State Configuration (DSC), Update Management, Change Tracking, Inventory management, etc.

These practices and techniques are already well established for Azure-based workloads in use such as Azure VMs, Azure Kubernetes Service (AKS), Azure SQL, and many more. In order to take advantage of these well-established practices, Fabrikam is using Azure Arc to extend the ARM APIs to project and manage their workloads deployed outside of Azure. Once onboarded, Azure Arc projects resources as first-class citizens in Azure which can then take advantage of the ARM capabilities mentioned above. In addition, they are able to guarantee Kubernetes deployments and app consistency through GitOps-based configuration for their Kubernetes clusters in Azure, other clouds and on-premises.

With Azure Arc, Fabrikam is able to project resources and register them into Azure Resource Manager independently of where they run, so they have a single control plane and can extend cloud-native operations and governance beyond Azure.

<p align="center">
  <img src="img/architecture_white.jpg" width="90%"/>
</p>

## Azure Arc enabled Servers

The deployment scenarios below will guide you through onboarding various Windows and Linux server deployments to Azure with Azure Arc.

**Note: For a list of supported operating systems and Azure regions, please visit the official [Azure Arc docs](https://docs.microsoft.com/azure/azure-arc/servers/overview).**

### General

The following examples can be used to connect existing Windows or Linux servers to Azure with Azure Arc. Use these if you already have existing servers that you want to project into Azure.

* [Connect an existing Linux server to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_linux.md)

* [Connect an existing Windows machine to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_win.md)

### Microsoft Azure

The following guides in this section will walk you through how to project an Azure VM as an Azure Arc enabled server.
These guides, using Azure VM as the targeted Azure Arc server are designed **for demo and testing purposes ONLY and are not supported.**

In each guide, you find a detailed, technical explanation of the mechanism and why **it is not expected to project an Azure VM as an Azure Arc enabled server**.

* [Deploy a Windows Azure VM and connect it to Azure Arc using ARM Template](azure_arc_servers_jumpstart/docs/azure_arm_template_win.md)

* [Deploy an Ubuntu Azure VM and connect it to Azure Arc using ARM Template](azure_arc_servers_jumpstart/docs/azure_arm_template_linux.md)

### Vagrant

If you don't have any existing servers available, you can use [Vagrant](https://www.vagrantup.com/) to host a new server locally and onboard it to Azure. This will allow you to simulate "on-premises" servers from your local machine. 

* [Deploy a local Ubuntu VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_ubuntu.md)

* [Deploy a local Windows 10 VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_windows.md)

### Amazon Web Services (AWS)

Azure Arc can project servers into Azure from any public cloud. The following guides provide end-to-end deployment of new Linux servers in AWS EC2 and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Deploy an AWS EC2, Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/aws_terraform_ubuntu.md)

* [Deploy an AWS Amazon Linux 2 VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/aws_terraform_al2.md)

### Google Cloud Platform (GCP)

The following guides provide end-to-end deployment of new Windows or Linux servers in Google Cloud and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Deploy a GCP Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_ubuntu.md)

* [Deploy a GCP Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_windows.md)

### VMware

The following guides provide end-to-end deployment of new Windows or Linux servers in VMware and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Deploy a VMware vSphere Ubuntu Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/vmware_terraform_ubuntu.md)

* [Deploy a VMware vSphere Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/vmware_terraform_winsrv.md)

#### Azure Arc enabled Servers - Day-2 Scenarios & Use-Cases

Once you have server resources projected into Azure with Azure Arc, you can start to use native Azure tooling to manage the servers as native Azure resources. The following guides show examples of using Azure management tools such as resource tags, Azure Policy, Log Analytics, and more with Azure Arc enabled servers.

* [Tagging and querying server inventory across multiple clouds using Resource Graph Explorer](azure_arc_servers_jumpstart/docs/arc_inventory_tagging.md)

* [Deploying Microsoft Monitoring Agent Extension (MMA) to Azure Arc Linux and Windows VMs using Extension Management](azure_arc_servers_jumpstart/docs/arc_vm_extension_mma_arm.md)

* [Deploying Custom Script Extension to Azure Arc Linux and Windows VMs using Extension Management](azure_arc_servers_jumpstart/docs/arc_vm_extension_customscript_arm.md)

* [Deploying Microsoft Monitoring Agent Extension (MMA) to Azure Arc Linux and Windows VMs using Azure Policies](azure_arc_servers_jumpstart/docs/arc_policies_mma.md)
 
* [Integrate Azure Security Center with Azure Arc enabled Servers](azure_arc_servers_jumpstart/docs/arc_securitycenter.md)

* [Integrate Azure Sentinel with Azure Arc enabled Servers](azure_arc_servers_jumpstart/docs/arc_azuresentinel.md)

* [Deploy Update Management on Azure Arc enabled Servers](azure_arc_servers_jumpstart/docs/arc_updateManagement.md)

#### Azure Arc enabled Servers - Scaled Deployment Scenarios

The following guides are designed to provide scaled onboarding experience to Azure Arc of virtual machines deployed in various platforms and existing environments.

* [Scaled Onboarding VMware vSphere Windows Server VMs to Azure Arc](azure_arc_servers_jumpstart/docs/vmware_scaled_powercli_win.md)

* [Scaled Onboarding VMware vSphere Linux VMs to Azure Arc](azure_arc_servers_jumpstart/docs/vmware_scaled_powercli_linux.md)

* [Scaled Onboarding AWS EC2 instances to Azure Arc using Ansible](azure_arc_servers_jumpstart/docs/aws_scale_ansible.md)

## Azure Arc enabled SQL Server

The deployment scenarios below will guide you through onboarding Microsoft SQL Server, deployed on various platforms to Azure Arc.

### Microsoft Azure

The following guide in this section will walk you through how to project an Azure VM installed with SQL Server as an Azure Arc enabled server and Azure Arc enabled SQL.
This guide, using Azure VM is designed **for demo and testing purposes ONLY and is not supported.**

In each guide, you find a detailed, technical explanation of the mechanism and why **it is not expected to project an Azure VM as an Azure Arc enabled server**.

* [Onboard an Azure VM with Windows Server & Microsoft SQL Server to Azure Arc using ARM Template](azure_arc_sqlsrv_jumpstart/docs/azure_arm_template_winsrv.md)

### Amazon Web Services (AWS)

The following guide provide end-to-end deployment of new Windows Server install with SQL Server in AWS and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Onboard an AWS EC2 instance with Windows Server & Microsoft SQL Server to Azure Arc](azure_arc_sqlsrv_jumpstart/docs/aws_terraform_winsrv.md)

### Google Cloud Platform (GCP)

The following guide provide end-to-end deployment of new Windows Server install with SQL Server in GCP and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Onboard a GCP VM instance with Windows Server & Microsoft SQL Server to Azure Arc](azure_arc_sqlsrv_jumpstart/docs/gcp_terraform_winsrv.md)

### VMware

The following guide provide end-to-end deployment of new Windows Server install with SQL Server in VMware vSphere and onboarding to Azure with Azure Arc using [Terraform](https://www.terraform.io/).

* [Onboard a VMware vSphere-based Windows Server with SQL to Azure Arc](azure_arc_sqlsrv_jumpstart/docs/vmware_terraform_winsrv.md)

## Azure Arc enabled Kubernetes

The below deployment options are focused on Azure Arc enabled Kubernetes. They are designed to quickly spin up a Kubernetes cluster that is ready to be projected in Azure Arc and ready for use with Azure native tooling. 

**Disclaimer: Azure Arc enabled Kubernetes is currently in Public Preview.**

### General

This example demonstrates how to connect an existing Kubernetes cluster to Arc. It assumes you already have a cluster ready to work with.

* [Connect an existing Kubernetes cluster to Azure Arc](azure_arc_k8s_jumpstart/docs/onboard_k8s.md)

### Azure Kubernetes Service (AKS)

If you do not yet have a Kubernetes cluster, the following examples walk through creating an AKS cluster to simulate an "on-premises" cluster. Examples are provided for deploying with either Terraform or with an ARM template.

* [Deploy AKS cluster and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/aks_arm_template.md)

* [Deploy AKS cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/aks_terraform.md)

### Amazon Elastic Kubernetes Service (EKS)

This example uses Terraform to deploy an EKS cluster on AWS and connect it to Azure with Azure Arc.

* [Deploy EKS cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/eks_terraform.md)

### Google Kubernetes Engine (GKE)

This example uses Terraform to deploy a GKE cluster on Google Cloud and connect it to Azure with Azure Arc.

* [Deploy GKE cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/gke_terraform.md)

### Rancher k3s

These examples deploy [Rancher k3s](https://github.com/rancher/k3s) on an Azure VM or VMware and onboards the cluster with Azure Arc.

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/rancher_k3s_azure_arm_template.md)

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/rancher_k3s_azure_terraform.md)

* [Deploy Rancher k3s on a VMware vSphere VM and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/rancher_k3s_vmware_terraform.md)

### Azure Red Hat OpenShift (ARO) V4

Azure Arc can also support Azure Red Hat OpenShift (ARO). This example uses Terraform to deploy a new ARO cluster and onboards it to Azure with Azure Arc.

* [Deploy Azure Redhat Openshift Cluster and connect it to Azure Arc using automation](azure_arc_k8s_jumpstart/docs/aro_script.md)

### kind

This example walks you through how to create a Kubernetes cluster on your local machine using [kind (kubernetes in docker)](https://kind.sigs.k8s.io/), and onboard it as an Azure Arc enabled Kubernetes cluster

* [Deploy a local Kubernetes Cluster using kind and connect it to Azure Arc](azure_arc_k8s_jumpstart/docs/local_kind.md)

### MicroK8s

This example walks you through how to create a Kubernetes cluster on your local machine using [MicroK8s](https://microk8s.io/), and onboard it as an Azure Arc enabled Kubernetes cluster

* [Deploy a local Kubernetes Cluster using MicroK8s and connect it to Azure Arc](azure_arc_k8s_jumpstart/docs/local_microk8s.md)

#### Azure Arc enabled Kubernetes - Day-2 Scenarios & Use-Cases

Once you have Kubernetes clusters projected into Azure with Azure Arc, you can start to use native Azure tooling to manage the clusters as native Azure resources. The following guides show examples of using Azure management tools such as Azure Monitor, GitOps configurations, and Azure Policy.

##### AKS

* [Deploy GitOps configurations and perform basic GitOps flow on AKS as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/aks_gitops_basic.md)

* [Deploy GitOps configurations and perform Helm-based GitOps flow on AKS as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/aks_gitops_helm.md)

* [Integrate Azure Monitor for Containers with AKS as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/aks_monitor.md)

* [Apply GitOps configurations on AKS as an Azure Arc Connected Cluster using Azure Policy for Kubernetes](azure_arc_k8s_jumpstart/docs/aks_policy.md)

##### GKE

* [Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/gke_gitops_basic.md)

* [Deploy GitOps configurations and perform Helm-based GitOps flow on GKE as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/gke_gitops_helm.md)

* [Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/gke_monitor.md)

* [Apply GitOps configurations on GKE as an Azure Arc Connected Cluster using Azure Policy for Kubernetes](azure_arc_k8s_jumpstart/docs/gke_policy.md)

##### kind

* [Deploy GitOps configurations and perform Helm-based GitOps flow on kind as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/local_kind_gitops_helm.md)

##### MicroK8s

* [Deploy GitOps configurations and perform Helm-based GitOps flow on MicroK8s as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/local_microk8s_gitops_helm.md)

## Azure Arc enabled Data Services

The below deployment options are focused on Azure Arc enabled Data Services. They are designed to quickly spin up a new Kubernetes cluster and deploy Azure Arc enabled data services that are ready to be projected in Azure Arc and ready for use with Azure native tooling.

> [!NOTE] Already have a Kubernetes cluster?
[Deploy Azure Arc enabled data services to an existing Kubernetes cluster](https://docs.microsoft.com/en-us/azure/azure-arc/data/create-data-controller)

**Disclaimer: Azure Arc enabled Data Services is currently in Public Preview.**

### Data Services on Azure Kubernetes Service (AKS)

If you do not yet have a Kubernetes cluster, the following examples walk through creating an AKS cluster and deploy Azure Arc Data Services on top of it.

* [Azure Arc Data Controller Vanilla Deployment on AKS using Azure ARM template](azure_arc_data_jumpstart/docs/aks_dc_vanilla_arm_template.md)

* [Azure SQL Managed Instance Deployment on AKS using Azure ARM template](azure_arc_data_jumpstart/docs/aks_mssql_mi_arm_template.md)

* [Azure PostgreSQL Hyperscale Deployment on AKS using Azure ARM template](azure_arc_data_jumpstart/docs/aks_postgresql_hyperscale_arm_template.md)

### Data Services on AWS Elastic Kubernetes Service (EKS)

If you do not yet have a Kubernetes cluster, the following examples walk through creating an EKS cluster and deploy Azure Arc Data Services on top of it.

* [Azure Arc Data Controller Vanilla Deployment on EKS using Terraform](azure_arc_data_jumpstart/docs/eks_dc_vanilla_terraform.md)

### Data Services on GCP Google Kubernetes Engine (GKE)

If you do not yet have a Kubernetes cluster, the following examples walk through creating a GKE cluster and deploy Azure Arc Data Services on top of it.

* [Azure Arc Data Controller Vanilla Deployment on GKE using Terraform](azure_arc_data_jumpstart/docs/gke_dc_vanilla_terraform.md)

### Data Services on Upstream Kubernetes (Kubeadm)

If you do not yet have a Kubernetes cluster, the following examples walk through creating an single-node Kubernetes cluster to simulate a full scale Kubernetes cluster and deploy Azure Arc Data Services on top of it.

* [Azure Arc Data Controller Vanilla Deployment on Ubuntu Kubeadm VM using Azure ARM template](azure_arc_data_jumpstart/docs/kubeadm_dc_vanilla_arm_template.md)

# Repository Roadmap

Up-to-date roadmap for the Azure Arc scenarios to be covered can be found under [this repository GitHub Project](https://github.com/microsoft/azure_arc/projects/1).

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

Before contributing code, please see the [CONTRIBUTING](CONTRIBUTING.md) guide.

Issues, PRs and Feature Request have their own templates. Please fill out the whole template.

# Legal Notices

Microsoft and any contributors grant you a license to the Microsoft documentation and other content
in this repository under the [Creative Commons Attribution 4.0 International Public License](https://creativecommons.org/licenses/by/4.0/legalcode),
see the [LICENSE](LICENSE) file, and grant you a license to any code in the repository under the [MIT License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products and services referenced in the documentation
may be either trademarks or registered trademarks of Microsoft in the United States and/or other countries.
The licenses for this project do not grant you rights to use any Microsoft names, logos, or trademarks.
Microsoft's general trademark guidelines can be found at http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/

Microsoft and any contributors reserve all other rights, whether under their respective copyrights, patents,
or trademarks, whether by implication, estoppel or otherwise.
