#  Onboard an Azure Linux Server VM with Azure Arc

The following README will guide you on how onboard a Azure Linux VM on to Azure Arc. An ARM template is provided for the creation of the Azure Resouces, along with an script that will allow you to onboard the Azure VM onto Azure Arc, this step is requiered as Azure VMs are already part of ARM, therefore, the Azure Arc agent cannot be installed following the regular onboarding method. 

   > [!NOTE]Please note that this scenario is only intended for demo purposes. 

# Azure Account  

* You will need an Azure Account with an active and valid subscription so you can deploy the Azure VMs and then register and onboard them with Azure Arc. If you do not have an account already, you can start with a free-trial account. 

* To create an Azure free account browse to [this link](https://azure.microsoft.com/en-us/free/) and select 'Start Free' to get access to a free trial subscription. 

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

# Automation Flow

Below you can find the automation flow for this scenario:

1. Edit the *azurevm_linux.parameters.json* file 

2. Upon execution of the *azurevm_linux.json* ARM template, an Azure VM will be created on your Azure Subscription

3. Connect to the VM and run the *allow_arc_agent.sh* Shell script on the guest OS to: 
    * Prepare the OS for the installation of the "Azure Arc Connected Machine Agent".
    * Install and configure the "Azure Arc Connected Machine Agent". 

# Deployment

* Create a new Azure Resource Group where you want your machine(s) to be deployed and then be registered as Azure Arc enabled Servers. 

    ```terminal
    az group create --name <Name of the Azure Resource Group> --location <Azure Region>
    ```

![](../img/azure_linux/01.png)

* Before executing the ARM template, you must set the parameters that match your environment. Edit the *azurevm_linux.parameters.json* file and provide: 
    - **adminUsername:** a username for Admin access to the Linux OS
    - **adminPublicKey:** the public key for SSH access
    - **dnsLabelPrefix:** a DNS prefix for the VM 
    - **vmName:** a custom name for the Azure VM

* To deploy the ARM template, navigate to the local cloned deployment folder and run the below command:

    ```console
    az deployment group create --resource-group <Name of the Azure Resource Group> --name <The name of this deployment> --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_servers_jumpstart/azure/arm_template/azurevm_linux.json --parameters <The *azurevm_linux.parameters.json* parameters file location>
    ```

* Once Azure resources have been provisioned, you will be able to see it in Azure portal. 

# Azure Arc Agent Installation 

* SSH onto the recently created machine. 

![](../img/azure_linux/02.png)

* Provide your environment variables and run the script *allow_arc_agent.sh*. Make sure the script has execution permissions by running: 

    ```console
    sudo chmod +x allow_arc_agent.sh
    sudo ./allow_arc_agent.sh
    ```
   > [!NOTE] the script is prepared to run on Ubuntu VMs, if you are using other Linux distros you will need to customize it. 

![](../img/azure_linux/03.png)

* Upon completion, you will have your Linux server, connected as a new Azure Arc resource inside your Resource Group.

![](../img/azure_linux/04.png)


# Clean up environment

Complete the following steps to clean up your environment.

* Remove the resource group that holds all the resources for this scenario. 

![](../img/azure_linux/05.png)