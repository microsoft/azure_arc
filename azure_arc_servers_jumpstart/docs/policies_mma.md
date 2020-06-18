# Overview

The following README will guide you on how to use Arc for servers to assign Azure Policies to VMs outside of Azure, wether they are on-premise or other clouds. With this feature you can now use Azure Policies to audit settings in the operating system of an Azure Arc connected servers, if a setting is not compliant you can also trigger a remediation task. 

In this case we will assign a policy to audit if the Azure Arc connected machine has the (Microsoft Monitoring Agent) MMA agent installed, if not, we will use the extensions feature to automatically deploy it to the VM, an enrollment experience that levels to Azure VMs. This approach can be used to make sure all your servers are onboarded to services such as: Azure Monitor, Azure Security Center, Azure Sentinel, etc. 

You can use the Azure Portal, an ARM template or PowerShell script to assign policies to Azure Subscriptions or Resource Groups. In this guide, you will use an ARM template to assign built-in policies. 

**Note: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc.**

**If you haven't, this repository offers you a way to do so in an automated fashion:**
- **[GCP Ubuntu VM](gcp_terraform_ubuntu.md) / [GCP Windows VM](gcp_terraform_windows.md)**
- **[AWS Ubuntu VM](aws_terraform_ubuntu.md)**
- **[VMware Ubuntu VM](vmware_terraform_ubuntu.md) / [VMware Windows Server VM](vmware_terraform_winsrv.md)**
- **[Local Ubuntu VM](local_vagrant_ubuntu.md) / [Local Windows VM](local_vagrant_windows.md)**

# Prerequisites

* Clone this repo

* As mentioned, this guide starts at the point where you already deployed and connected VMs or servers to Azure Arc.

    ![](../img/vm_policies/01.png)

    ![](../img/vm_policies/02.png)

  
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    To connect a VM or bare-metal server to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

  ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```
    For example:
    ```az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor```
    Output should look like this:
    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    
**Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) 

* You will also need to have a Log Analytics Workspace deployed. You can automate the deployment by editing the ARM template [parameters file](../policies/arm/log_analytics-template.parameters.json) and provide a name and location for your workspace. Then start the deployment with the command:

    ![](../img/vm_policies/03.png)

    ```bash
    az deployment group create --resource-group <resource-group-name> --template-file <path-to-template> --parameters <path-to-parametersfile>
    ```

# Azure Policies on Azure Arc connected machines

* Now that we have all the requirements set. We can assign policies to our Arc connected machines using these commands. Edit the [parameters file](../policies/arm/policy.json) to provide your subscription ID as well as the Log Analytics Workspace. Then start the deployment with the command: 

    ![](../img/vm_policies/04.png)

    ```bash
    az policy assignment create --name 'Enable Azure Monitor for VMs' --scope '/subscriptions/<subscription_id>/resourceGroups/<resource_group>' --policy-set-definition '55f3eceb-5573-4f18-9695-226972c6d74a' -p "<path_to_json>" --assign-identity --location "<region>"
    ```

* Once you have assigned the initiative, you will see that it will be evaluated (it may take 30 minutes to run the first scan) and show that the server on GCP is not compliant.

  ![](../img/vm_policies/05.png)

* We can now add a remediation task by clicking on the Initiative 'Enable Azure Monitor' and selecting 'Create Remediation Task' 

  ![](../img/vm_policies/06.png)

* Under 'Policy to remediate' choose '[Preview] Deploy Log Analytics Agent to Linux Azure Arc machines' and select 'Remediate' 

  ![](../img/vm_policies/07.png)

* Once you have assigned remediation task, the policy will be evaluated again and show that the server on GCP is compliant. And that the Microsoft Monitoring Agent extension is installed on the Azure Arc machine. 

  ![](../img/vm_policies/08.png)

  ![](../img/vm_policies/09.png)

