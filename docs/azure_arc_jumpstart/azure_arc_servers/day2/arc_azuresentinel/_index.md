---
type: docs
title: "Microsoft Sentinel"
linkTitle: "Microsoft Sentinel"
weight: 9
description: >
---

## Connect Azure Arc-enabled servers to Microsoft Sentinel

The following Jumpstart scenario will guide you on how to onboard Azure Arc-enabled servers on to [Microsoft Sentinel](https://docs.microsoft.com/es-es/azure/sentinel/), so you can start collecting security-related events and start correlating them with other data sources.
in this scenario, you will enable and configure Microsoft Sentinel on your Azure subscription. To complete this process you will:

- Setup a Log Analytics Workspace where logs and events will be aggregated for analysis and correlation.

- Enable Microsoft Sentinel on the workspace.

- Onboard Azure Arc-enabled servers on Sentinel by using the extension management feature and Azure Policies.

> **NOTE: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc but If you haven't, this repository offers you a way to do so in an automated fashion:**

- **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
- **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
- **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
- **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
- **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
- **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
- **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
- **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
- **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
- **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

## Prerequisites

- As mentioned, this scenario starts at the point where you already deployed and connected VMs or bare-metal servers to Azure Arc. For this scenario, as can be seen in the screenshots below, we will be using a Google Cloud Platform (GCP) instance that has been already connected to Azure Arc and is visible as a resource in Azure.

    ![Screenshot showing Azure Portal with Azure Arc-enabled server](./01.png)

    ![Screenshot showing Azure Portal with Azure Arc-enabled server detail](./02.png)

- [Install or update Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.49.0 or later. Use ```az --version``` to check your current installed version.

- Create Azure service principal (SP).

    To connect a VM or bare-metal server to Azure Arc, Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArc" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArc",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password**.

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

## Deployment Options and Automation Flow

This Jumpstart scenario provides multiple paths for deploying and configuring resources. Deployment options include:

- Azure portal
- ARM template via Azure CLI

The steps below will help you get familiar with the automation and deployment flow.

- User provides the ARM template parameter values, either via the portal or editing the parameters file. These parameters values are used throughout the deployment.

- User will run the ARM template at resource group level.

## Deployment Option 1: Azure portal

- Click the <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fazure_arc%2Fmain%2Fazure_arc_servers_jumpstart%2Fazuresentinel%2Farm%2Fsentinel-template.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a> button and enter values for the the ARM template parameters.

  ![Screenshot showing Azure portal deployment](./03.png)

  ![Screenshot showing Azure portal deployment](./04.png)

## Deployment Option 2: ARM template with Azure CLI

Microsoft Sentinel uses the Log Analytics agent to collect Windows and Linux server's log files and forwards them to Microsoft Sentinel, the data collected is stored in a Log Analytics workspace. Since you cannot use the default workspace created by Microsoft Defender for Cloud, a custom one is required and you could have raw events and alerts for Defender within the same custom workspace as Sentinel.

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- You will need to create a dedicated Log Analytics workspace and enable the Microsoft Sentinel solution on the top of it. For that you can use this [ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/azuresentinel/arm/sentinel-template.json) that will create a new Log Analytics Workspace and define the Microsoft Sentinel solution and enable it for the workspace. To automate the deployment edit the ARM template [parameters file](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/azuresentinel/arm/sentinel-template.parameters.json), provide a name and location for your workspace:

    ![Screenshot showing Azure ARM template](./05.png)

- To deploy the ARM template, navigate to the [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/azuresentinel/arm) and run the below command:

  ```shell
  az deployment group create --resource-group <Name of the Azure resource group> \
  --template-file <The *sentinel-template.json* template file location> \
  --parameters <The *sentinel-template.parameters.json* template file location>
  ```

For example:

   ![Screenshot showing az deployment group create command](./06.png)

## Azure Arc-enabled VMs onboarding on Microsoft Sentinel

Once you have deployed Microsoft Sentinel on your Log Analytics workspace, you will need to connect data sources to it.

There are connectors for Microsoft services, third party solutions from the Security products ecosystem. You can also use Common Event Format (CEF), Syslog, or REST-API to connect your data sources with Microsoft Sentinel.

For servers and VMs, you can install the Microsoft Monitoring Agent (MMA) agent or the Sentinel agent which collects the logs and forwards them to Microsoft Sentinel. You can deploy the agent in multiple ways by leveraging Azure Arc:

- Using **[Extension Management](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_vm_extension_mma_arm/)**

This feature in Azure Arc-enabled servers allows you to deploy the MMA agent VM extensions to a non-Azure Windows and/or Linux VMs. You can use the Azure Portal, Azure CLI, an ARM template as well as PowerShell script to manage extension deployment to Azure Arc-enabled servers.

- Setting up **[Azure Policies](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/day2/arc_policies_mma/)**

Using this approach, you will assign an Azure Policy to audit if the Azure Arc-enabled Server has the MMA agent installed. If the agent is not installed, you will use the Extensions feature to automatically deploy it to the VM using a Remediation task, an enrollment experience that compares to Azure VMs.

## Clean up environment

Complete the following steps to clean up your environment.

- Remove the virtual machines from each environment by following the teardown instructions from each guide.

- **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
- **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
- **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
- **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
- **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
- **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
- **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
- **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
- **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
- **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

- Remove the Log Analytics workspace by executing the following script in AZ CLI. Provide the workspace name you used when creating the Log Analytics Workspace.

    ```shell
    az monitor log-analytics workspace delete --resource-group <Name of the Azure resource group> --workspace-name <Log Analytics Workspace Name> --yes
    ```
