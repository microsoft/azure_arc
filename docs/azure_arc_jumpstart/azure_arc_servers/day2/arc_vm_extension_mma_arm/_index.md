---
title: "Azure Arc enabled servers MMA Extension"
linkTitle: "Azure Arc enabled servers MMA Extension"
weight: 2
description: >
---

# Azure Arc enabled servers MMA Extension

The following README will guide you on how to manage extensions on Azure Arc connected machines. Virtual machine extensions are small applications that provide post-deployment configuration and automation tasks such as software installation, anti-virus protection, or a mechanism to run a custom script.

Azure Arc enabled servers, enables you to deploy Azure VM extensions to non-Azure Windows and Linux VMs, giving you a hybrid or multicloud management experience that levels to Azure VMs.

You can use the Azure Portal, Azure CLI, an ARM template, PowerShell script or Azure policies to manage the extension deployment to Azure Arc enabled servers, both Linux and Windows. In this guide, you will use an ARM template deploy the Microsoft Monitoring Agent (MMA) to your servers so they are onboarded on Azure Services that leverage this service: Azure Monitor, Azure Security Center, Azure Sentinel, etc. 

**Note: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc.**

**If you haven't, this repository offers you a way to do so in an automated fashion:**
- **[GCP Ubuntu VM](../../gcp/gcp_terraform_ubuntu/) / [GCP Windows VM](../../gcp/gcp_terraform_windows)**
- **[AWS Ubuntu VM](../../aws/aws_terraform_ubuntu/)**
- **[VMware Ubuntu VM](../../vmware/vmware_terraform_ubuntu/) / [VMware Windows Server VM](../../vmware/vmware_terraform_winsrv)**
- **[Local Ubuntu VM](../../vagrant/local_vagrant_ubuntu/) / [Local Windows VM](../../vagrant/local_vagrant_windows)**

Please review the [Azure Monitor Supported OS documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-enable-overview#supported-operating-systems) and ensure that the VMs you will use for this exercise are supported. For Linux VMs, check both the Linux distro and kernel to ensure you are using a supported configuration.

## Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* As mentioned, this guide starts at the point where you already deployed and connected VMs or servers to Azure Arc. In the screenshots below you can see a GCP server has been connected with Azure Arc and is visible as a resource in Azure.

    ![](./01.png)

    ![](./02.png)


* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure service principal (SP)   

    To connect a VM or bare-metal server to Azure Arc, Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

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
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) 

* You will also need to have a Log Analytics Workspace deployed. You can automate the deployment by editing the ARM template [parameters file](https://github.com/microsoft/azure_arc/blob/master/azure_arc_servers_jumpstart/extensions/arm/log_analytics-template.parameters.json) and provide a name and location for your workspace. 

    ![](./03.png)

To deploy the ARM template, navigate to the "deployment folder"-***../extensions/arm*** and run the below command:

  ```bash
    az deployment group create --resource-group <Name of the Azure resource group> \
    --template-file <The *log_analytics-template.json* template file location> \
    --parameters <The *log_analytics-template.parameters.json* template file location>
  ```

## Azure Arc enabled servers Microsoft Monitoring Agent Extension Deployment

* Edit the [*extensions parameters file*](https://github.com/microsoft/azure_arc/blob/master/azure_arc_servers_jumpstart/extensions/arm/mma-template.parameters.json) 

    ![](./04.png)

* To match your configuration you will need to provide: 
    - The VM name as it is registered in Azure Arc

    ![](./05.png)

    - The location of the resource group where you registered the Azure Arc connected VM  

    ![](./06.png)

    - Information of the Log Analytics Workspace you previously created: Workspace ID and key. These parameters will be used to configure the MMA agent. You can get this information by going to your Log Analytics Workspace and under "Settings" select "Agent management"

    ![](./07.png)

    ![](./08.png)

* Choose the ARM template that matches your Operating System, for [*Windows*](https://github.com/microsoft/azure_arc/blob/master/azure_arc_servers_jumpstart/extensions/arm/mma-template-windows.json) and [*Linux*](https://github.com/microsoft/azure_arc/blob/master/azure_arc_servers_jumpstart/extensions/arm/mma-template-linux.json), deploy the template by running the following command: 

    ```bash
    az deployment group create --resource-group <Name of the Azure resource group> \
    --template-file <The *mma-template.json* template file location> \
    --parameters <The *mma-temaplte.parameters.json* template file location>
    ```
   
* Once the template has completed it's run, you should see an output as follows: 

    ![](./09.png)
    
* You will have the Microsoft Monitoring agent deployed on your Windows or Linux system and reporting to the Log Analytics Workspace that you have selected. You can verify by going back to the "Agents management" section of your workspace and choosing either Windows or Linux, you should see now an additional connected VM. 

    ![](./10.png)

    ![](./11.png)

## Clean up environment

Complete the following steps to clean up your environment.

* Remove the virtual machines from each environment by following the teardown instructions from each guide.

    - *[GCP Ubuntu VM](../../gcp/gcp_terraform_ubuntu/) / [GCP Windows VM](../../gcp/gcp_terraform_windows)*
    - *[AWS Ubuntu VM](../../aws/aws_terraform_ubuntu/)*
    - *[VMware Ubuntu VM](../../vmware/vmware_terraform_ubuntu/) / [VMware Windows Server VM](../../vmware/vmware_terraform_winsrv)*
    - *[Local Ubuntu VM](../../vagrant/local_vagrant_ubuntu/) / [Local Windows VM](../../vagrant/local_vagrant_windows)*

* Remove the Log Analytics workspace by executing the following command in AZ CLI. Provide the workspace name you used when creating the Log Analytics Workspace.

    ```bash
    az monitor log-analytics workspace delete --resource-group <Name of the Azure resource group> --workspace-name <Log Analytics Workspace Name> --yes
    ```
    