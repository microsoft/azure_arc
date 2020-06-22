# Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multicloud, [Azure Arc](https://azure.microsoft.com/en-us/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multicloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multicloud environments for your data estate.

# Azure Arc Story Time

Fabrikam Global Manufacturing runs workloads on different hardware, across on-premises datacenters, multiple public clouds, with Microsoft Azure being the main one as well as IoT workloads deployed on the edge. Workloads include very diverse services and are based on either virtual machines, managed Platforms-as-a-Service (PaaS) services as well as container-based applications. 
 
As mentioned, Fabrkam’s R&D teams are well-invested in containerized workloads for their modernized applications and as a result, they are using Kubernetes as their container orchestration platform, deployed both as a self-managed Kubernetes in their on-premises environments as well as a managed Kubernetes deployments in the cloud.

As part of their cloud-native practices with Azure being it’s main hyper-scale cloud, Fabrkam’s  operations teams are standardized and taking advantage of Azure Resource Manager (ARM) capabilities such as (but not limited to) tagging, Azure Monitoring for VMs and containers, logging and telemetry, policy and government, Desired State Configuration (DSC), Update Management, Change Tracking, Inventory management,etc. 

These practices and techniques are already well established for Azure-based workloads Fabrkam are using such as Azure VMs, Azure Kubernetes Service (AKS), Azure SQL, and many more. In order to take advantage of these well-established practices, Fabrkam are using Azure Arc to extend the ARM API’s to project and manage it’s workloads deployed outside of Azure. Once onboarded, Azure Arc projects resources as first-class citizens in Azure which can then take advantage of ARM capabilities mentioned above. In addition, they are able to guarantee Kubernetes deployments and app consistency through GitOps-based configuration for their Kubernetes clusters in Azure, other clouds and on-premises. 
 
With Azure Arc, Fabrikam are able to project resources and register them into Azure Resource Manager independently of where they run, so they have a single control plane and extend those cloud-native operations and governance beyond Azure.

<p align="center">
  <img src="img/architecture_dark.png" width="80%"/>
</p>

# Azure Arc "Jumpstart"

The following guides will walk you trough on how to demo and get started with Azure Arc. They are designed with a "zero to hero" approach in mind and with much automation as possible. The goal is for you to have a working Azure Arc demo environment spined-up in no time so you can focus on showing the core values of the solution.

**Disclaimer: The intention for this repo is to focus on the core Azure Arc capabilities. deployment scenarios, use-cases and ease of use. It does not focus on Azure best-practices or the other tech and OSS project being leveraged in the guides and code.**

## Azure Arc for Servers
The below deployment options are focusing on Azure Arc for Servers. It is designed to quickly spin up a server that is ready to be projected in Azure Arc and for you to start playing with it. 

**Note: For a list of supported operating systems and Azure regions, please visit the official [Azure Arc docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/overview).**

#### General

* [Connect an existing Linux server to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_linux.md)

* [Connect an existing Windows machine to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_win.md)

#### Vagrant

* [Deploy a local Ubuntu VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_ubuntu.md)

* [Deploy a local Windows 10 VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_windows.md)

#### Amazon Web Services (AWS)

* [Deploy an AWS EC2, Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/aws_terraform_ubuntu.md)

#### Google Cloud Platform (GCP)

* [Deploy a GCP, Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_ubuntu.md)

* [Deploy a GCP, Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_windows.md)

#### VMware

* [Deploy a VMware vSphere, Ubuntu Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/vmware_terraform_ubuntu.md)

* [Deploy a VMware vSphere, Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/vmware_terraform_winsrv.md)

#### Azure Arc for Servers - Day-2 Scenarios & Use-Cases

* [Tagging and querying server inventory across multiple clouds using Resource Graph Explorer](azure_arc_servers_jumpstart/docs/arc_inventory_tagging.md)

## Azure Arc for Kubernetes

The below deployment options are focusing on Azure Arc for Kubernetes. It is designed to quickly spin up a Kubernetes cluster that is ready to be projected in Azure Arc and for you to start playing with. 

#### General

* [Connect an existing Kubernetes cluster to Azure Arc](azure_arc_k8s_jumpstart/docs/onboard_k8s.md)

* [Deploying Microsoft Monitoring Agent Extension (MMA) to Azure Arc Linux and Windows VMs using Extension Management](azure_arc_servers_jumpstart/docs/arc_vm_extension_mma_arm.md)

* [Deploying Custom Script Extension to Azure Arc Linux and Windows VMs using Extension Management](azure_arc_servers_jumpstart/docs/arc_vm_extension_customscript_arm.md)

* [Deploying Microsoft Monitoring Agent Extension (MMA) to Azure Arc Linux and Windows VMs using Azure Policies](azure_arc_servers_jumpstart/docs/arc_policies_mma.md)


#### Azure Kubernetes Service (AKS)

* [Deploy AKS cluster and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/aks_arm_template.md)

* [Deploy AKS cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/aks_terraform.md)

* [Deploy GitOps configurations and perform basic GitOps flow on AKS as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/aks_gitops.md)

* [Integrate Azure Monitor for Containers with AKS as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/aks_monitor.md)

#### Amazon Elastic Kubernetes Service (EKS)

* [Deploy EKS cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/eks_terraform.md)

#### Google Kubernetes Engine (GKE)

* [Deploy GKE cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/gke_terraform.md)

* [Deploy GitOps configurations and perform basic GitOps flow on GKE as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/gke_gitops.md)

* [Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster](azure_arc_k8s_jumpstart/docs/gke_monitor.md)

#### Rancher k3s

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/rancher_k3s_azure_arm_template.md)

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/rancher_k3s_azure_terraform.md)

* [Deploy Rancher k3s on a VMware vSphere VM and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/rancher_k3s_vmware_terraform.md)

#### Azure Red Hat OpenShift V4
* [Deploy Azure Redhat Openshift Cluster and connect it to Azure Arc using automation](azure_arc_k8s_jumpstart/docs/aro_script.md)


## Azure Arc for Data Services

Coming soon!

# Support for future deployment scenarios

Below are an additional deployment scenarios the team is currently working on.

### Azure Arc for Servers

- Support for an AWS Linux 2 instance deployment using Terraform
- Support for a Windows Server AWS EC2 instance deployment using Terraform

### Azure Arc for Kubernetes

- Support for an Azure Red Hat OpenShift deployment using ARM template
- Support for kind Deployment guide with Arc connectivity
- Support for Minikube Deployment guide with Arc connectivity
- Support for MicroK8s Deployment guide with Arc connectivity

### Azure Arc for Data Services

- Support SQL Managed Instance (MI) in Azure Kubernetes Service (AKS) deployment using ARM template
- Support SQL Managed Instance (MI) in Azure Kubernetes Service (AKS) deployment using Terraform
- Support PostgreSQL Hyperscale in Azure Kubernetes Service (AKS) deployment using ARM template
- Support PostgreSQL Hyperscale in Azure Kubernetes Service (AKS) deployment using Terraform

## Contributing

Before contributing code, please see the [CONTRIBUTING](CONTRIBUTING.md) guide.

Issues, PRs and Feature Request have their own templates. Please fill out the whole template.