---
type: docs
title: "Monitoring Azure Arc-enabled servers with Datadog"
linkTitle: "Monitoring Azure Arc-enabled servers with Datadog"
weight: 17
description: >
---

## Monitoring Azure Arc-enabled servers with Datadog

The following Jumpstart scenario will guide you on how to onboard an Azure Arc-enabled server on to [Datadog](https://www.datadoghq.com/), so you can get insights into Arc environments with Datadog, visualize host status and identify any disconnected hosts across your hybrid infrastructure, set up Datadog monitors to alert you immediately when this connection status is no longer healthy, simplifying hybrid and multi-cloud management.

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

    ![Screenshot of Azure Portal showing Azure Arc-enabled server](./01.png)

    ![Screenshot of Azure Portal showing Azure Arc-enabled server detail](./02.png)

- Note that there is no Datadog extension on the Arc-enabled server

    ![Screenshot of Azure Portal showing Azure Arc-enabled server extensions](./03.png)

- [Install or update Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.42.0 or later. Use ```az --version``` to check your current installed version.

- Create Azure service principal (SP)

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

- Get a Datadog account. You can either use a preexisting one or create a [Datadog free trial](https://www.datadoghq.com/free-datadog-trial/) for 14 days.

    ![Screenshot create Datadog Free Trial](./04.png)

    ![Screenshot create Datadog Free Trial](./05.png)

## Automation Flow

The steps below will help you get familiar with the automation and deployment flow.

- User gets information from their Datadog account and provides it in the variables of the script. These variables values are used throughout the deployment.

- User will run PowerShell script.

## Datadog VM extension deployment

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- Edit the variables section on the script to match your environment. You will need to provide:

  - resourceGroup: name of the resource group of your Azure Arc-enabled server.
  - machineName: name of the Azure Arc-enabled server.
  - location: Azure region where your Azure Arc-enabled server is connected to.
  - osType: operating system of your Azure Arc-enabled server. You can choose between "Windows" or "Linux", be mindful this is case sensitive.
  - datadog_site: location of your Datadog site. You can identify which site you are on by matching your Datadog website URL to the site URL in the [table](https://docs.datadoghq.com/getting_started/site/).
  - datadog_api_key: provide your organization's unique API key, this is required by the Datadog Agent to submit metrics and events to Datadog. You can add a Datadog key following [these steps](https://docs.datadoghq.com/account_management/api-app-keys/#add-an-api-key-or-client-token).
  - app_Id: your service principal ID.
  - app_secret: your service principal secret.
  - subscription_id: your Azure subscription ID.
  - tenantId: your Azure AD tenant.

- To run the PowerShell script, navigate to the [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/datadog/) and run the below command:

  ```powershell
    .\datadog.ps1
  ```

- Once the script finishes its run, check the extension section of your Azure Arc-enabled server, you should see the Datadog extension deployed

    ![Screenshot create Datadog Free Trial](./06.png)

- Now that you have successfully onboarded the Arc-enabled server, go back to your Datadog dashboard and you should see one more agent reporting metrics:

    ![Screenshot create Datadog agent](./07.png)

    ![Screenshot create Datadog agent](./08.png)

## Clean up environment

Complete the following steps to clean up your environment.

Remove the virtual machines from each environment by following the teardown instructions from each guide.

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
