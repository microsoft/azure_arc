---
type: docs
title: "SQL Managed Instance Azure DevOps Release"
linkTitle: "SQL Managed Instance Azure DevOps Release"
weight: 4
description: >
---

## Deploy Azure SQL Managed Instance on AKS using Azure DevOps Release Pipeline

The following README will guide you on how to use [Azure DevOps (ADO) Release pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/release/?view=azure-devops) to deploy a "Ready to Go" environment so you can start using Azure Arc-enabled data services on [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) cluster using [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview).

By the end of this guide, you will have an Azure DevOps Release pipeline to deploy AKS cluster with an Azure Arc Data Controller ([in "Directly Connected" mode](https://docs.microsoft.com/en-us/azure/azure-arc/data/connectivity), Azure SQL MI with a sample database and a Microsoft Windows Server 2022 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

> **Note: Currently, Azure Arc-enabled data services with PostgreSQL Hyperscale is in [public preview](https://docs.microsoft.com/en-us/azure/azure-arc/data/release-notes)**.

> **Note: The following scenario is focusing the Azure DevOps Release pipeline creation. Once the pipeline has been created and the environment deployment has finished, the automation flow and next steps are as [described on in the main bootstrap scenario](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_mi_arm_template/)**

## Prerequisites

* [Azure DevOps account](https://azure.microsoft.com/en-us/services/devops/) set up with your organization and ready for project creation.

  * (Optional) [Create new Azure DevOps organization](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops).

  * (Optional) [Create new Azure DevOps project](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page).

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

    > **Note: It is optional, but highly recommended, to scope the SP to a specific [Azure subscription](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest).**

* Enable subscription for the *Microsoft.AzureArcData* resource provider for Azure Arc-enabled data services. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.AzureArcData
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.AzureArcData -o table
  ```

## Deployment

In this scenario, you will create a new Release pipeline to deploy the environment ARM template for this Jumpstart scenario.

* In a new or an existing ADO project, start the process of creating a new release pipeline.

    ![Screenshot of creating new ADO pipeline](./01.jpg)

    ![Screenshot of creating new ADO pipeline](./02.jpg)

* To create the pipeline, we will be using an empty job template and give it a name (once done click the X button).

    ![Screenshot of creating new empty job template](./03.jpg)

    ![Screenshot of creating new empty job template](./04.jpg)

* Create a new task for the stage you have just created. This task will be the one for deploying the ARM template.

    ![Screenshot of creating new ARM template deployment task](./05.jpg)

    ![Screenshot of creating new ARM template deployment task](./06.jpg)

* Click on the new task to start it's configuration.

    ![Screenshot of deployment task config](./07.jpg)

* When deploying an ARM template, the Azure Resource Manager connection and subscription must be provided.

    ![Screenshot of Azure Resource Manager connection config](./08.jpg)

  > **Note: For new ADO project, you will be asked to click the authorization button**

    ![Screenshot of Azure subscription config](./09.jpg)

* Provide the Azure resource group and location where all the resources will be deployed. Make sure to validate if the service is [currently available in your Azure region](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=azure-arc).

    ![Screenshot of resource group and location config](./10.jpg)

* As mentioned, the task will deployed the existing ARM template for deploying Azure Arc-enabled data services with SQL Managed Instance that in the Azure Arc Jumpstart GitHub repository.

  * Change the Template location to "URL of the file"

  * Copy the raw URLs for both the [template](https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/aks/arm_template/mssql_mi/azuredeploy.json) and the [parameters](https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/aks/arm_template/mssql_mi/azuredeploy.parameters.json) json files and paste it in it's the proper field.

  * The deployment ARM template requires you provide parameters values. Click on the _Edit Override template parameters_ to add your parameters values.

    ![Screenshot of ARM template config](./11.jpg)

  > **Known issue: Currently, Azure Arc-enabled data services running on AKS with a [Kubernetes version >=1.19.x is not supported](https://docs.microsoft.com/en-us/azure/azure-arc/data/release-notes#known-issues). This is due to data services cannot be deployed on AKS cluster with availability zones enabled.**

  * *clusterName* - AKS cluster name
  * *dnsPrefix* - AKS unique DNS prefix
  * *nodeAdminUsername* - AKS Node Username
  * *sshRSAPublicKey* - Your ssh public key
  * *SPN_CLIENT_ID* - Your Azure service principal name
  * *SPN_CLIENT_SECRET* - Your Azure service principal password
  * *SPN_TENANT_ID* - Your Azure tenant ID
  * *ARC_DC_SUBSCRIPTION* - Azure Arc Data Controller Azure subscription ID
  * *ARC_DC_REGION* - Azure location where the Azure Arc Data Controller resource will be created in Azure (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)  
  * *SPN_AUTHORITY* - *https://login.microsoftonline.com* **Do not change**
  * *kubernetesVersion* - AKS Kubernetes Version (See previous prerequisite)
  * *adminUsername* - Client Windows VM admin username
  * *adminPassword* - Client Windows VM admin password
  * *vmSize* - Client Windows VM size
  * *resourceGroup* - Azure resource group where all the resources get deploy
  * *AZDATA_USERNAME* - Azure Arc Data Controller admin username.  DO NOT USE 'sa' or 'admin'!!
  * *AZDATA_PASSWORD* - Azure Arc Data Controller admin password (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols.)
  * *ACCEPT_EULA* - "yes" **Do not change**
  * *ARC_DC_NAME* - Azure Arc Data Controller name. The name must consist of lowercase alphanumeric characters or '-', and must start d end with a alphanumeric character (This name will be used for k8s namespace as well).
  * *MSSQL_MI_NAME* - SQL Managed Instance name to be deployed on the Kubernetes cluster

    > **Note: Make sure that you are using the same Azure resource group name as the one you've just used in the *azuredeploy.parameters.json* file**

    ![Screenshot of ARM template parameters config](./12.jpg)

    ![Screenshot of ARM template parameters config](./13.jpg)

    ![Screenshot of ARM template parameters config](./14.jpg)

    ![Screenshot of ARM template parameters config](./15.jpg)

* Provide a deployment name.

    ![Screenshot of deployment name config](./16.jpg)

* Click the save button.

    ![Screenshot of config save](./17.jpg)

* After saving the task configuration, continue to create the release pipeline.

    ![Screenshot of pipeline creation](./18.jpg)

    ![Screenshot of pipeline creation](./19.jpg)

    ![Screenshot of pipeline creation](./20.jpg)

    ![Screenshot of pipeline creation](./21.jpg)

* Once done, click on the new release link. In this scenario, you will perform a manually triggering for the deployment. Once you do, click on the Logs button to see the progress.

    ![Screenshot of pipeline deployment](./22.jpg)

    ![Screenshot of pipeline deployment](./23.jpg)

    ![Screenshot of deployment progress logs](./24.jpg)

    ![Screenshot of deployment progress logs](./25.jpg)

* Once completed, all the deployment resources will be available in the Azure portal.

  > **Note: Deployment time of the Azure resources (AKS + Windows VM) can take ~25-30 minutes.**

    ![Screenshot of deployment completed](./26.jpg)

    ![Screenshot of Azure resources](./27.jpg)

* As mentioned, this scenario is focusing on the Azure DevOps Release pipeline creation. At this point, now that you have the Azure resources created, continue to the next steps as [described on in the main bootstrap scenario](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/aks/aks_mssql_mi_arm_template/#windows-login--post-deployment).
