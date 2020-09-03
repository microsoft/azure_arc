# Azure Arc Data Controller Vanilla Deployment on Kubeadm Azure VM (ARM Template)

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using Azure Arc Data Services and deploy Azure data services on single-node Kubernetes cluster deployed with [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) in az Azure Ubuntu VM, using [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview). 

By the end of this guide, you will an Ubuntu VM deployed with an Azure Arc Data Controller and a Microsoft Windows Server 2019 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

# Prerequisites

* **Currently, Azure Arc Data Services is in Private Preview. In order for you to go trough this guide you are required to have your [Azure subscription whitelisted](https://azure.microsoft.com/en-us/services/azure-arc/hybrid-data-services/#faq). As part of you submitting a request to join, you will also get an invite to join the [Private Preview GitHub Repository](https://github.com/microsoft/Azure-data-services-on-Azure-Arc) which we will be using later on in this guide.**

    **If you already registered to Private Preview, you can skip this prerequisite.**

    ![](../img/kubeadm_dc_vanilla_arm_template/01.png)

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    In order for you to deploy the Azure resources using the ARM template, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

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

- Once Ubuntu VM deployment has finished, the main ARM template will call a secondary ARM template which is depended on a successful Ubuntu VM deployment.

- Secondary ARM template will deploy a client Windows Server 2019 VM.

- As part of the Windows Server 2019 VM deployment, there are 2 scripts executions; First script (ClientTools.ps1) at deployment runtime using the ARM *"CustomScriptExtention"* module and a second script (LogonScript.ps1) on user first logon to Windows.

    - Runtime script will:
        - Inject user params values (from bullet point #1) to be used in both runtime and logon script
        - Install the required tools – az cli, az cli Powershell module, kubernetes-cli and putty (Chocolaty packages)
        - Download & install the Azure Data Studio (Insiders) & azdata cli
        - Download the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
        - Create the logon script
        - Create the Windows schedule task to run the logon script at first login
        - Disable Windows Server Manager from running at login

    - Logon script will:
        - Create the *LogonScript.log* file
        - Connect to Azure using SPN credentials (from bullet point #1)
        - Copy the kubeconfig file from the Ubuntu (Kubeadm) VM to the local Windows user profile
        - Install the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
        - Create the Azure Data Studio desktop shortcut
        - Unregister the logon script Windows schedule task so it will not run after first login

# Deployment 

As mentioned, this deployment will leverage ARM templates. You will deploy a single template, responsible on deploying Ubuntu VM install with Kubernetes and the Data Controller. Once Ubuntu VM deployment has finished, the template will then automatically execute another template which will deploy the Windows Server Azure VM which will be automatically connected to the Kubernetes cluster.

* The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](../kubeadm/azure/arm_template/azuredeploy.parameters.json) file located in your local cloned repository folder. An example parameters file is located [here](../kubeadm/azure/arm_template/azuredeploy.parameters.example.json).

    - *K8svmName* - Kubeadm Ubuntu VM name

    - *vmName* - Client Windows VM name

    - *adminUsername* - Client Windows VM admin username

    - *adminPassword* - Client Windows VM admin password

    - *K8sVMSize* - Kubeadm Ubuntu VM size

    - *vmSize* - Client Windows VM size

    - *servicePrincipalClientId* - Your Azure Service Principle name

    - *servicePrincipalClientSecret* - Your Azure Service Principle password

    - *tenantId* - Azure tenant ID    

    - *AZDATA_USERNAME* - Azure Arc Data Controller admin username

    - *AZDATA_PASSWORD* - Azure Arc Data Controller admin password (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols.)

    - *ACCEPT_EULA* - "yes" **Do not change**

    - *DOCKER_USERNAME* - Azure Arc Data - Private Preview Container Registry username (See note below)

    - *DOCKER_PASSWORD* - Azure Arc Data - Private Preview Container Registry password (See note below)

    - *ARC_DC_NAME* - Azure Arc Data Controller name. The name must consist of lowercase alphanumeric characters or '-', and must start and end with a alphanumeric character (This name will be used for k8s namespace as well).

    - *ARC_DC_SUBSCRIPTION* - Azure Arc Data Controller Azure subscription ID

    - *ARC_DC_RG* - Azure Resource Group where all the resources get deploy

    - *ARC_DC_REGION* - Azure location where the Azure Arc Data Controller resource will be created in Azure (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)

    **Note: Currently, the DOCKER_USERNAME / DOCKER_PASSWORD values can only be found in the Azure Arc Data Services [Private Preview repository](https://github.com/microsoft/Azure-data-services-on-Azure-Arc/blob/master/scenarios/002-create-data-controller.md).**

 * To deploy the ARM template, navigate to the local cloned [deployment folder](../kubeadm/azure/arm_template) and run the below command:

    ```bash
    az group create --name <Name of the Azure Resource Group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure Resource Group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/kubeadm/azure/arm_template/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    **Note: Make sure that you are using the same Azure Resource Group name as the one you've just used in the *azuredeploy.parameters.json* file** 

    For example:

    ```bash
    az group create --name Arc-Data-Kubeadm-Demo --location "East US"
    az deployment group create \
    --resource-group Arc-Data-Kubeadm-Demo \
    --name arcdatakubeadmdemo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/kubeadm/azure/arm_template/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

    **Note: Deployment time of the Azure Resource (Ubuntu VM + Windows VM) can take ~15-20min long**

* Once Azure resources has been provisioned, you will be able to see it in Azure portal. 

    ![](../img/kubeadm_dc_vanilla_arm_template/02.png)

    ![](../img/kubeadm_dc_vanilla_arm_template/03.png)

# Windows Login & Post Deployment

Now that both the Ubuntu Kubernetes VM and the Windows Server client VM are created, it is time to login the Client VM. 

* Using it's public IP, RDP to the **Client VM**

    ![](../img/kubeadm_dc_vanilla_arm_template/04.png)

* At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process. 

    Let the script to run it's course and **do not close** the Powershell session, this will be done for you once completed. **The logon script run time is approximately 30s long**.  

    Once the script will finish it's run, the logon script Powershell session will be closed and the *kubeconfig* is copied to the *.kube* folder of the Windows user profile, the client VM will be ready to use.

    ![](../img/kubeadm_dc_vanilla_arm_template/05.png)

    ![](../img/kubeadm_dc_vanilla_arm_template/06.png)

    ![](../img/kubeadm_dc_vanilla_arm_template/07.png)    

* To start interacting with the Azure Arc Data Controller, Open PowerShell and use the log in command bellow.

    ```powershell
    azdata login --namespace $env:ARC_DC_NAME

    azdata arc dc status show
    ```

* Another tool automatically deployed is Azure Data Studio (Insiders Build) along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions.

    ![](../img/kubeadm_dc_vanilla_arm_template/08.png)

# Using the Ubuntu Kubernetes VM

Even though everything you need is installed in the Windows client VM, it is possible, if you prefer, to use *azdata* CLI from within the Ubuntu VM.

* SSH to the Ubuntu VM using it public IP.

    ![](../img/kubeadm_dc_vanilla_arm_template/09.png)

* To start interacting with the Azure Arc Data Controller, use the log in command bellow.

    ```bash
    azdata login --namespace $ARC_DC_NAME

    azdata arc dc status show
    ```

![](../img/kubeadm_dc_vanilla_arm_template/10.png)

# Cleanup

* To delete the entire environment, simply delete the deployment Resource Group from the Azure portal.

    ![](../img/kubeadm_dc_vanilla_arm_template/11.png)