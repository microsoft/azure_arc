# Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multicloud, Azure Arc enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

<p align="center"> 
<img src="azure_arc_k8s_jumpstart/img/Azure_Arc.png?style=centerme">
</p>

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multicloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multicloud environments for your data estate.

# Azure Arc "Jumpstart"

The following guides will walk you how to demo and started with Azure Arc. They are designed in "short & sweet" fashion with as much automation in mind. The goal is for you to have a working Azure Arc demo environment spined-up in no time so you can focus on showing the core values of the platform. 

## Azure Arc for Servers


### In planning:

* Deploy a single GCP VM and connect it to Azure Arc using Terraform

* Deploy a single AWS EC2 instance and connect it to Azure Arc using Terraform

## Azure Arc for Kubernetes

The below deployment options are focusing on Azure Arc for Kubernetes. They are designed to quickly spin up a Kubernetes cluster that is ready to be projected in Azure Arc and for you to start playing with it. 

* [Deploy Rancher k3s on an Azure VM using Azure ARM template](azure_arc_k8s_jumpstart/docs/azure_arm_template.md)

* [Deploy Rancher k3s on an Azure VM using Terraform](azure_arc_k8s_jumpstart/docs/azure_terraform.md)

## Azure Arc for Data Services