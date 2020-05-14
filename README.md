# Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multicloud, Azure Arc enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

<p align="center"> 
<img src="azure_arc_k8s_jumpstart/img/Azure_Arc.png?style=centerme">
</p>

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multicloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multicloud environments for your data estate.

# Azure Arc "Jumpstart"

The following guides will walk you how to demo and get started with Azure Arc. They are designed in "short & sweet" fashion with as much automation in mind. The goal is for you to have a working Azure Arc demo environment spined-up in no time so you can focus on showing the core values of the platform. 

## Azure Arc for Servers
The below deployment options are focusing on Azure Arc for Servers. It is designed to quickly spin up a server that is ready to be projected in Azure Arc and for you to start playing with it. 

* [Deploy a local Ubuntu VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_ubuntu.md)

* [Deploy a local Windows 10 VM and connect it to Azure Arc using Vagrant](azure_arc_servers_jumpstart/docs/local_vagrant_windows.md)

### In planning:

* Deploy a GCP VM and connect it to Azure Arc using Terraform

* Deploy an AWS EC2 instance and connect it to Azure Arc using Terraform

## Azure Arc for Kubernetes

The below deployment options are focusing on Azure Arc for Kubernetes. It is designed to quickly spin up a Kubernetes cluster that is ready to be projected in Azure Arc and for you to start playing with it. 

* [Deploy Rancher k3s on an Azure VM using Azure ARM template](azure_arc_k8s_jumpstart/docs/azure_arm_template.md)

* [Deploy Rancher k3s on an Azure VM using Terraform](azure_arc_k8s_jumpstart/docs/azure_terraform.md)

## Azure Arc for Data Services

TBD

# Support for future deployment scenarios

### Azure Arc for Servers

Below are an additional deployment scenarios the team is currently working on.

- [ ] Support for an Ubuntu Server GCP instance deployment using Terraform
- [ ] Support for a Windows Server GCP instance deployment using Terraform
- [ ] Support for an Ubuntu Server AWS EC2 instance deployment using Terraform
- [ ] Support for a Windows Server AWS EC2 instance deployment using Terraform

### Azure Arc for Kubernetes

- [ ] Support for an Azure OpenShift deployment using ARM template
- [ ] Support for an Azure OpenShift deployment using Terraform
- [ ] Support for a GKE k8s deployment using Terraform
- [ ] Support for an EKS k8s deployment using Terraform

### Azure Arc for Data Services