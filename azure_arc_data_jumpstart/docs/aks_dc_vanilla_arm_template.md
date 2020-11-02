# Azure Arc Data Controller Vanilla Deployment on AKS (ARM Template)

> [!NOTE] Currently, Azure Arc enabled data services is in Preview.

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using Azure Arc Data Services and deploy Azure data services on [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) cluster, using [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview).

By the end of this guide, you will have an AKS cluster deployed with an Azure Arc Data Controller and a Microsoft Windows Server 2019 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

## Prerequisites

* Clone this repo

```console
git clone https://github.com/microsoft/azure_arc.git
```

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure Service Principal (SP)

    In order for you to deploy the AKS cluster using the ARM template, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```console
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```console
    az ad sp create-for-rbac -n "http://AzureArcData" --role contributor
    ```

    Output should look like this:

    ```console
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcData",
    "name": "http://AzureArcData",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

> [!Note] It is optional, but highly recommended, to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest).

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

* User is editing the ARM template parameters file (1-time edit). These params values are being used throughout the deployment.

* Main ARM template will deploy AKS.

* Once AKS deployment has finished, the main ARM template will call a secondary ARM template which is depended on a successful AKS deployment.

* Secondary ARM template will deploy a client Windows Server 2019 VM.

* As part of the Windows Server 2019 VM deployment, there are 2 scripts executions; First script (ClientTools.ps1) at deployment runtime using the ARM *"CustomScriptExtension"* module and a second script (LogonScript.ps1) on user first logon to Windows.

  * Runtime script will:
    * Inject user params values (from bullet point #1) to be used in both runtime and logon script
    * Install the required tools – az cli, az cli Powershell module, kube-cli (Chocolaty packages)
    * Download & install the Azure Data Studio & azdata cli
    * Download the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
    * Download the *DC_Cleanup* and *DC_Deploy* Powershell scripts
    * Create the logon script
    * Create the Windows schedule task to run the logon script at first login
    * Disable Windows Server Manager from running at login

  * Logon script will:
    * Create the *LogonScript.log* file
    * Retrieve the AKS credentials & create the *kubeconfig* file in user Windows profile
    * Create the *azdata* config file in user Windows profile
    * Install the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
    * Create the Azure Data Studio desktop shortcut
    * Open another Powershell session which will execute the ```kubectl get pods -n <Arc Data Controller namespace> -w``` command
    * Deploy the Arc Data Controller using the user params values
    * Unregister the logon script Windows schedule task so it will not run after first login

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single template, responsible on deploying AKS. Once AKS deployment has finished, the template will then automatically execute another template which will deploy the Windows Server Azure VM followed by the Azure Arc Data Controller deployment on the AKS cluster.

* Before deploying the ARM template, login to Azure using AZ CLI with the ```az login``` command. To determine which AKS Kubernetes versions are available in your region use the below Azure CLI command.

    ```console
    az aks get-versions -l "<Your Azure Region>"
    ```

* The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](../aks/arm_template/dc_vanilla/azuredeploy.parameters.json) file located in your local cloned repository folder. An example parameters file is located [here](../aks/arm_template/dc_vanilla/azuredeploy.parameters.example.json).

  * *clusterName* - AKS cluster name
  * *dnsPrefix* - AKS unique DNS prefix
  * *nodeAdminUsername* - AKS Node Username
  * *sshRSAPublicKey* - Your ssh public key
  * *servicePrincipalClientId* - Your Azure Service Principal name
  * *servicePrincipalClientSecret* - Your Azure Service Principal password
  * *kubernetesVersion* - AKS Kubernetes Version (See previous prerequisite)
  * *adminUsername* - Client Windows VM admin username
  * *adminPassword* - Client Windows VM admin password
  * *vmSize* - Client Windows VM size
  * *tenantId* - Azure tenant ID
  * *resourceGroup* - Azure Resource Group where all the resources get deploy
  * *AZDATA_USERNAME* - Azure Arc Data Controller admin username
  * *AZDATA_PASSWORD* - Azure Arc Data Controller admin password (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols.)
  * *ACCEPT_EULA* - "yes" **Do not change**
  * *ARC_DC_NAME* - Azure Arc Data Controller name. The name must consist of lowercase alphanumeric characters or '-', and must start and end with an alphanumeric character. This name will be used for k8s namespace as well.
  * *ARC_DC_SUBSCRIPTION* - Azure Arc Data Controller Azure subscription ID
  * *ARC_DC_REGION* - Azure location where the Azure Arc Data Controller resource will be created in Azure (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)

* To deploy the ARM template, navigate to the local cloned [deployment folder](../aks/arm_template/dc_vanilla) and run the below command:

    ```console
    az group create --name <Name of the Azure Resource Group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure Resource Group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > [!NOTE] Make sure that you are using the same Azure Resource Group name as the one you've just used in the *azuredeploy.parameters.json* file

    For example:

    ```console
    az group create --name Arc-Data-Vanilla-Demo --location "East US"
    az deployment group create \
    --resource-group Arc-Data-Vanilla-Demo \
    --name arcdatademo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

> [!NOTE] Deployment time of the Azure Resource (AKS + Windows VM) can take ~20-30min

* Once Azure resources has been provisioned, you will be able to see it in Azure portal.

    ![](../img/aks_dc_vanilla_arm_template/01.png)

    ![](../img/aks_dc_vanilla_arm_template/02.png)

## Windows Login & Post Deployment

Now that both the AKS cluster and the Windows Server VM are created, it is time to login to the Client VM.

* Using it's public IP, RDP to the **Client VM**

    ![](../img/aks_dc_vanilla_arm_template/03.png)

* At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process.

    Let the script to run its course and **do not close** the Powershell session, this will be done for you once completed. You will notice that the Azure Arc Data Controller gets deployed on the AKS cluster. **The logon script run time is approximately 10min long**.  

    Once the script will finish it's run, the logon script Powershell session will be closed and the Azure Arc Data Controller will be deployed on the AKS cluster and be ready to use.

    ![](../img/aks_dc_vanilla_arm_template/04.png)

    ![](../img/aks_dc_vanilla_arm_template/05.png)

    ![](../img/aks_dc_vanilla_arm_template/06.png)

* Using Powershell, login to the Data Controller and check it's health using the below commands.

    ```powershell
    azdata login --namespace $env:ARC_DC_NAME
    azdata arc dc status show
    ```

    ![](../img/aks_dc_vanilla_arm_template/07.png)

* Another tool automatically deployed is Azure Data Studio along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions.

    ![](../img/aks_dc_vanilla_arm_template/08.png)

    ![](../img/aks_dc_vanilla_arm_template/09.png)

## Cleanup

* To delete the Azure Arc Data Controller and all of it's Kubernetes resources, run the *DC_Cleanup.ps1* Powershell script located in *C:\tmp* on the Windows Client VM. At the end of it's run, the script will close all Powershell sessions. **The Cleanup script run time is approximately 5min long**.

    ![](../img/aks_dc_vanilla_arm_template/10.png)

    ![](../img/aks_dc_vanilla_arm_template/11.png)

* If you want to delete the entire environment, simply delete the deployment Resource Group from the Azure portal.

    ![](../img/aks_dc_vanilla_arm_template/12.png)

## Re-Deploy Azure Arc Data Controller

In case you deleted the Azure Arc Data Controller from the AKS cluster, you can re-deploy it by running the *DC_Deploy.ps1* Powershell script located in *C:\tmp* on the Windows Client VM. **The Deploy script run time is approximately 5-10min long**

![](../img/aks_dc_vanilla_arm_template/13.png)

![](../img/aks_dc_vanilla_arm_template/14.png)
