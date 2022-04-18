---
type: docs
title: "Existing Windows server"
linkTitle: "Existing Windows server"
weight: 2
description: >
---

## Connect an existing Windows server to Azure Arc

The following README will guide you on how to connect an Windows machine to Azure Arc using a simple PowerShell script.

## Prerequisites

* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* Create Azure service principal (SP)

    To connect a server to Azure Arc, an Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

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

* Azure Arc-enabled servers depends on the following Azure resource providers in your subscription in order to use this service. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  * Microsoft.HybridCompute
  * Microsoft.GuestConfiguration

      ```shell
      az provider register --namespace 'Microsoft.HybridCompute'
      az provider register --namespace 'Microsoft.GuestConfiguration'
      ```

      You can monitor the registration process with the following commands:

      ```shell
      az provider show --namespace 'Microsoft.HybridCompute'
      az provider show --namespace 'Microsoft.GuestConfiguration'
      ```

* Create a new Azure resource group where you want your machine(s) to show up.

    ![Screenshot showing Azure Portal with empty resource group](./01.png)

* Download the [az_connect_win](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/scripts/az_connect_win.ps1) PowerShell script.

* Change the environment variables according to your environment and copy the script to the designated machine.

    ![Screenshot showing PowerShell script](./02.png)

## Deployment

On the designated machine, Open PowerShell ISE **as Administrator** and run the script. Note the script is using *$env:ProgramFiles* as the agent installation path so make sure **you are not using PowerShell ISE (x86)**.

![Screenshot showing PowerShell script](./03.png)

![Screenshot showing PowerShell script](./04.png)

Upon completion, you will have your Windows server, connected as a new Azure Arc resource inside your resource group.

![Screenshot showing PowerShell script being run](./05.png)

![Screenshot showing Azure Portal with Azure Arc-enabled server resource](./06.png)

![Screenshot showing Azure Portal with Azure Arc-enabled server resource detail](./07.png)

## Delete the deployment

The most straightforward way is to delete the server via the Azure Portal, just select server and delete it.

![Screenshot showing delete resource function in Azure Portal](./08.png)

If you want to delete the entire environment, just delete the Azure resource group.

![Screenshot showing delete resource group function in Azure Portal](./09.png)
