# Overview

The following README will guide you on how to manage extensions on Azure Arc connected machines. Virtual machine extensions are small applications that provide post-deployment configuration and automation tasks such as software installation, anti-virus protection, or a mechanism to run a custom script.

Azure Arc for servers,  enables you to deploy Azure VM extensions to non-Azure Windows and Linux VMs, giving you a hybrid or multicloud management experience that levels to Azure VMs.

You can use the Azure Portal, an ARM template, PowerShell script or Azure policies to manage the extension deployment to Arc servers, both Linux and Windows. In this guide, you will use an ARM template to deploy the Custom Script extension.This extension downloads and executes scripts on virtual machines and it is useful for post deployment configuration, software installation, or any other configuration or management tasks.

**Note: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc.**

**If you haven't, this repository offers you a way to do so in an automated fashion:**
- **[GCP Ubuntu VM](gcp_terraform_ubuntu.md) / [GCP Windows VM](gcp_terraform_windows.md)**
- **[AWS Ubuntu VM](aws_terraform_ubuntu.md)**
- **[VMware Ubuntu VM](vmware_terraform_ubuntu.md) / [VMware Windows Server VM](vmware_terraform_winsrv.md)**
- **[Local Ubuntu VM](local_vagrant_ubuntu.md) / [Local Windows VM](local_vagrant_windows.md)**

# Prerequisites

* Clone this repo.

* Register your subscription to access preview extensions functionality.

* As mentioned, this guide starts at the point where you already deployed and connected VMs or servers to Azure Arc.

    ![](../img/vm_extension_customscript/01.png)

    ![](../img/vm_extension_customscript/02.png)

* You must have a script to run on the VM. In this case, you can use these scripts for [*Linux*](../scripts/custom_script_linux.sh) or [*Windows*](../scripts/custom_script_windows.sh)

    
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
    ```

    Then, assign a the "Contributor" role to the SP you've just created.

    ```az role assignment create --assignee "<Unique SP Name>" --role contributor```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) 

# Azure Arc for Servers Custom Script Extension Deployment

* Edit the [*parameters file*](../extensions/arm/customscript-template.parameters.json) to match your environment configuration, you will need to provide the following: 

- The VMname as it is registered in Azure Arc
- The location of the resource group where you registered the Azure Arc connected VM  
- A public Uri for the script that you would like to run on the servers, in this case use the URL for the script in raw format
- The command that will triger the script: 
    - For Windows: ```powershell -ExecutionPolicy Unrestricted -File custom_script_windows.ps1 ```
    - For Linux: ```./custom_script_linux.sh```

* After you have provided your parameters, deploy the template by running the following command: 

    ```bash
    az deployment group create --resource-group <resource-group-name> --template-file <path-to-template> --parameters <path-to-parametersfile>
    ```
   
* Once the template has completed it's run, you should see an output as follows: 

    ![](../img/vm_extension_customscript/08.png)
    
Since on the scripts we deployed configured our operating systems we can verify the results. 

* For Linux VMs login to your VM and checkout the message of the day, it was customized by the script so you should see a message like this: 

    ![](../img/vm_extension_customscript/09.png)

* For the Windows VM we deployed some applications in this case: Microsoft Edge, 7zip and Visual Studio Code. RDP to your VM and make sure the applications are installed. 