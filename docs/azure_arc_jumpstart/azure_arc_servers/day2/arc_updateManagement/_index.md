---
type: docs
title: "Update Management"
linkTitle: "Update Management"
weight: 9
description: >
---

## Enable Update Management on Azure Arc-enabled servers

The scenario will show you how to onboard Azure Arc-enabled servers to [Update Management](https://docs.microsoft.com/en-us/azure/automation/update-management/overview), so that you can manage operating system updates for your Azure Arc-enabled servers running Windows or Linux.

In this guide, you will create and configure an Azure Automation account and Log Analytics workspace to support Update Management for Azure Arc-enabled servers by doing the following:

* Setup a new Log Analytics Workspace and Azure Automation account.

* Enable Update Management on Azure Arc-enabled servers.

> **Note: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc but If you haven't, this repository offers you a way to do so in an automated fashion:**

* **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
* **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
* **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
* **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
* **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
* **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
* **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
* **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
* **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
* **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* As mentioned, this guide starts at the point where you already deployed and connected VMs or bare-metal servers to Azure Arc. For this scenario, as can be seen in the screenshots below, we will be using an Amazon Web Services (AWS) EC2 instance that has been already connected to Azure Arc and is visible as a resource in Azure.

    ![Screenshot showing AWS cloud console with EC2 instance](./01.png)

    ![Screenshot showing Azure Portal with Azure Arc-enabled server](./02.png)
    
    > **Note: Ensure that the server you will use for this scenario is running an [OS supported by Update Management](https://docs.microsoft.com/en-us/azure/automation/update-management/overview#supported-operating-systems)and meets the [system requirements](https://docs.microsoft.com/en-us/azure/automation/update-management/overview#system-requirements).**

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.14 or later. Use ```az --version``` to check your current installed version.

## Configuring Update Management

Update Management uses the Log Analytics agent to collect Windows and Linux server log files and the data collected is stored in a Log Analytics workspace.

* You will need to create a Log Analytics workspace. For that you can use this [ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/updateManagement/law-template.json) that will create a new Log Analytics Workspace and define the Update Management solution and enable it for the workspace.

* First, create a new resource group for the Log Analytics workspace by running the below command, replacing the values in brackets with your own.

    ```shell
    az group create --name <Name for your resource group> \
    --location <Location for your resources> \
    --tags "Project=jumpstart_azure_arc_servers"
    ```

    ![Screenshot showing az group create being run](./03.png)

* Next, edit the ARM template [parameters file](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/updateManagement/law-template.parameters.json), providing a name for your Log Analytics workspace, a location, and a name for your Azure Automation account. You also need to supply the name of your Azure Arc-enabled server, and the name of the resource group that contains the Arc-enabled server as shown in the example below:

    ![Screenshot showing Azure ARM template](./04.png)

* To deploy the ARM template, navigate to the [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/updateManagement) and run the below command:

    ```shell
    az deployment group create --resource-group <Name of the Azure resource group you created> \
        --template-file law-template.json \
        --parameters law-template.parameters.json
    ```

   ![Screenshot showing az deployment group create being run](./05.png)

* When the deployment is complete, you should be able to see the resource group with your Log Analytics workspace, automation account and Update Management solution from the Azure Portal. Drilling into the Log Analytics workspace Solutions blade should show the Update Management solution.

    ![Screenshot showing Azure Portal with Log Analytics workspace](./06.png)

## Confirm that the Update Management solution is deployed on your Azure Arc-enabled server

* Click on the Solutions blade of the Log Analytics workspace and then click the Updates solution from the list to check the progress of the Update Management assessment.

    ![Screenshot showing Solutions Blade of Log Analytics workspace](./13.png)

* It may take several hours for Update Management to collect enough data to show an assessment for your VM. In the screen below we can see the assessment is being performed.

    ![Screenshot showing Update Management overview blade](./14.png)

* When the assessment is complete, you will see an option to "View summary" on the Update Management blade.

    ![Screenshot showing Update Management with summary](./15.png)

* Click View Summary and then click again to drill into the Update Management assessment. In the below example we can see there are updates missing on our Azure Arc-enabled server.

    ![Screenshot showing ](./16.png)

## Schedule an Update

Now that we have configured the Update Management solution, we can deploy updates on a set schedule for our Azure Arc-enabled server.

* Navigate to the Automation Account we created previously and click on the Update Management blade as shown in the screenshot below. You should see your Azure Arc-enabled server listed.

    ![Screenshot showing Azure Automation account](./18.png)

* From the above screen, click "Schedule update deployment". On the next screen, select the Operating System that your Azure Arc-enabled server is using, and then select "Machines to update" as shown below.

    ![Screenshot showing scheduling an update with Update Management](./19.png)

* From the "Type" dropdown, select "Machines" and then select your server and click Ok.

    ![Screenshot showing scheduling an update with Update Management](./20.png)

* Click Schedule Settings and then provide a desired schedule.

    ![Screenshot showing scheduling an update with Update Management](./21.png)

    ![Screenshot showing scheduling an update with Update Management](./22.png)

* Finally, provide a name for your Update deployment and then click Create.

    ![Screenshot showing scheduling an update with Update Management](./23.png)

* From the Automation Account Update Management blade, you should be able to see your scheduled Update deployment from the Deployment Schedules tab.
    ![Screenshot showing scheduled update](./24.png)

The Update Management solution will now update your Azure Arc-enabled servers in the deployment window based on the schedule you defined. There is a lot more you can do with [Update Management](https://docs.microsoft.com/en-us/azure/automation/update-management/overview) that is outside the scope of this scenario. Review the [documentation](https://docs.microsoft.com/en-us/azure/automation/update-management/overview) for more information.

## Clean up environment

Complete the following steps to clean up your environment.

* Remove the virtual machines from each environment by following the teardown instructions from each guide.

* **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
* **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
* **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
* **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
* **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
* **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
* **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
* **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
* **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
* **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

* Delete the resource group.

    ```shell
    az group delete --name <Name of your resource group>
    ```

    ![Screenshot showing az group delete being run](./26.png)
