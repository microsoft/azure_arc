---
type: docs
title: "Overview"
linkTitle: "Overview"
weight: 1
---

## Azure Arc Jumpstart

The Azure Arc Jumpstart project is designed to provide a "zero to hero" experience so you can start working with Azure Arc right away!

The provided step-by-step scenarios will allow you to go through independent scenarios that incorporate as much automation as possible, detailed screenshots and code samples, and an overall rich and comprehensive experience while getting started with the Azure Arc platform.

Our goal is for you to have a working Azure Arc environment spun-up in no time so you can focus on the core values of the platform, regardless of where your infrastructure may be, either on-premises or in the cloud.

<p align="center"><img src="/img/jumpstart_logo.png" alt="jumpstart-logo" width="250"></p>

## Jumpstart Scenarios

Ready to get going?! This website offers you detailed guides, automation, code samples, screenshots and everything you really need to get going with Azure Arc!

Hope over to the [Jumpstart Scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/) section and enjoy the ride.

> **Disclaimer: The intention for the Azure Arc Jumpstart project is to focus on the core Azure Arc capabilities, deployment scenarios, use-cases, and ease of use. It does not focus on Azure best-practices or the other tech and OSS projects being leveraged in the scenarios and code.**

## Azure Arc Overview

For customers who want to simplify complex and distributed environments across on-premises, edge and multi-cloud, [Azure Arc](https://azure.microsoft.com/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure.

* **Organize and govern across environments** - Get databases, Kubernetes clusters, and servers sprawling across on-premises, edge and multi-cloud environments under control by centrally organizing and governing from a single place.

* **Manage Kubernetes Apps at scale** - Deploy and manage Kubernetes applications across environments using DevOps techniques. Ensure that applications are deployed and configured from source control consistently.

* **Run data services anywhere** - Get automated patching, upgrades, security and scale on-demand across on-premises, edge and multi-cloud environments for your data estate.

## Azure Arc Story Time

Fabrikam Global Manufacturing runs workloads on different hardware, across on-premises datacenters, and multiple public clouds, with Microsoft Azure being the primary cloud. They also support IoT workloads deployed on the edge. Workloads include very diverse services and are based on either virtual machines, managed Platform-as-a-Service (PaaS) services, and container-based applications.

As mentioned, Fabrikam’s R&D teams are well-invested in containerized workloads for their modernized applications. As a result, they are using Kubernetes as their container orchestration platform. Kubernetes is deployed both as self-managed Kubernetes clusters in their on-premises environments and managed Kubernetes deployments in the cloud.

As part of their cloud-native practices with Azure being the main hyper-scale cloud, Fabrikam’s operations teams are standardized and taking advantage of Azure Resource Manager (ARM) capabilities such as (but not limited to) tagging, Azure Monitoring for VMs and containers, logging and telemetry, policy and government, Desired State Configuration (DSC), Update Management, Change Tracking, Inventory management, etc.

These practices and techniques are already well established for Azure-based workloads in use such as Azure VMs, Azure Kubernetes Service (AKS), Azure SQL, and many more. In order to take advantage of these well-established practices, Fabrikam is using Azure Arc to extend the ARM APIs to project and manage their workloads deployed outside of Azure. Once onboarded, Azure Arc projects resources as first-class citizens in Azure which can then take advantage of the ARM capabilities mentioned above. In addition, they are able to guarantee Kubernetes deployments and app consistency through GitOps-based configuration for their Kubernetes clusters in Azure, other clouds and on-premises.

With Azure Arc, Fabrikam is able to project resources and register them into Azure Resource Manager independently of where they run, so they have a single control plane and can extend cloud-native operations and governance beyond Azure.

![architecture](/img/architecture_white.jpg)

## Jumpstart Roadmap

Up-to-date roadmap for the Azure Arc Jumpstart scenarios can be found under [the repository GitHub Project](https://github.com/microsoft/azure_arc/projects/1).

<!-- ## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

Before contributing code, please see the [CONTRIBUTING](../contributing/) guide.

Issues, PRs and Feature Request have their own templates. Please fill out the whole template.

## Legal Notices

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
or trademarks, whether by implication, estoppel or otherwise. -->
