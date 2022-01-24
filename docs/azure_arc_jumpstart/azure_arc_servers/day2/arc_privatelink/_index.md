---
type: docs
title: "Azure Private Link"
linkTitle: "Azure Private Link"
weight: 11
description: >
---

## Use Azure Private Link to securely connect networks to Azure Arc

The following README will guide you on how to use [Azure Private Link](https://docs.microsoft.com/en-us/azure/private-link/private-link-overview) to securely connect from an Azure Arc-enabled server to Azure PaaS services. [This feature](https://docs.microsoft.com/en-us/azure/azure-arc/servers/private-link-security) not only allows you to link your Azure PaaS services to your virtual network using private endpoints but also enables you to connect your on-premises or multi-cloud resources with Azure Arc and ensure that all traffic is being sent over a VPN or ExpressRoute connection.

In this guide, you will emulate a hybrid environment connected to Azure over a VPN with hybrid resources that will be Arc-enabled, and Azure Private Link will be used to connect to an Azure PaaS service over a private connection. To complete this process you deploy a single ARM template that will:

- Create two separate resource groups:

  - "On-premises" resource group: will simulate a private on-premises environment with a Windows virtual machine. This VM does will not have a public IP address assigned to it so [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) is deployed to have access to the operating system. The Windows virtual machine is an Azure Arc-enabled server by installing the Azure Arc-connected machine agent.
  - Azure resource group: in this resource group, you will be deploying all Azure PaaS resources, in this case, [Azure DNS](https://docs.microsoft.com/en-us/azure/dns/dns-overview) and [Azure SQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/sql-database-paas-overview). In order to establish a private connection to these Azure services, Azure Private Link will be deployed as well.

- Both resource groups have their own virtual networks and address spaces, however, they are connected via Azure VPN gateways to set up a hybrid private connection.

  ![Deployment Overview](./01.png)

Once everything is deployed, you will be able to access the Azure SQL private IP address from the "on-premises" Windows machine while network traffic will go over the VPN connection and be kept within the Azure VNET via Private Link to access the database service.

  > **Note: It is not expected for an Azure VM to be projected as an Azure Arc-enabled server. The below scenario is unsupported and should ONLY be used for demo and testing purposes.**

## Prerequisites

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

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
        - Azure SQL server and a SQL database
        - Azure Private Link
        - Azure Private DNS zone
        - Azure VPN Gateway and its public IP address
        - Azure VNET

    - On-premises resource group:
        - Azure VNET
        - Azure Bastion
        - Azure VPN Gateway and its public IP address
        - Azure Windows Virtual Machine with a custom script extension that will run the [_install_arc_agent.sh_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/azure/linux/arm_template/scripts/install_arc_agent.sh) shell script to Arc-enable the Azure VM.

        > **Note: The [_install_arc_agent.sh_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/azure/linux/arm_template/scripts/install_arc_agent.sh) shell script will enable the OS firewall and set up new rules for incoming and outgoing connections. By default all incoming and outgoing traffic will be allowed, except blocking Azure IMDS outbound traffic to the *169.254.169.254* remote address.**

3. User tests private connectivity to Azure SQL server from the Azure Windows Virtual Machine.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single ARM template at subscription scope that will deploy resources to the Azure's resource group as well as the "on-premises" resources that will be onboarded to Azure Arc.

- Before deploying the ARM template, login to Azure using AZ CLI with the ```az login``` command.

- The deployment will use an ARM template parameters file to customize your environment. Before initiating the deployment, edit the [*nesteddeploy.parameters.json*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/privatelink/nesteddeploy.parameters.json) file located in your local cloned repository folder. Example parameters files is located [here](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/privatelink/nesteddeploy.example.parameters.json).

- To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/privatelink) and run the below command, start deploying resources:

    ```shell
    az deployment sub create \
    --location <Azure Region Location> \
    --template-file <The *azuredeploy.json* template file location> \
    --parameters <The *azuredeploy.parameters.json* parameters file location>

    For example:

    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/azure/privatelink/nesteddeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

     > **Note: The deployment may take around 30-40 minutes to complete**

- Verify the resources are created on the Azure Portal for both resource groups:

    ![Resources created on Azure's resource group](./02.png)

    ![Resources created on Onpremises's resource group](./03.png)

- Notice there should be an Azure Arc-enabled server on the Azure resource group.

    ![Azure Arc-enabled server](./04.png)

## Connectivity test

- Now that all resources are deployed in both resources groups, you can verify that there is a private connection from the Azure Arc-enabled server to the Azure SQL database, this connection will go through the VPN gateways that connect the two VNETs and the network traffic will continue over the Microsoft's network to reach the PaaS service on its private IP enpoint's address since Azure Private link has been enabled.

- To perform the test you will need the database's private endpoint IP address. Navigate to the resource group in the Azure Portal as described below:

  - Select the Private endpoint resource:

      ![Private endpoint resource](./05.png)

  - Select the Private Enpoint's network interface:

      ![Private endpoint network interface](./06.png)

  - Copy the private IP address:

      ![Private endpoint private IP address](./07.png)

- You can then do some connectivity checks to ensure that the on-premises VM is connecting to SQL Database via the private endpoint, you will use telnet for this purpose. To connect to the Azure Windows VM you will use Azure Bastion to connect and test private connectivity to the database:

  - On the "on-premises" resource group select the Windows VM:

    ![Azure Bastion session 01](./08.png)

  - Under "Connect" choose Bastion:

    ![Azure Bastion session 02](./09.png)

  - Provide the VM credentials and click on "Connect":

    ![Azure Bastion session 03](./10.png)

  - Open an administrative session of PowerShell and run the commands below:

    ```powershell
    Install-WindowsFeature -Name Telnet-Client
    telnet <private_endpoint_IP> 1433
    ```

  For example:

    ```powershell
    Install-WindowsFeature -Name Telnet-Client
    telnet 172.16.0.68 1433
    ```

    ![Azure Bastion session 04](./11.png)

- When Telnet connects successfully, you'll see a window like the below image:

  ![Telnet connection](./12.png)

## Clean up environment

To delete the entire deployment, simply delete both resources groups from the Azure portal.

  ![Delete Azure's resource group](./13.png)

  ![Delete Onpremises resource group](./14.png)
  