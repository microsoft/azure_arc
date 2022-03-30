---
type: docs
title: "Azure Private Link"
linkTitle: "Azure Private Link"
weight: 11
description: >
---

## Use Azure Private Link to securely connect networks to Azure Arc

The following README will guide you on how to use [Azure Private Link](https://docs.microsoft.com/en-us/azure/private-link/private-link-overview) to securely connect from an Azure Arc-enabled server to Azure using a VPN. [This feature](https://docs.microsoft.com/en-us/azure/azure-arc/servers/private-link-security) allows you to connect privately to Azure Arc without opening up public network access but rather using private endpoints over a VPN or ExpressRoute connection, ensuring that all traffic is being sent to Azure privately.

In this guide, you will emulate a hybrid environment connected to Azure over a VPN with hybrid resources that will be Arc-enabled, and Azure Private Link Scope will be used to connect over a private connection. To complete this process you deploy a single ARM template that will:

- Create two separate resource groups:

  - "On-premises" resource group: will simulate a private on-premises environment with a Windows virtual machine. This VM will not have a public IP address assigned to it so [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) is deployed to have administrative access to the operating system. The Windows virtual machine is an Azure Arc-enabled server by installing the Azure Arc-connected machine agent using Azure Private Link.
  - "Azure" resource group: in this resource group, you will have the Azure Arc-enabled server and its Private Link Scope.

- Both resource groups have their own virtual networks and address spaces, and they are connected via Azure VPN gateways to set up a hybrid private connection.

  ![Deployment Overview](./01.png)

  > **NOTE: It is not expected for an Azure VM to be projected as an Azure Arc-enabled server. The below scenario is unsupported and should ONLY be used for demo and testing purposes.**
  > **NOTE: The below scenario assumes the on-premises VM has outbound internet connectivity for the deployment of the Azure Arc connected machine agent, for internet disconnected environments you will need to adjust the automation to retrieve the agent's software from locally accessible storage**

## Prerequisites

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.25.0** or later. Use ```az --version``` to check your current installed version.

- Azure Arc-enabled servers depends on the following Azure resource providers in your subscription in order to use this service. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  - Microsoft.HybridCompute
  - Microsoft.GuestConfiguration

      ```shell
      az provider register --namespace 'Microsoft.HybridCompute'
      az provider register --namespace 'Microsoft.GuestConfiguration'
      ```

      You can monitor the registration process with the following commands:

      ```shell
      az provider show --namespace 'Microsoft.HybridCompute'
      az provider show --namespace 'Microsoft.GuestConfiguration'
      ```

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User is editing the ARM template parameters file (1-time edit). These parameters values are being used throughout the deployment.

2. User deploys the ARM template at subscription level. The ARM template will create two resources groups with:

    - Azure resource group:
        - Azure Arc Private Link Scope
        - Azure Arc-enabled server
        - Azure Private Link Endpoint for the Azure Arc-enabled Server
        - Three Azure Private DNS zones
        - Azure VPN Gateway and its public IP address
        - Azure VNET

    - On-premises resource group:
        - Azure VNET
        - Azure Bastion
        - Azure VPN Gateway and its public IP address
        - Azure Windows Virtual Machine with a custom script extension that runs the **install_arc_agent.sh** script

        > **Note: The [*install_arc_agent.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/azure/linux/arm_template/scripts/install_arc_agent.sh) shell script will enable the OS firewall and set up new rules for incoming and outgoing connections. By default all incoming and outgoing traffic will be allowed, except blocking Azure IMDS outbound traffic to the *169.254.169.254* remote address.**

3. User logs in to the on-premises VM using Azure Bastion to trigger the Azure Arc onboarding script.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single ARM template at subscription scope that will deploy resources to the Azure's resource group as well as the "On-premises" resources that will be onboarded to Azure Arc.

- Before deploying the ARM template, login to Azure using AZ CLI with the ```az login``` command.

- The deployment will use an ARM template parameters file to customize your environment. Before initiating the deployment, edit the [*nesteddeploy.parameters.json*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/privatelink/nesteddeploy.parameters.json) file located in your local cloned repository folder. Example parameters files is located [here](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/privatelink/nesteddeploy.example.parameters.json).

- To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/privatelink) and run the below command, start deploying resources:

    ```shell
    az deployment sub create \
    --location <Azure Region Location> \
    --template-file <The *azuredeploy.json* template file location> \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    For example:

    ```shell
    az deployment sub create \
    --location eastus \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/azure/privatelink/nesteddeploy.json \
    --parameters nesteddeploy.example.parameters.json
    ```

     > **NOTE: The deployment may take around 45 minutes to complete**

- Verify the resources are created on the Azure Portal for both resource groups:

    ![Resources created on Onpremises's resource group](./02.png)

    ![Resources created on Azure's resource group](./03.png)

## Windows Login & Post Deployment

- Now that the Windows Server VM is created and the VPN connections are established, it is time to RDP to it using Azure Bastion.

  - On the "on-premises" resource group select the Windows VM:

    ![Azure Bastion session 01](./04.png)

  - Under "Connect" choose Bastion:

    ![Azure Bastion session 02](./05.png)

  - Provide the VM credentials and click on "Connect":

    ![Azure Bastion session 03](./06.png)

- At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process.

- Let the script to run its course and **do not close** the Powershell session, this will be done for you once completed.

    > **NOTE: The script run time is ~1-2min long.**

    ![Screenshot script output](./07.png)

- Upon successful run, a new Azure Arc-enabled server will be added to the resource group.

  ![Screenshot Azure Arc-enabled server on resource group](./08.png)

## Azure Arc-enabled server Private Link connectivity

To make sure that your Azure Arc-enabled server is using Private Link for its connection. Use your Azure Bastion session to run the command below:

  ```powershell
    azcmagent.exe show
  ```

It should list your Private Link Scope ID.

  ![Connected Machine agent using PL](./09.png)

## Delete the deployment

The most straightforward way is to delete both resource groups:

  ![Delete Resource Group On-premises](./10.png)
  
  ![Delete Resource Group Azure](./11.png)
