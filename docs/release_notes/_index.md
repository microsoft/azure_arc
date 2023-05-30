---
type: docs
title: "Jumpstart Release Notes"
linkTitle: "Jumpstart Release Notes"
weight: 5
---

# Azure Arc Jumpstart release notes

**Release notes will be released around the first week of each month and will cover the previous month.**

## 2023

### May 2023

#### Release highlights

- New Azure Arc-enabled Kubernetes scenario
- Scenarios enhancements and bug fixes:
  - Azure Arc-enabled SQL Server
  - Azure Arc-enabled data services
- ArcBox and HCIBox enhancements and bug fixes
- Monthly ArcBox Kubernetes-related versions bump

#### Jumpstart ArcBox

- [Bug fix: azuredeploy.parameters.json file has incorrect names that do not correlate with the azuredeploy.json file #1827](https://github.com/microsoft/azure_arc/issues/1827)
- [Bug fix: patchesstrategicmerge is deprecated in kustomize #1840](https://github.com/microsoft/azure_arc/issues/1840)
- [Bug fix: ArcBox deployment fails #1861](https://github.com/microsoft/azure_arc/issues/1861)
- [Feature: Move ArcBox VHDs to new Jumpstart blob storage #1839](https://github.com/microsoft/azure_arc/issues/1839)
- [Docs update: Add Nested VMs credentials to guide #1829](https://github.com/microsoft/azure_arc/issues/1829)

#### Jumpstart HCIBox

- [Bug fix: Invalid parameter in register HCI #1877](https://github.com/microsoft/azure_arc/issues/1877)

#### Azure Arc-enabled Kubernetes

- [New scenario: AKS Edge Essentials multi-node deployment with Azure Arc using Azure Bicep](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_hybrid/aks_edge_essentials_full/)

#### Azure Arc-enabled SQL Server

- [Bug fix: azuredeploy.parameters.json file has incorrect names that do not correlate with the azuredeploy.json file #1827](https://github.com/microsoft/azure_arc/issues/1827)
- [Docs update: Add Nested VMs credentials to guide #1829](https://github.com/microsoft/azure_arc/issues/1829)

#### Azure Arc-enabled data services

- [Feature: Azure Arc-enabled data services - May release #1807](https://github.com/microsoft/azure_arc/issues/1807)

### April 2023

#### Release highlights

- New Azure Arc-enabled servers scenarios
- Scenarios enhancements and bug fixes:
  - Azure Arc-enabled SQL Server
  - Azure Arc-enabled data services
- ArcBox and HCIBox enhancements and bug fixes
- Monthly ArcBox Kubernetes-related versions bump

#### Azure Arc-enabled servers

- [New scenario: Create Automanage Machine Configuration custom configurations for Windows](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_automanage/arc_automanage_machine_configuration_custom_windows/)
- [New scenario: Create Automanage Machine Configuration custom configurations for Linux](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_automanage/arc_automanage_machine_configuration_custom_linux/)

#### Azure Arc-enabled SQL Server

- [Bug fix: Arc-enabled SQL Server best practices assessment failing with error #1783](https://github.com/microsoft/azure_arc/issues/1783)

#### Azure Arc-enabled data services

- [Feature: Azure Arc-enabled data services - April release #1762](https://github.com/microsoft/azure_arc/issues/1762)
- [Bug fix: Arc data services extension creation requires a --version argument #1780](https://github.com/microsoft/azure_arc/issues/1780)
- [Bug fix: Azure Arc-enabled SQL Managed Instance for AKS fails to deploy #1810](https://github.com/microsoft/azure_arc/issues/1810)

#### Jumpstart ArcBox

- [Feature: April Kubernetes-related version bump #1815](https://github.com/microsoft/azure_arc/issues/1815)

#### Jumpstart HCIBox

- [Bug fix: HCIBox Microsoft.OperationalInsights #1805](https://github.com/microsoft/azure_arc/issues/1805)

### March 2023

#### Release highlights

- New and updated Azure Arc-enabled servers scenarios
- Multiple enhancements and bug fixes:
  - Azure Arc-enabled SQL Server
  - Azure Arc-enabled Kubernetes
  - Azure Arc-enabled data services
- Multiple ArcBox and HCIBox enhancements and bug fixes
- Monthly ArcBox Kubernetes-related versions bump

#### Azure Arc-enabled servers

- [New scenario: Enable Azure Automanage custom profiles on an Azure Arc-enabled servers using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_automanage/arc_automanage_custom_profiles/)
- [Updated scenario: Enable Azure Automanage built-in profiles on an Azure Arc-enabled servers using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_automanage/arc_automanage_builtin_profiles/)

#### Azure Arc-enabled SQL Server

- [Bug fix: Onboarding role requirement is no longer needed for Arc-enabled SQL Server #1729](https://github.com/microsoft/azure_arc/issues/1729)

#### Azure Arc-enabled Kubernetes

- [Bug fix: Missing two parameters to use Azure Arc with ARO in Azure #1716](https://github.com/microsoft/azure_arc/issues/1716)

#### Azure Arc-enabled data services

- [Feature: Azure Arc-enabled data services - March release #1723](https://github.com/microsoft/azure_arc/issues/1723)

#### Jumpstart ArcBox

- [Feature: March Kubernetes-related version bump #1764](https://github.com/microsoft/azure_arc/issues/1764)
- [Bug fix: Onboarding role requirement is no longer needed for Arc-enabled SQL Server #1729](https://github.com/microsoft/azure_arc/issues/1729)

#### Jumpstart HCIBox

- [Bug fix: When deployAKSHCI is set to false and deployResourceBridge is set to true, RB install fails because of missing az cli path in environment variable #1726](https://github.com/microsoft/azure_arc/issues/1726)
- [Bug fix: Resource Bridge deployments failing due to upstream issue #1731](https://github.com/microsoft/azure_arc/issues/1731)

### February 2023

#### Release highlights

- Multiple ArcBox enhancements and bug fixes
- Multiple HCIBox enhancements and bug fixes
- Old scenarios deprecation
- [Updated community decks](https://github.com/microsoft/azure_arc/tree/main/docs/ppt)
  - Azure Kubernetes Service (AKS) Overview slide library deck v1.1

#### Azure Arc-enabled servers

- [Deprecated: Monitoring Agent Extension scenario #1643](https://github.com/microsoft/azure_arc/issues/1643)
- [Deprecated: Update Management scenario #1645](https://github.com/microsoft/azure_arc/issues/1645)

#### Azure Arc-enabled SQL Server

- [Bug fix: SQL Server management studio shortcut is broken #1667](https://github.com/microsoft/azure_arc/issues/1667)

#### Azure Arc-enabled Kubernetes

- [Feature: AKS Edge Essentials Scenario Update #1652](https://github.com/microsoft/azure_arc/issues/1652)
- [Feature: February Kubernetes-related version bump #1670](https://github.com/microsoft/azure_arc/issues/1670)

#### Azure Arc-enabled data services

- [Feature: Azure Arc-enabled data services - February release #1638](https://github.com/microsoft/azure_arc/issues/1638)

#### Jumpstart ArcBox

- [Feature: ArcBox storage account should enforce HTTPS only #1654](https://github.com/microsoft/azure_arc/issues/1654)
- [Feature: (P3) Hide Sidebar in Edge Browser #1683](https://github.com/microsoft/azure_arc/issues/1683)
- [Bug fix: Fix ArcBox-sql credentials #1677](https://github.com/microsoft/azure_arc/issues/1677)
- [Bug fix: Key Vault Portal UI is different from Jumpstart doc #1682](https://github.com/microsoft/azure_arc/issues/1682)
- [Bug fix: (P2) Edge Certificate UI is different from Jumpstart doc #1684](https://github.com/microsoft/azure_arc/issues/1684)
- [Bug fix: ArcBox DevOps - OSM extension failed #1686](https://github.com/microsoft/azure_arc/issues/1686)

#### Jumpstart HCIBox

- [Feature: Include code example for easily creating k8s service account bearer token #1614](https://github.com/microsoft/azure_arc/issues/1614)
- [Feature: Switch HCIBox storage account to require HTTPS encryption #1615](https://github.com/microsoft/azure_arc/issues/1615)
- [Feature: HCIBox - Include script to uninstall resource bridge cleanly #1691](https://github.com/microsoft/azure_arc/issues/1691)
- [Feature: HCIBox - allow placing Arc server resources into the same resource group as the infrastructure #1699](https://github.com/microsoft/azure_arc/issues/1699)
- [Bug fix: A part of WindowsAdminPassword was dropped when set domain user password #1616](https://github.com/microsoft/azure_arc/issues/1616)
- [Bug fix: Remove U+2013 character and replace with - #1689](https://github.com/microsoft/azure_arc/issues/1689)

### January 2023

#### Release highlights

- New and updated Jumpstart scenarios:
  - Azure Arc-enabled SQL Server
  - Azure Arc-enabled Kubernetes (first one for AKS hybrid)
  - Azure Arc-enabled app services (first one for Container Apps)
- Multiple ArcBox enhancements and bug fixes
- Multiple HCIBox bug fixes
- [Updated community decks](https://github.com/microsoft/azure_arc/tree/main/docs/ppt)
  - Azure Arc Overview slide library deck v1.8
  - Azure Arc Jumpstart overview deck v1.3

#### Azure Arc-enabled SQL Server

- [Updated scenario: Integrate Microsoft Defender for SQL servers with Azure Arc-enabled SQL Server (on Windows) using Hyper-V nested virtualization and ARM templates](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_sqlsrv/azure/azure_arm_template_sqlsrv_winsrv_defender/)

#### Azure Arc-enabled Kubernetes

- [New scenario: Deploy an AKS Edge Essentials in Azure Windows Server VM, and connect the Azure VM and AKS Edge Essentials cluster to Azure Arc using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_hybrid/aks_edge_essentials/)
- [Feature: January Kubernetes-related version bump #1611](https://github.com/microsoft/azure_arc/issues/1611)
- [Bug fix: Getting error while installing Azure Key Vault Secrets Provider extension on HCI Arc enabled Cluster #1587](https://github.com/microsoft/azure_arc/issues/1587)

#### Azure Arc-enabled data services

- [Feature: Azure Arc-enabled data services - January release #1585](https://github.com/microsoft/azure_arc/issues/1585)
- [Feature: January Kubernetes-related version bump #1611](https://github.com/microsoft/azure_arc/issues/1611)

#### Azure Arc-enabled app services

- [New scenario: Deploy Azure Container Apps on AKS using an ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/aks/aks_container_apps_arm_template/)
- [Feature: January Kubernetes-related version bump #1611](https://github.com/microsoft/azure_arc/issues/1611)

#### Jumpstart ArcBox

- [Feature: Migrate from MMA to AMA #1569](https://github.com/microsoft/azure_arc/issues/1569)
- [Feature: January Kubernetes-related version bump #1611](https://github.com/microsoft/azure_arc/issues/1611)
- [Feature: Install SSH server on the nested Windows VMs #1618](https://github.com/microsoft/azure_arc/issues/1618)
- [Feature: ArcBox - Microsoft Defender for SQL server #1617](https://github.com/microsoft/azure_arc/issues/1617)
- [Bug fix: Ubuntu VMs offline due to full disks #1601](https://github.com/microsoft/azure_arc/issues/1601)
- [Bug fix: DevOps Scenario K3sGitOps.ps1 script references the CAPI cluster not the K3s cluster #1607](https://github.com/microsoft/azure_arc/issues/1607)
- [Bug fix: ArcBox Full - update API call to get SQLMI primary endpoint #1609](https://github.com/microsoft/azure_arc/issues/1609)
- [Bug fix: BadRequest UbuntuCAPIDeployment - Azure Arcbox Full #1712](https://github.com/microsoft/azure_arc/issues/1712)

#### Jumpstart HCIBox

- [Bug fix: HCIBox deployment fails if passwords contain dollar signs #1590](https://github.com/microsoft/azure_arc/issues/1590)
- [Bug fix: HCIBox - HCIBoxLogonScript - NuGet/PS Timeout Errors on Deploy-AKS.ps1 #1591](https://github.com/microsoft/azure_arc/issues/1591)
- [Bug fix: HCIBox - HCIBoxLogonScript - NuGet/PS Timeout Errors on Deploy-AKS.ps1 #1591](https://github.com/microsoft/azure_arc/issues/1591)
- [Bug fix: HCIBox - Deployment Error- Choco Install Fails - Register-AzSHCI.ps1 #1597](https://github.com/microsoft/azure_arc/issues/1597)

## 2022

The 2022 archived release notes can be found [here](https://github.com/microsoft/azure_arc/tree/main/docs/release_notes/archive/2022.md).

## 2021

The 2021 archived release notes can be found [here](https://github.com/microsoft/azure_arc/tree/main/docs/release_notes/archive/2021.md).
