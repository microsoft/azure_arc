---
type: docs
title: "Jumpstart FAQ"
linkTitle: "Jumpstart FAQ"
weight: 8
---

# Jumpstart Frequently Asked Questions (FAQ)

## General

### Can I contribute to the Jumpstart?

Absolutely! The Jumpstart is a community-driven open-source project and all contributions are welcomed. To get started, review the [Jumpstart Scenario Write-up Guidelines](https://azurearcjumpstart.io/scenario_guidelines/) and our [Code of Conduct](https://azurearcjumpstart.io/code_of_conduct/).

## Jumpstart ArcBox

### What are the use cases for ArcBox?

ArcBox is a virtual hybrid sandbox that can be used to explore Azure Arc capabilities, build quick demo environments, support proof-of-concept projects, and even provide a testing platform for specific hybrid scenarios. Many partners and customers use ArcBox to quickly get hands-on with Azure Arc technology because its quick to deploy with minimal requirements.

### What is required to deploy ArcBox?

ArcBox deployment requires an Azure service principal with Contributor or Owner role-based access control (RBAC) on an Azure subscription and resource group. You can deploy ArcBox using the Azure portal, Az CLI, Bicep, or Terraform. The service principal is required to run the automation scripts that deploy and configure ArcBox features. You can view how the service principal is used by exploring the ArcBox code on our [public GitHub repository](https://github.com/microsoft/azure_arc).

### What Azure regions can ArcBox be deployed to?

ArcBox can be deployed to the following regions:

- East US
- East US 2
- Central US
- West US 2
- North Europe
- West Europe
- France Central
- UK South
- Australia East
- Japan East
- Korea Central
- Southeast Asia

### What are the different "flavors" of ArcBox?

ArcBox offers three different configurations, or "flavors", that allow the user to choose their own experience.

- [ArcBox "Full"](https://azurearcjumpstart.io/azure_jumpstart_arcbox/Full) - The core ArcBox experience with Azure Arc-enabled servers, Kubernetes, and data services capabilities.
- [ArcBox for IT Pros](https://azurearcjumpstart.io/azure_jumpstart_arcbox/ITPro) - This essential Azure Arc-enabled servers sandbox includes a mix of Microsoft Windows and Linux servers managed using the included capabilities such Azure Monitor, Microsoft Defender for Cloud, Azure Policy, Update Management and more.
- [ArcBox for DevOps](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps) - This essential Azure Arc-enabled Kubernetes sandbox with the included capabilities such as GitOps, Open Service Mesh (OSM), secretes management, monitoring, and more.
- [ArcBox for DataOps](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DataOps) - This essential Azure Arc-enabled SQL Managed Instance sandbox with the included capabilities such as AD authentication, disaster recovery, point-in-time restore, migration, and more.

### What are the costs for using ArcBox?

ArcBox incurs normal Azure consumption charges for various Azure resources such as virtual machines and storage. Each flavor of ArcBox uses a different combination of Azure resources and therefore costs vary depending on the flavor used. You can view example estimates of ArcBox costs per flavor by clicking the links below.

- [ArcBox Full cost estimate](https://aka.ms/ArcBoxFullCost)
- [ArcBox for ITPro cost estimate](https://aka.ms/ArcBoxITProCost)
- [ArcBox for DevOps cost estimate](https://aka.ms/ArcBoxDevOpsCost)
- [ArcBox for DataOps cost estimate](https://aka.ms/ArcBoxDataOpsCost)

### Where can I go if I have trouble deploying or using ArcBox?

Each ArcBox flavor has a troubleshooting section of its documentation that you can review for common issues:

- [Troubleshooting ArcBox Full](https://azurearcjumpstart.io/azure_jumpstart_arcbox/full/#basic-troubleshooting)
- [Troubleshooting ArcBox for IT Pros](https://azurearcjumpstart.io/azure_jumpstart_arcbox/ITPro/#basic-troubleshooting)
- [Troubleshooting ArcBox for DevOps](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#basic-troubleshooting)
- [Troubleshooting ArcBox for DataOps](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DataOps/#basic-troubleshooting)

If you're still stuck, please [submit an issue](https://github.com/microsoft/azure_arc/issues/new/choose) on our GitHub repository and the Jumpstart team will try to assist you.

## Jumpstart HCIBox

### What Azure regions can HCIBox be deployed to?

HCIBox can be deployed to the following regions:

- East US
- East US 2
- West US 2
- North Europe

### What are the costs for using HCIBox?

HCIBox incurs normal Azure consumption charges for various Azure resources such as virtual machines and storage. You can view example estimates of HCIBox costs per flavor by clicking the links below.

- [HCIBox cost estimate](https://aka.ms/HCIBoxCost)
