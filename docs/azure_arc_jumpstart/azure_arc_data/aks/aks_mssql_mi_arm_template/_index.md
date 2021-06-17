---
type: docs
title: "SQL Managed Instance ARM Template"
linkTitle: "SQL Managed Instance ARM Template"
weight: 2
description: >
---

## Deploy Azure SQL Managed Instance in directly connected mode on AKS using an ARM Template

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using [Azure Arc enabled data services](https://docs.microsoft.com/en-us/azure/azure-arc/data/overview) and [SQL Managed Instance](https://docs.microsoft.com/en-us/azure/azure-arc/data/managed-instance-overview) deployed on [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) cluster using [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview).

By the end of this guide, you will have an AKS cluster deployed with an Azure Arc Data Controller, SQL Managed Instance, and a Microsoft Windows Server 2019 (Datacenter) Azure client VM, installed & pre-configured with all the required tools needed to work with Azure Arc enabled data services.

> **Note: Currently, Azure Arc enabled data services is in [public preview](https://docs.microsoft.com/en-us/azure/azure-arc/data/release-notes)**.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure service principal (SP)

    To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "http://AzureArcData" --role contributor
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcData",
    "name": "http://AzureArcData",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: It is optional, but highly recommended, to scope the SP to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest).**

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

* User is editing the ARM template parameters file (1-time edit). These parameters values are being used throughout the deployment.

* Main [_azuredeploy_ ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/azuredeploy.json) will initiate the deployment of the linked ARM templates:

  * [_aks_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/aks.json) - Deploys the AKS cluster where all the Azure Arc data services will be deployed.
  * [_clientVm_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/clientVm.json) - Deploys the client Windows VM. This is where all user interactions with the environment are made from.
  * [_logAnalytics_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/logAnalytics.json) - Deploys Azure Log Analytics workspace to support Azure Arc enabled data services logs uploads.

User remotes into client Windows VM, which automatically kicks off the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/artifacts/DataServicesLogonScript.ps1) PowerShell script that deploy and configure Azure Arc enabled data services on the AKS cluster including the data controller and SQL Managed Instance.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single template that will initiate the entire automation for this scenario.

* The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [_azuredeploy.parameters.json_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/azuredeploy.parameters.json) file located in your local cloned repository folder. An example parameters file is located [here](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/artifacts/azuredeploy.parameters.example.json).

  * *sshRSAPublicKey* - Your SSH public key
  * *spnClientId* - Your Azure service principal id
  * *spnClientSecret* - Your Azure service principal secret
  * *spnTenantId* - Your Azure tenant id
  * *windowsAdminUsername* - Client Windows VM Administrator name
  * *windowsAdminPassword* - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  * *myIpAddress* - Your local public IP address. This is used to allow remote RDP and SSH connections to the client Windows VM and AKS cluster.
  * *logAnalyticsWorkspaceName* - Unique name for the deployment log analytics workspace
  * *deploySQLMI* - Boolean that sets whether or not to deploy SQL Managed Instance, for this data controller and Azure SQL Managed Instance scenario, we will set it to _**true**_.
  * *deployPostgreSQL* - Boolean that sets whether or not to deploy PostgreSQL Hyperscale, for this data controller and Azure SQL Managed Instance scenario only scenario, we leave it set to _**false**_.
  * *kubernetesVersion* - AKS version
  * *dnsPrefix* - AKS unique DNS prefix

* To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template) and run the below command:

    ```shell
    az group create --name <Name of the Azure resource group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/aks/arm_template/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > **Note: Make sure that you are using the same Azure resource group name as the one you've just used in the _azuredeploy.parameters.json_ file**

    For example:

    ```shell
    az group create --name Arc-Data-Demo --location "East US"
    az deployment group create \
    --resource-group Arc-Data-Demo \
    --name arcdata \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/aks/arm_template/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

    > **Note: The deployment time for this scenario can take ~15-20min**

* Once Azure resources has been provisioned, you will be able to see it in Azure portal. At this point, the resource group should have **8 various Azure resources** deployed.

    ![ARM template deployment completed](./01.jpg)

    ![New Azure resource group with all resources](./02.jpg)

## Windows Login & Post Deployment

* Now that first phase of the automation is completed, it is time to RDP to the client VM using it's public IP.

    ![Client VM public IP](./03.png)

* At first login, as mentioned in the "Automation Flow" section above, the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/aks/arm_template/artifacts/DataServicesLogonScript.ps1) PowerShell logon script will start it's run.

* Let the script to run its course and **do not close** the PowerShell session, this will be done for you once completed. Once the script will finish it's run, the logon script PowerShell session will be closed, the Windows wallpaper will change and the Azure Arc Data Controller will be deployed on the cluster and be ready to use.

![PowerShell logon script run](./04.png)

![PowerShell logon script run](./05.png)

![PowerShell logon script run](./06.png)

![PowerShell logon script run](./07.png)

![PowerShell logon script run](./08.png)

![PowerShell logon script run](./09.png)

![PowerShell logon script run](./10.png)

![PowerShell logon script run](./11.png)

![PowerShell logon script run](./12.png)

![PowerShell logon script run](./13.png)

![PowerShell logon script run](./14.png)

![PowerShell logon script run](./15.png)

![PowerShell logon script run](./16.png)

![PowerShell logon script run](./17.png)

![PowerShell logon script run](./18.png)

![PowerShell logon script run](./19.png)

![PowerShell logon script run](./20.png)

* Since this scenario is deploying the Azure Arc Data Controller and SQL Managed Instance, you will also notice addtional newly deployed Azure resources in the resources group (at this point you should have **12 various Azure resources deployed**. The important ones to notice are:

  * Azure Arc enabled Kubernetes cluster - Azure Arc enabled data services deployed in directly connected are using this type of resource in order to deploy the data services [cluster extension](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-extensions) as well as for using Azure Arc [Custom locations](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-custom-locations).

  * Custom location - provides a way for tenant administrators to use their Azure Arc enabled Kubernetes clusters as target locations for deploying Azure services instances.

  * Azure Arc Data Controller - The data contoller that is now deployed on the Kubernetes cluster.

  * Azure Arc enabled SQL Managed Instance - The SQL Managed Instance that is now deployed on the Kubernetes cluster.

![Addtional Azure resources in the resource group](./21.png)

* Another tool automatically deployed is Azure Data Studio along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions.

  ![Azure Data Studio connection](./22.png)

* Addtionaly, the SQL Managed Instance connection will be configured automaticly for you.

  ![Azure Data Studio connection](./23.png)

  ![Configured SQL Managed Instance connection](./24.png)

## Cluster extensions

In this scenario, the Azure Arc enabled data services cluster extension was deployed and used troughout this scenario in order to deploy the data services infrastructure.

* In order to view cluster extensions, click on the Azure Arc enabled Kubernetes resource Extensions settings.

  ![Azure Arc enabled Kubernetes resource](./25.png)

  ![Azure Arc enabled Kubernetes cluster extensions settings](./26.png)

## Cleanup

* If you want to delete the entire environment, simply delete the deployment resource group from the Azure portal.

    ![Delete Azure resource group](./27.png)
