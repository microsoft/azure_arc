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

  - "On-premises" resource group: will simulate a private on-premises environment with a Windows virtual machine. This VM does will not have a public IP address assigned to it so [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) is deployed to have access to the operating system. The Windows virtual machine is an Azure Arc-enabled server by installing the Azure Arc-connected machine agent.
  - Azure resource group: in this resource group, you will have the Azure Arc-enable server and its Private Link Scope, as well as the required [Azure DNS](https://docs.microsoft.com/en-us/azure/dns/dns-overview) configurations.

- Both resource groups have their own virtual networks and address spaces, however, they are connected via Azure VPN gateways to set up a hybrid private connection.

  ![Deployment Overview](./01.png)

Once everything is deployed, you will be able to onboard the Windows machine on the "on-premises" to Azure Arc using private endpoints via the Azure Arc Private Link Scope, while network traffic will go over the VPN connection.

  > **Note: It is not expected for an Azure VM to be projected as an Azure Arc-enabled server. The below scenario is unsupported and should ONLY be used for demo and testing purposes.**
  > **Note: The below scenario assumes the on-premises VM has outbound internet connectivity for the deployment of the Azure Arc connected machine agent, for internet disconnected environments you will need to adjust the automation to retrieve the agent's software from locally accessible storage**

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

3. User configure DNS resolution for private DNS endpoints.

4. User adds the Azure Arc-enabled server to the Azure Arc Private Link Scope.

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

    az deployment sub create \
    --location eastus \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/azure/privatelink/nesteddeploy.json \
    --parameters nesteddeploy.example.parameters.json
    ```

     > **Note: The deployment may take around 30-40 minutes to complete**

- Verify the resources are created on the Azure Portal for both resource groups:

    ![Resources created on Azure's resource group](./02.png)

    ![Resources created on Onpremises's resource group](./03.png)

- Notice there should be an Azure Arc-enabled server on the Azure resource group.

    ![Azure Arc-enabled server](./04.png)

## Configure DNS and add the Azure-Arc enabled server to the Private Link Scope

- Now that all resources are deployed you will need to configure DNS resolution for the Azure Arc private endpoints. The Azure Arc connected machine agent connects to a set of Azure Endpoints that by default are public, by adding the Azure Arc-enabled server to the Azure Arc Private Link scope we are making the connection between the agent and Azure private, however you need to make sure that there is DNS resolution for those endpoints and that they resolve the private IP address. To make sure that the [DNS settings resolve the private endpoint](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns) IP address to the fully qualified domain name (FQDN) of the connection string, you could:
  - Use the host file
  - Use a private DNS zone
  - Configure a DNS forwarder

  For this instance we will modify the host file on the virtual machine to override the DNS.

- Connect to the Azure Windows VM using Azure Bastion:

  - On the "on-premises" resource group select the Windows VM:

    ![Azure Bastion session 01](./05.png)

  - Under "Connect" choose Bastion:

    ![Azure Bastion session 02](./06.png)

  - Provide the VM credentials and click on "Connect":

    ![Azure Bastion session 03](./07.png)

- Get the private endpoint's private IP addresses, navigate to the Private endpoint resource and choose "DNS configuration"

  ![Private Endpoint](./08.png)

  ![Private Endpoint DNS configuration](./09.png)

- From the Bastion session open a PowerShell with admini priviliges and run the commands below to add the list of private IP addresses and FQDNs to the on-premises Windows VM host file.

    ```powershell
    Install-Module -Name 'Carbon' -AllowClobber
    Import-Module 'Carbon'
    Set-CHostsEntry -IPAddress <your IP address> -HostName 'glb.his.arc.azure.com'
    Set-CHostsEntry -IPAddress <your IP address> -HostName 'we.his.arc.azure.com'
    Set-CHostsEntry -IPAddress <your IP address> -HostName 'agentserviceapi.guestconfiguration.azure.com'
    Set-CHostsEntry -IPAddress <your IP address> -HostName 'westeurope-gas.guestconfiguration.azure.com'
    Set-CHostsEntry -IPAddress <your IP address> -HostName 'westeurope.dp.kubernetesconfiguration.azure.com'
    ```

  ![Add Host files](./10.png)

- Add the Azure Arc-enabled server to the Azure Arc Private Link Scope. Navigate to the Azure Arc Private Link Scope on the Azure resource group and select "Azure Arc resources" to add the Azure Arc-enabled server.

  ![Private Link Scope](./11.png)

  ![Azure Arc resources](./12.png)

  ![Add Azure Arc-enabled Server](./13.png)

## Clean up environment

To delete the entire deployment, simply delete both resources groups from the Azure portal.

  ![Delete Azure's resource group](./13.png)

  ![Delete Onpremises resource group](./14.png)
  