---
type: docs
title: "SQL Server Virtual Machine"
linkTitle: "SQL Server Virtual Machine"
weight: 1
---

## Deploy an Azure Virtual Machine with Windows Server & Microsoft SQL Server and connect it to Azure Arc using Terraform

The following README will guide you on how to use the provided [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview) to deploy an Azure VM installed with Windows Server and Microsoft SQL Server 2019 (Developer edition) and connect it as an Azure Arc-enabled SQL server resource.

Azure VMs are leveraging the [Azure Instance Metadata Service (IMDS)](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/instance-metadata-service) by default. By projecting an Azure VM as an Azure Arc-enabled server, a "conflict" is created which will not allow for the Azure Arc server resources to be represented as one when the IMDS is being used and instead, the Azure Arc server will still "act" as a native Azure VM.

However, **for demo purposes only**, the below guide will allow you to use and onboard Azure VMs to Azure Arc and by doing so, you will be able to simulate a server which is deployed outside of Azure (i.e "on-premises" or in other cloud platforms)

> **Note: It is not expected for an Azure VM to be projected as an Azure Arc-enabled server. The below scenario is unsupported and should ONLY be used for demo and testing purposes.**

By the end of the guide, you will have an Azure VM installed with Windows Server 2019 with SQL Server 2019, projected as an Azure Arc-enabled SQL Server and a running SQL assessment with data injected to Azure Log Analytics workspace.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

    ```shell
    az --version
    ```

* In case you don't already have one, you can [Create a free Azure account](https://azure.microsoft.com/en-us/free/).

* Create Azure service principal (SP)

    To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

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

* Enable subscription for the *Microsoft.AzureArcData* and *Microsoft.HybridCompute* resource providers for Azure Arc-enabled SQL Server. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.AzureArcData
  az provider register --namespace Microsoft.HybridCompute
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.AzureArcData -o table
  az provider show -n Microsoft.HybridCompute -o table
  ```

## Automation Flow

The automation for this scenario includes 3 PowerShell scripts executed in the following order:

1. [*ClientTools.ps1*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/ClientTools.ps1) - Executed at ARM Template deployment time as a CustomScriptExtension. This script has two main functionalities:

    1. Generate the *LogonScript.ps1* script and will configure a Windows scheduled task to *LogonScript* when user log in the VM for the first time.
    2. Download the [*ArcOnboarding.ps1*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/ArcOnboarding.ps1) script.  

2. *LogonScript.ps1* - Auto generated by the *ClientTools* script. This script has two main functionalities:

    1. Install and configure SQL Server on the VM
    2. Execute the *ArcOnboarding* script

3. [*ArcOnboarding.ps1*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/ArcOnboarding.ps1) - This is the main script and will be executed by the *LogonScript* script at VM runtime. This script has multiple functionalities:

    1. Restore AdventureWorksLT2019 Database
    2. Allow Azure VM to be onboard to Azure Arc
    3. Project VM as an Azure Arc-enabled server resource
    4. Project SQL Server as an Azure Arc-enabled SQL server resource
    5. Deploy Log Analytics workspace and Solutions
    6. Install Log Analytics agent using extension on Azure Arc server
    7. Create SQL Assessment and inject data to Azure Log Analytics workspace

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User is editing the ARM template parameters file (1-time edit). These parameters values are being used throughout the deployment.

2. The ARM template incl. an Azure VM Custom Script Extension which will deploy the the [*ClientTools.ps1*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/ClientTools.ps1) PowerShell Script. The script will:

    1. Download the *ArcOnboarding.ps1* PowerShell script

    2. Set local OS environment variables

    3. Generate a local OS logon script named *LogonScript.ps1*. This script will:

## Deployment

As mentioned, this deployment will use an ARM Template. You will deploy a single template, responsible for creating all the Azure resources in a single resource group as well onboarding the created VM to Azure Arc.

* Before deploying the ARM template, login to Azure using AZ CLI with the ```az login``` command.

* The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/azuredeploy.parameters.json) file located in your local cloned repository folder. An example parameters file is located [here](https://github.com/microsoft/azure_arc/blob/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/azuredeploy.parameters.example.json).

* To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_sqlsrv_jumpstart/azure/arm_template) and run the below command:

    ```shell
    az group create --name <Name of the Azure resource group> --location <Azure Region> --tags "Project=jumpstart_azure_arc_sql"
    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > **Note: Make sure that you are using the same Azure resource group name as the one you've just used in the *azuredeploy.parameters.json* file**

    For example:

    ```shell
    az group create --name Arc-SQL-Demo --location "East US" --tags "Project=jumpstart_azure_arc_sql"
    az deployment group create \
    --resource-group Arc-SQL-Demo \
    --name arcsqlsrvdemo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

* Once Azure resources has been provisioned, you will be able to see it in Azure portal.

    ![Screenshot showing ARM deployment](./01.jpg)

    ![Screenshot showing Azure Portal with Azure resources](./02.jpg)

## Windows Login & Post Deployment

* Now that the Windows Server VM has been deployed, it is time to login to it. Using it's public IP, RDP to the VM.

    ![Screenshot showing Overview tab of Azure VM](./03.jpg)

* At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process.

    Let the script to run its course and **do not close** the PowerShell session, this will be done for you once completed.

    > **Note: The script run time is ~10-15min long**

    ![Screenshot showing PowerShell script executing in VM](./04.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./05.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./06.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./07.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./08.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./09.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./10.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./11.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./12.jpg)

    ![Screenshot showing showing PowerShell script executing in VM](./13.jpg)

* Upon successful run, in the Azure portal, notice you now have a new Azure Arc-enabled server (with the Microsoft Monitoring agent installed via an extension) and Azure Arc-enabled SQL resources as well as Azure Log Analytics added to the resource group.

    ![Screenshot showing Azure Arc-enabled SQL resources](./14.jpg)

    ![Screenshot showing Azure Arc-enabled SQL resources](./15.jpg)

    ![Screenshot showing Azure Arc-enabled SQL resources](./16.jpg)

* Open Microsoft SQL Server Management Studio (a Windows shortcut will be created for you) and validate the *AdventureWorksLT2019* sample database is deployed as well.

    ![Screenshot showing SQL Management Studio](./17.jpg)

    ![Screenshot showing SQL Management Studio](./18.jpg)

## Azure SQL Assessment

Now that you have both the server and SQL projected as Azure Arc resources, the last step is complete the initiation of the SQL Assessment run.

* On the SQL Azure Arc resource, click on "Environment Health" followed by clicking the "Download configuration script".

    Since the *LogonScript* run in the deployment step took care of deploying and installing the required binaries, you can safely ignore and delete the downloaded *AddSqlAssessment.ps1* file.

    Clicking the "Download configuration script" will simply send a REST API call to the Azure portal which will make "Step3" available and will result with a grayed-out "View SQL Assessment Results" button.

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./19.jpg)

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./20.jpg)

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./21.jpg)

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./22.jpg)

    It might take a bit of time, but after ~45-60min you will notice how the "View SQL Assessment Results" button is available for you to click on. At this point, the SQL assessment data and logs are getting injected to Azure Log Analytics.

    Initially, the amount of data will be limited as it take a while for the assessment to complete a full cycle but after few hours you should be able to see much more data coming in.  

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./23.jpg)

    ![Screenshot showing Environment Health blade of Azure Arc-enabled SQL server](./24.jpg)

## Cleanup

To delete the entire deployment, simply delete the resource group from the Azure portal.

![Screenshot showing Azure Portal delete resource group function](./25.jpg)
