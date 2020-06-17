# Overview

The following README will guide you on how to use Arc for servers to deploy to the VM the Microsoft Monitoring Agent extension. This feature provides Azure Arc connected servers an enrollment experience to other management services that levels to Azure VMs.

You can use the Azure Portal, an ARM template, PowerShell script or Azure policies to manage the extension deployment to Arc servers, both Linux and Windows. In this guide, you will use an ARM template deploy the Microsoft Monitoring Agent (MMA) to your servers so they are onboarded on Azure Services that leverage this service: Azure Monitor, Azure Security Center, Azure Sentinel, etc. 

**Note: This guide assumes you already deployed VMs or servers that are running on-prem or other clouds and you have connected them to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion using either [GCP Ubuntu VM](gcp_terraform_ubuntu.md), [GCP Windows VM](gcp_terraform_windows.md), [AWS Ubuntu VM](aws_terraform_ubuntu.md), [VMware Ubuntu VM](vmware_terraform_ubuntu.md), [VMware Windows Server VM](vmware_terraform_winsrv.md), [Local Ubuntu VM](local_vagrant_ubuntu.md) or [Local Windows VM](local_vagrant_windows.md)**

# Prerequisites

* Clone this repo

* Register your subscription to access preview extensions functionality

* As mentioned, this guide starts at the point where you already deployed and connected VMs or servers to Azure Arc.

    ![](../img/vm_extension_mma/01.png)

    ![](../img/vm_extension_mma/02.png)

* You must have a Log Analytics Workspace created prior to making Extension Install request.

    ![](../img/vm_extension_mma/03.png)

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.6.0 or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    To connect a VM or Server to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --skip-assignment
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcservers" --skip-assignment```

    Output should look like this:
    ```terminal
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcservers",
    "name": "http://AzureArcservers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }

    Then, assign a the "Contributor" role to the SP you've just created.

    ```az role assignment create --assignee "<Unique SP Name>" --role contributor```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) 

# Azure Arc for Servers Microsoft Monitoring Agent Extension Deployment

* Edit the [*parameters file*](../extensions/arm/mma-template.parameters.json) to match your environment configuration, you will need to provide: 

- The VMname as it is registered in Azure Arc
- The location of the resource group where you registered the Azure Arc connected VM  
- Information of the Log Analytics Workspace you previously created: Workspace ID and key. These parameters will be used to configure the MMA agent. You can get this information by going to your Log Analytics Workspace and under "Settings" select "Agent Management"


    ![](../img/vm_extension_mma/04.png)

    ![](../img/vm_extension_mma/05.png)

* Choose the ARM template that matches your Operating System, for [*Windows*](../extensions/arm/mma-template-windows.json) and [*Linux*](../extensions/arm/mma-template-linux.json), deploy the template by running the following command: 

    ```bash
    az deployment group create --resource-group <resource-group-name> --template-file <path-to-template> --parameters <path-to-parametersfile>
    ```
   
* * Once the template has completed it's run, you should see an output as follows: 

    ![](../img/vm_extension_mma/08.png)
    
* You will have the Microsoft Monitoring agent deployed on your Windows or Linux system and reporting to the Log Analytics Workspace that you have selected. You can verify by going back to the "Agents Management" section of your workspace and choosing either Windows or Linux, you should see now an additional connected VM. 

    ![](../img/vm_extension_mma/06.png)

    ![](../img/vm_extension_mma/07.png)