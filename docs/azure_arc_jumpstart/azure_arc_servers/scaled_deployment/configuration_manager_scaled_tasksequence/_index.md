---
type: docs
title: "Windows server with Configuration Manager using a Task sequence"
linkTitle: "Windows server with Configuration Manager using a Task sequence"
weight: 5
description: >
---
## Connect an existing Windows server to Azure Arc using Configuration Manager with a Task sequence

The following README will guide you on how to connect a Windows machine to Azure Arc with a Task sequence using Configuration Manager.

This guide assumes that you already have an installation of [Microsoft Configuration Manager](https://docs.microsoft.com/en-us/mem/configmgr/core/understand/introduction), at least one active Windows server client, an active distribution point and a basic understanding of the product.

## Prerequisites

- [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- Enable subscription with the resource provider for Azure Arc-enabled Servers. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.HybridCompute
  ```

  You can monitor the registration process with the following commands:

    ```shell
    az provider show -n Microsoft.HybridCompute -o table
    ```

- Create Azure service principal (SP)

    To connect a server to Azure Arc, an Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)**

- Create a new Azure resource group where you want your machine(s) to show up.

    ![Screenshot showing Azure Portal with empty resource group](./01.png)

- Download the [_az_connect_win_ConfigMgr_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/scripts/az_connect_win.ps1) PowerShell script.

- Change the environment variables according to your environment and save the script.

    ![Screenshot showing PowerShell script](./02.png)

## Creating an msi application for the Azure Connected Machine agent

- Download the Azure Connected Machine agent package for Windows from the [Microsoft Download Center](https://aka.ms/AzureConnectedMachineAgent) and copy it to the Configuration Manager server.

- Login to the Configuration Manager console.

- After logging in, go to the “Software Library” workspace. Under “Application Management”, Right-click  “Applications” and click "Create Application".

    ![Screenshot showing creation of a new application](./03.png)

- Browse to the location of the downloaded Azure Connected Machine agent msi package and click “Next”.

    ![Screenshot showing the path of the agent](./04.png)

- Add any relevant information about this application. Keep the defaults for the installation program and install behavior and click “Next” to finalize the application.

    ![Screenshot showing the application configuration](./05.png)

    ![Screenshot showing the created application](./06.png)

- Select the newly created application and click on “Distribute Content”.

    ![Screenshot showing initiating a content distribution](./07.png)

- Keep the defaults and click “Next”.

    ![Screenshot showing the initial content distribution wizard](./08.png)

- Make sure to have the Azure Connected Machine agent application selected click “Next”.

    ![Screenshot showing the application being distributed](./09.png)

- Click “Add”, select “Distribution Point” and select one or more distribution points where you would like to distribute the application to.

    ![Screenshot showing the distribution point option](./10.png)

    ![Screenshot showing the distribution point selection](./11.png)

- Click “Next” to finalize the wizard and initate the content distributtion.

    ![Screenshot showing a successful content distribution](./12.png)

## Creating a custom Task sequence for the Azure Connected Machine agent deployment

- 