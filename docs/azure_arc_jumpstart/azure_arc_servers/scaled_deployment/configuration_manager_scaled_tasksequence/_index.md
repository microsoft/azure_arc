---
type: docs
title: "Windows server with Configuration Manager using a Task Sequence"
linkTitle: "Windows server with Configuration Manager using a Task Sequence"
weight: 5
description: >
---
## Connect an existing Windows server to Azure Arc using Configuration Manager with a Task Sequence

The following README will guide you on how to connect a Windows machine to Azure Arc with a Task Sequence using Configuration Manager.

This guide assumes that you already have an installation of [Microsoft Configuration Manager](https://docs.microsoft.com/en-us/mem/configmgr/core/understand/introduction) and a basic understanding of the product, at least one active Windows server client, an active distribution point.

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

- Download the [_az_connect_win_ConfigMgr_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/scripts/az_connect_win_ConfigMgr.ps1) PowerShell script.

- Change the environment variables according to your environment and save the script.

    ![Screenshot showing PowerShell script](./02.png)

## Creating an msi application to deploy the Azure Connected Machine agent within the Task Sequence

- Download the Azure Connected Machine agent package for Windows from the [Microsoft Download Center](https://aka.ms/AzureConnectedMachineAgent) and copy it to the Configuration Manager server.

- Login to the Configuration Manager console.

- After logging in, go to the “Software Library” workspace. Under “Application Management”, click  “Applications” and click "Create Application".

    ![Screenshot showing the creation of a new application](./03.png)

- Browse to the location of the downloaded Azure Connected Machine agent MSI package and click “Next”.

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

- Click “Add”, select “Distribution Point” and select one or more distribution points where you would like to distribute the application.

    ![Screenshot showing the distribution point option](./10.png)

    ![Screenshot showing the distribution point selection](./11.png)

- Click “Next” to finalize the wizard and initiate the content distribution.

    ![Screenshot showing a successful content distribution](./12.png)

## Creating a custom Task Sequence for the Azure Connected Machine agent deployment

In order for Configuration Manager to onboard servers in this scenario, we will need to create a custom Task Sequence that has two steps; first to deploy the Azure Connected Machine agent as an application and second to run the “azcmagent connect” command to onboard to Azure Arc.

- Go to the “Software Library” workspace. Under “Operating Systems”, select “Task Sequences”, click "Create Task Sequence" and select “Create a new custom task sequence”.

    ![Screenshot showing a new custom task Sequence](./13.png)

- Give the Task Sequence and name, leave all the defaults and click “Next” to finalize the wizard.

    ![Screenshot showing a new custom task Sequence properties](./14.png)

- Select the newly created Task Sequence and Click “Edit” to open the Task Sequence editor.

    ![Screenshot showing the task Sequence editor](./15.png)

- Click “Add” to add a new Task Sequence step, select “Software” and click on “Install Application”.

    ![Screenshot showing adding an application install step](./16.png)

- Give the step a name, and click the “edit” button to select the Azure Connected Machine agent application.

    ![Screenshot showing adding the agent application](./17.png)

    ![Screenshot showing adding the agent application step completed](./18.png)

- Click “Add” to add a new Task Sequence step, select “General” and click on “Run PowerShell Script”.

    ![Screenshot showing adding the Powershell script step](./19.png)

- Give the step a name, “Select the PowerShell execution policy” to be Bypass, select the option to “Enter a PowerShell script” and click “Add Script”.

    ![Screenshot showing adding the PowerShell script details](./20.png)

-  Paste the content of the [_az_connect_win_ConfigMgr_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/scripts/az_connect_win_ConfigMgr.ps1) PowerShell script you downloaded earlier and click “Ok”.

    ![Screenshot showing adding the PowerShell script code](./21.png)

- Click “Ok” to finalize the task sequence.

    ![Screenshot showing adding the finished task sequence](./22.png)

## Deployment

- Go to the “Assets and Compliance” workspace. Expand on “Device Collections” and select the collection that contains the server(s) you want to onboard. Click “Deploy” and click “Task Sequence”.

    ![Screenshot showing deploying the task sequence](./23.png)

- Click on “Browse” and select the Task Sequence created.

    ![Screenshot showing selecting the task sequence to deploy](./24.png)

- Choose the deployment to be available (the deployment can be required or available based on your scenario). 

    ![Screenshot showing selecting the enforcement method](./25.png)

- Keep the defaults and finalize the Task Sequence deployment wizard.

- Connect to the server to be onboarded and open “Software Center”. After the server's machine policy has been refreshed, you should see the Task Sequence deployment in the Applications available in Software Center.

    ![Screenshot showing software center](./26.png)

- Click on the Task Sequence deployment and click “Install”.

    ![Screenshot showing software center installation step](./27.png)

- The progress of the Task Sequence will be displayed showing the two steps we created.

    ![Screenshot showing the first task sequence step](./28.png)

    ![Screenshot showing the second task sequence step](./29.png)

    ![Screenshot showing the task sequence completion](./30.png)

- Upon completion, you will have your Windows server, connected as a new Azure Arc-enabled server resource inside your resource group.

    ![Screenshot showing the server onboarded](./31.png)

    ![Screenshot showing the server connected succesfully](./32.png)

## Delete the deployment

The most straightforward way is to delete the server via the Azure Portal, just select server and delete it.

![Screenshot showing delete resource function in Azure Portal](./33.png)

If you want to delete the entire environment, just delete the Azure resource group.

![Screenshot showing delete resource group function in Azure Portal](./34.png)

