---
type: docs
title: "AKS hybrid cluster provisioning from Azure"
linkTitle: "AKS hybrid cluster provisioning from Azure"
weight: 2
description: >
---

## Deploy an AKS hybrid cluster provisioned from Azure using an ARM Template

The following Jumpstart scenario will show how to create an AKS cluster provisioned from an Azure Windows Server VM and connect it to Azure Arc via resource Bridge, using an [Azure ARM Template](https://docs.microsoft.com/azure/azure-resource-manager/templates/overview) for deployment. The provided ARM template is responsible for creating the Azure resources as well as executing the LogonScript (AKS Edge Essentials cluster creation and Azure Arc onboarding (Azure VM and AKS Edge Essentials cluster)) on the Azure VM.

  > **NOTE: AKS hybrid cluster provisioning from Azure is now in preview- You can find more details about this service in the [AKS hybrid cluster provisioning from Azure document](https://learn.microsoft.com/azure/aks/hybrid/aks-hybrid-preview-overview)**

## Prerequisites

- [Install or update Azure CLI to version 2.42.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- In case you don't already have one, you can [Create a free Azure account](https://azure.microsoft.com/free/).

- Create Azure service principal (SP)

    To complete the scenario and its related automation, an Azure service principal with the “Contributor” and "Group Admin" role assigned is required. To create it, login to your Azure account and run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "" --role "Contributor" --scopes /subscriptions/$subscriptionId
    SP_CLIENT_ID=$(az ad sp create-for-rbac -n "<Unique SP Name>" --role Contributor --scopes /subscriptions/$subscriptionId --query appId -o tsv) 
    SP_OID=$(az ad sp show --id $SP_CLIENT_ID --query id -o tsv) 
    BODY=$(jq -n \
    --arg principalId "$SP_OID" \
    --arg roleDefinitionId "fdd7a751-b60b-444a-984c-02652fe8fa1c" \
    --arg directoryScopeId "/" \
    '{principalId: $principalId, roleDefinitionId: $roleDefinitionId, directoryScopeId: $directoryScopeId}')
    az rest --method POST --uri https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments --headers "Content-Type=application/json" --body "$BODY" az ad sp create-for-rbac --name "<Unique SP Name>"
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "" --role "Contributor" --scopes /subscriptions/$subscriptionId
    SP_CLIENT_ID=$(az ad sp create-for-rbac -n "JumpstartArc" --role Contributor --scopes /subscriptions/$subscriptionId --query appId -o tsv) 
    SP_OID=$(az ad sp show --id $SP_CLIENT_ID --query id -o tsv) 
    BODY=$(jq -n \
    --arg principalId "$SP_OID" \
    --arg roleDefinitionId "fdd7a751-b60b-444a-984c-02652fe8fa1c" \
    --arg directoryScopeId "/" \
    '{principalId: $principalId, roleDefinitionId: $roleDefinitionId, directoryScopeId: $directoryScopeId}')
    az rest --method POST --uri https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments --headers "Content-Type=application/json" --body "$BODY" az ad sp create-for-rbac --name "JumpstartArc"
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
    > **NOTE: The Jumpstart scenarios are designed with ease of use in-mind and adhere to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well as considering use of a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

- User edits the ARM template parameters file (1-time edit). These parameter values are used throughout the deployment.

- Main [_azuredeploy_ ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/azuredeploy.json) will initiate the deployment of the following resources:

  - _Virtual Network_ - Virtual Network for Azure Windows Server VM.
  - _Network Interface_ - Network Interface for Azure Windows Server VM.
  - _Public IP_ - Public IP address for the Azure Windows Server VM, unless Bastion was enabled.
  - _Network Security Group_ - Network Security Group to allow RDP in Azure Windows Server VM.
  - _Virtual Machine_ - Azure Windows Server VM.
  - _Azure Bastion_ - If boolean was set to true.
  - _Custom script and Azure Desired State Configuration extensions_ - Configure the Azure Windows Server VM to host AKS Edge Essentials.

- User remotes into client Windows VM, which automatically kicks off the [_LogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/artifacts/LogonScript.ps1) PowerShell script to create the AKS cluster in the Windows Server VM, and onboard the cluster to Azure Arc.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single template, responsible for creating all the Azure resources in a single resource group as well onboarding the created VM to Azure Arc.

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- Before deploying the ARM template, login to Azure using Azure CLI with the ```az login``` command.

- The deployment uses the ARM template parameters file. Before initiating the deployment, edit the [_azuredeploy.parameters.json_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/azuredeploy.parameters.json) file located in your local cloned repository folder. An example parameters file is located [here](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/azuredeploy.parameters.example.json).

  - _`vmName`_ - Virtual machine name.
  - _`spnClientId`_ - Service principal App ID.
  - _`spnClientSecret`_ - Service principal password.
  - _`spnTenantId`_ - Tenant ID where the service principal is created.
  - _`adminUsername`_ - Username for the Azure Windows VM.
  - _`adminPassword`_ - Password for the Azure Windows VM.
  
- To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/) and run the below command:

    ```shell
    az group create --name <Name of the Azure resource group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > **NOTE: Make sure that you are using the same Azure resource group name as the one you've just used in the _azuredeploy.parameters.json_ file**

    For example:

    ```shell
    az group create --name AKS-WS-Demo --location "East US"
    az deployment group create \
    --resource-group AKS-WS-Demo \
    --name akswsdemo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/aks_hybrid/aks_azurevm/arm_template/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

- Once Azure resources have been provisioned, you will be able to see them in Azure portal.

    ![Screenshot ARM template output](./01.png)

    ![Screenshot resources in resource group](./02.png)

## Windows Login & Post Deployment

Various options are available to connect to _AKS-VM-Demo_ Azure VM, depending on the parameters you supplied during deployment.

- [RDP](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_hybrid/aks_edge_essentials/#connecting-directly-with-rdp) - available after configuring access to port 3389 on the _Arc-Win-Demo-NSG_, or by enabling [Just-in-Time access (JIT)](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_hybrid/aks_edge_essentials/#connect-using-just-in-time-access-jit).
- [Azure Bastion](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks_hybrid/aks_edge_essentials/#connect-using-azure-bastion) - available if ```true``` was the value of your _`deployBastion`_ parameter during deployment.

### Connecting directly with RDP

By design, port 3389 is not allowed on the network security group. Therefore, you must create an NSG rule to allow inbound 3389.

- Open the _AKSVMLabNSG_ resource in Azure portal and click "Add" to add a new rule.

  ![Screenshot showing AKSVMLabNSG NSG with blocked RDP](./03.png)

  ![Screenshot showing adding a new inbound security rule](./04.png)

- Specify the IP address that you will be connecting from and select RDP as the service with "Allow" set as the action. You can retrieve your public IP address by accessing [https://icanhazip.com](https://icanhazip.com) or [https://whatismyip.com](https://whatismyip.com).

  ![Screenshot showing all inbound security rule](./05.png)

  ![Screenshot showing all NSG rules after opening RDP](./06.png)

  ![Screenshot showing connecting to the VM using RDP](./07.png)

### Connect using just-in-time access (JIT)

If you already have [Microsoft Defender for Cloud](https://docs.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage?tabs=jit-config-asc%2Cjit-request-asc) enabled on your subscription and would like to use JIT to access the Azure VM, use the following steps:

- In the Client VM configuration pane, enable just-in-time. This will enable the default settings.

  ![Screenshot showing the Microsoft Defender for cloud portal, allowing RDP on the client VM](./08.png)

  ![Screenshot showing connecting to the VM using JIT](./09.png)

### Connect using Azure Bastion

- If you have chosen to deploy Azure Bastion in your deployment, use it to connect to the Azure VM.

  ![Screenshot showing connecting to the VM using Bastion](./10.png)

  > **NOTE: When using Azure Bastion, the desktop background image is not visible. Therefore some screenshots in this guide may not exactly match your experience if you are connecting with Azure Bastion.**

### Post Deployment

- At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process.

- Let the script to run its course and **do not close** the Powershell session, this will be done for you once completed.

    > **NOTE: The script run time is ~13min long.**

    ![Screenshot script output](./11.png)

    ![Screenshot script output](./12.png)

    ![Screenshot script output](./13.png)

    ![Screenshot script output](./14.png)

    ![Screenshot script output](./15.png)

    ![Screenshot script output](./16.png)

    ![Screenshot script output](./17.png)

    ![Screenshot script output](./18.png)

    ![Screenshot script output](./19.png)

- Upon successful run, a new Azure Arc-enabled Kubernetes cluster will be added to the resource group. You should also see an Azure Arc Resource Bridge and a Custom Location.

![Screenshot Azure resources on resource group](./20.png)

### Exploring logs from the Client VM

Occasionally, you may need to review log output from scripts that run on the _AKS-WS-VM_ VM in case of deployment failures. To make troubleshooting easier, the scenario deployment scripts collect all relevant logs in the _C:\Temp_ folder on the Azure VM. A short description of the logs and their purpose can be seen in the list below:

| Log file | Description |
| ------- | ----------- |
| _C:\Temp\Bootstrap.log_ | Output from the initial _bootstrapping.ps1_ script that runs on _AKS-WS-VM_ Azure VM. |
| _C:\Temp\LogonScript.log_ | Output of _LogonScript.ps1_ which creates the AKS cluster, onboard it with Azure Arc creating the needed extensions as well as onboard the Azure VM. |
|

![Screenshot showing the Temp folder with deployment logs](./21.png)

## Cleanup

- If you want to delete the entire environment, simply delete the deployment resource group from the Azure portal.

    ![Screenshot showing Azure resource group deletion](./22.png)
