# Azure Arc Data Controller Vanilla Deployment on Kubeadm Azure VM (ARM Template)

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using Azure Arc Data Services and deploy Azure data services on single-node Kubernetes cluster deployed with [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) in az Azure Ubuntu VM, using [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview). 

By the end of this guide, you will an Ubuntu VM deployed with an Azure Arc Data Controller and a Microsoft Windows Server 2019 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

# Prerequisites

* **Currently, Azure Arc Data Services is in Private Preview. In order for you to go trough this guide you are required to have your [Azure subscription whitelisted](https://azure.microsoft.com/en-us/services/azure-arc/hybrid-data-services/#faq). As part of you submitting a request to join, you will also get an invite to join the [Private Preview GitHub Repository](https://github.com/microsoft/Azure-data-services-on-Azure-Arc) which we will be using later on in this guide.**

    **If you already registered to Private Preview, you can skip this prerequisite.**

    ![](../img/aks_dc_vanilla_arm_template/01.png)

* Clone this repo

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure Service Principal (SP)   

    In order for you to deploy the AKS cluster using the ARM template, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcData" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcData",
    "name": "http://AzureArcData",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.
 
- User is editing the ARM template parameters file (1-time edit). These params values are being used throughout the deployment.

- Main ARM template will deploy an Ubuntu VM. The ARM template will call the the Azure [Linux Custom Script Extension](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux) to:

    - Deploy a single-node Kubernetes cluster using Kubeadm.
    - Deploy the Azure Arc Data Controller on that cluster.

- Once Ubuntu VM deployment has finished, the main ARM template will call a secondary ARM template which is depended on a successful AKS deployment.

- Secondary ARM template will deploy a client Windows Server 2019 VM.

- As part of the Windows Server 2019 VM deployment, there are 2 scripts executions; First script (ClientTools.ps1) at deployment runtime using the ARM *"CustomScriptExtention"* module and a second script (LogonScript.ps1) on user first logon to Windows.

    - Runtime script will:
        - Inject user params values (from bullet point #1) to be used in both runtime and logon script
        - Install the required tools – az cli, az cli Powershell module, kubernetes-cli and putty (Chocolaty packages)
        - Download & install the Azure Data Studio (Insiders) & azdata cli
        - Download the Azure Data Studio Arc & PostgreSQL extensions
        - Create the logon script
        - Create the Windows schedule task to run the logon script at first login
        - Disable Windows Server Manager from running at login

    - Logon script will:
        - Create the *LogonScript.log* file
        - Connect to Azure using SPN credentials (from bullet point #1)
        - Copy the kubeconfig file from the Ubuntu (Kubeadm) VM to the local Windows user profile
        - Install the Azure Data Studio Arc & PostgreSQL extensions
        - Create the Azure Data Studio desktop shortcut
        - Unregister the logon script Windows schedule task so it will not run after first login

