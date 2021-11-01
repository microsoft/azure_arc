---
type: docs
title: "Jumpstart ArcBox - Release Notes"
weight: 98
toc_hide: true
---

# Jumpstart ArcBox release notes

Release notes will be released on the first week of each month and will cover the previous month.

## October 2021

* Update required Azure CLI version to 2.25.0 or higher
* Fix missing dependencies in ARM templates

## September 2021

* Switch inbound SQL MI port from 1433 to 11433
* Switch inbound PostgreSQL port from 5432 to 15432
* Remove custom-locations-oid parameter from connected cluster onboarding scripts
* Add --kubeconfig parameter to custom location creation

## August 2021

* New [Azure Monitor workbook](https://azurearcjumpstart.io/azure_jumpstart_arcbox/workbook/) included that provides single pane of glass monitoring for all ArcBox resources.
* Remove port 22 from Cluster API control plane Network Security Group
* Update clusterctl to v0.4.2
* Update CAPZ provider to v0.5.2
* Update Kubernetes version to 1.20.10
* Automation optimizations
* Documentation revisions

## July 2021

* Improvements to Azure Policy experience. Updated policy names with (ArcBox) callout to easily identify policies created by ArcBox deployment. New policies to support onboarding Dependency Agents and Azure Defender for Kubernetes.
* Add Change Tracking, Security, VMInsights solutions to deployment.
* New troubleshooting section in documentation.
* Add automatic provisioning for Microsoft.HybridCompute and Microsoft.GuestConfiguration resource providers.
* Various fixes to Cluster API and Data Services components.
* Automation optimizations and cleanup.

## June 2021

* Azure Arc-enabled data services components of ArcBox have been updated to use [directly connected mode](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity#connectivity-modes).
* Required resource providers are now enabled automatically as part of the automation scripts.
* Per updated Azure Arc-enabled data services requirements, ArcBox region support is restricted to East US, Northern Europe, and Western Europe.
* Incorporated streamlined modular automation approach for Azure Arc-enabled data services used by the primary Jumpstart data services scenarios.

## April 2021

* This is the initial release for Jumpstart ArcBox, a project that provides an easy to deploy sandbox for all things Azure Arc. ArcBox is designed to be completely self-contained within a single Azure subscription and resource group, which will make it easy for a user to get hands-on with all available Azure Arc technologies with nothing more than an available Azure subscription.

* ArcBox can be used for a wide variety of use cases including:
  * Sandbox environment for getting hands-on with Azure Arc technologies
  * Accelerator for Proof-of-concepts or pilots
  * Training tool for Azure Arc skills development
  * Demo environment for customer presentations or events
  * Rapid integration testing platform

* View the official README for details on Jumpstart ArcBox including features and usage.

* If you encounter issues, bugs, or have a feature idea, submit it as an issue through GitHub and tag it with the ArcBox label.
