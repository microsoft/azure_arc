---
type: docs
title: "Jumpstart Agora FAQ"
linkTitle: "Jumpstart Agora FAQ"
weight: 7
---

# Jumpstart Agora Frequently Asked Questions (FAQ)

## General

### What is Jumpstart Agora?

Jumpstart Agora is a marketplace of various “cloud to edge” industry scenarios, designed to provide an end-to-end user experience. The word "Agora" comes from the ancient Greek term for a public gathering place or assembly, and it has come to be used more broadly to refer to any place or forum where people come together for discussion or exchange. Our mission is to create a rich marketplace of applications that can leverage Hybrid Cloud, Internet of Things (IoT), and artificial intelligence (AI) technologies and make those accessible for enablement and educational purposes via the Jumpstart automation mechanisms.

> **NOTE: For general questions about Azure Arc Jumpstart please check the [main Jumpstart FAQ](https://azurearcjumpstart.io/faq/).**

### What industry scenarios are available in Jumpstart Agora?

Currently, Agora offers the [Contoso Supermarket](./contoso_supermarket/_index.md) retail industry experience. Contoso Supermarket includes everything needed to deploy, configure and use a realistic sample point-of-sale application including CI/CD, observability, security, and more.

### What is required to deploy Agora?

Agora deployment requires an Azure service principal with Contributor or Owner role-based access control (RBAC) on an Azure subscription and resource group. You can deploy Agora using Azure Bicep or the [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview). The service principal is required to run the automation scripts that deploy and configure Agora features. You can view how the service principal is used by exploring the Agora code on our [public GitHub repository](https://github.com/microsoft/azure_arc).

### What Azure regions can Agora be deployed to?

Agora can be deployed to the following regions:

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

### What are the costs for using Agora?

Agora incurs normal Azure consumption charges for various Azure resources such as virtual machines and storage. Each industry scenario in Agora may use a different combination of Azure resources and therefore costs vary depending on the industry scenario used. You can view example estimates of Agora costs by clicking the links below.

- [Agora Contoso Supermarket cost estimate](https://aka.ms/AgoraContosoSupermarketCostEstimate)

### Where can I go if I have trouble deploying or using ArcBox?

Agora has a [dedicated page for troubleshooting](https://aka.ms/AgoraTroubleshooting) that you can review for common issues.

If you're still stuck, please [submit an issue](https://github.com/microsoft/azure_arc/issues/new/choose) on our GitHub repository and the Jumpstart team will try to assist you.
