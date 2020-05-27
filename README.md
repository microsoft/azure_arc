# Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multicloud, [Azure Arc](https://azure.microsoft.com/en-us/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

<p align="center"> 
<img src="img/Azure_Arc.png?style=centerme">
</p>

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multicloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multicloud environments for your data estate.

# Azure Arc "Jumpstart"

The following guides will walk you how to demo and get started with Azure Arc. They are designed with a "zero to hero" approach in mind and with much automation as possible. The goal is for you to have a working Azure Arc demo environment spined-up in no time so you can focus on showing the core values of the solution.

***Disclaimer: The intention for this repo is to focus on the core Azure Arc capabilities. deployment scenarios, use-cases and ease of use. It does not focus on Azure best-practices or the other tech and OSS project being leveraged in the guides and code.***

## Azure Arc for Servers
The below deployment options are focusing on Azure Arc for Servers. It is designed to quickly spin up a server that is ready to be projected in Azure Arc and for you to start playing with it. 

**Note**: For a list of supported operating systems and Azure regions, please visit the official [Azure Arc docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/overview). 

#### General

* [Connect an existing Linux server to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_linux.md)

* [Connect an existing Windows machine to Azure Arc](azure_arc_servers_jumpstart/docs/onboard_server_win.md)

#### Vagrant

* [Deploy a local Ubuntu VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_ubuntu.md)

* [Deploy a local Windows 10 VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_windows.md)

#### Amazon Web Services

* [Deploy an AWS EC2 Amazon Linux 2 VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/aws_terraform_al2.md)

#### Google Cloud Platform

* [Deploy a Google Cloud Platform (GCP) Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_ubuntu.md)

* [Deploy a Google Cloud Platform (GCP) Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_windows.md)

#### VMware

* [Deploy a VMware vSphere Ubuntu Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/vmware_terraform_ubuntu.md)

## Azure Arc for Kubernetes

The below deployment options are focusing on Azure Arc for Kubernetes. It is designed to quickly spin up a Kubernetes cluster that is ready to be projected in Azure Arc and for you to start playing with it. 

#### General

* [Connect an existing Kubernetes cluster to Azure Arc](azure_arc_k8s_jumpstart/docs/onboard_k8s.md)

#### Azure Kubernetes Service (AKS)

* [Deploy Azure Kubernetes Service (AKS) cluster and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/aks_arm_template.md)

* [Deploy Azure Kubernetes Service (AKS) cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/aks_terraform.md)

#### Google Kubernetes Engine (GKE)

* [Deploy Google Kubernetes Engine (GKE) cluster and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/gke_terraform.md)

#### Rancher k3s

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Azure ARM template](azure_arc_k8s_jumpstart/docs/rancher_k3s_arm_template.md)

* [Deploy Rancher k3s on an Azure VM and connect it to Azure Arc using Terraform](azure_arc_k8s_jumpstart/docs/rancher_k3s_terraform.md)

## Azure Arc for Data Services

Coming soon!

# Support for future deployment scenarios

Below are an additional deployment scenarios the team is currently working on.

### Azure Arc for Servers

- Support for an Ubuntu Server AWS EC2 instance deployment using Terraform
- Support for a Windows Server AWS EC2 instance deployment using Terraform
- Support for a Windows Server VMware vSphere VM deployment using Terraform

### Azure Arc for Kubernetes

- Support for an Azure Red Hat OpenShift deployment using ARM template
- Support for an EKS deployment using Terraform
- Support for Rancher K3s single-host cluster in VMware vSphere VM deployment using Terraform

### Azure Arc for Data Services

- Support SQL Managed Instance (MI) in Azure Kubernetes Service (AKS) deployment using ARM template
- Support SQL Managed Instance (MI) in Azure Kubernetes Service (AKS) deployment using Terraform
- Support PostgreSQL Hyperscale in Azure Kubernetes Service (AKS) deployment using ARM template
- Support PostgreSQL Hyperscale in Azure Kubernetes Service (AKS) deployment using Terraform
