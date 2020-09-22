# Azure Arc Data Controller Vanilla Deployment on EKS (Terraform)

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using Azure Arc Data Services and deploy Azure data services on [Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/) cluster, using [Terraform](https://www.terraform.io/). 

By the end of this guide, you will have an EKS cluster deployed with an Azure Arc Data Controller and a Microsoft Windows Server 2019 (Datacenter) AWS EC2 instance VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

# Deployment TL;DR

  - Create AWS IAM Role
  - Create & download AWS Key Pair
  - Clone this repository
  - Edit *TF_VAR* variables values
  - *terraform init*
  - *terraform apply*
  - EKS cleanup
  - *terraform destroy*

# Prerequisites

* **Currently, Azure Arc Data Services is in Private Preview. In order for you to go trough this guide you are required to have your [Azure subscription whitelisted](https://azure.microsoft.com/en-us/services/azure-arc/hybrid-data-services/#faq). As part of you submitting a request to join, you will also get an invite to join the [Private Preview GitHub Repository](https://github.com/microsoft/Azure-data-services-on-Azure-Arc) which we will be using later on in this guide.**

    **If you already registered to Private Preview, you can skip this prerequisite.**

    ![](../img/eks_dc_vanilla_terraform/01.png)

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install AWS IAM Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Create a free Amazon Web Service's account](https://aws.amazon.com/free/)

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* Create Azure Service Principal (SP)

    To connect a Kubernetes cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcK8s",
    "name": "http://AzureArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

* Create AWS User IAM Key. An access key grants programmatic access to your resources which we will be using later on in this guide. 

  1. Navigate to the [IAM Access page](https://console.aws.amazon.com/iam/home#/home).

    ![](../img/eks_dc_vanilla_terraform/02.png)

  2. Select the **Users** from the side menu.

    ![](../img/eks_dc_vanilla_terraform/03.png)
    
  3. Select the **User** you want to create the access key for. 

   ![](../img/eks_dc_vanilla_terraform/04.png)

  4. Select ***Security credentials** of the **User** selected. 

   ![](../img/eks_dc_vanilla_terraform/05.png)

  5. Under **Access Keys** select **Create Access Keys**, this will download the

  ![](../img/eks_dc_vanilla_terraform/06.png)

  6. In the popup window it will show you the ***Access key ID*** and ***Secret access key***. Save both of these values to configure the **Terraform plan** variables later.

  ![](../img/eks_dc_vanilla_terraform/07.png)

* In order to open a RDP session to the Windows Client EC2 instance, an EC2 Key Pair is required. From the *Services* menu, click on *"EC2"*, enter the *Key Pairs* settings from the left sidebar (under the *Network & Security* section) and click on *"Create key pair"* (top-right corner) to create a new key pair.

  ![](../img/eks_dc_vanilla_terraform/08.png)

  ![](../img/eks_dc_vanilla_terraform/09.png)

  ![](../img/eks_dc_vanilla_terraform/10.png)

* Provide a meaningful name, for example *terraform*, and click on *"Create key pair"* which will then automatically download the created *pem* file.

  ![](../img/eks_dc_vanilla_terraform/11.png)

  ![](../img/eks_dc_vanilla_terraform/12.png)

  ![](../img/eks_dc_vanilla_terraform/13.png)  

* Copy the downloaded *pem* file to where the terraform binaries are located (in your cloned repository directory).

  ![](../img/eks_dc_vanilla_terraform/14.png)

# Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.
 
- User is editing and exporting Terraform runtime environment variables, AKA *TF_VAR* (1-time edit). The variables values are being used throughout the deployment.

- User deploys the Terraform plan which will deploy the EKS cluster and the EC2 Windows Client instance as well as an Azure Resource Group. The Azure Resource Group is required to host the Azure Arc services you will be able to deploy such as Azure SQL Managed Instance and PostgresSQL Hyperscale. 

- In addition, the plan will copy the EKS *kubeconfig* file as well as the *configmap.yml* file (which is responsible for having the EKS nodes communicate with the cluster control plane) on to the Windows instance.

- As part of the Windows Server 2019 VM deployment, there are 3 scripts executions:

  1. *azure_arc.ps1* script will be created automatically as part of the Terraform plan runtime and is responsible on injecting the *TF_VAR* variables values on to the Windows instance which will then be used in both the *ClientTools* and the *LogonScript* scripts.

  2. *ClientTools.ps1* script will run at the Terraform plan runtime Runtime and will:
      - Create the *ClientTools.log* file  
      - Install the required tools – az cli, az cli Powershell module, kubernetes-cli, aws-iam-authenticator (Chocolaty packages)
      - Download & install the Azure Data Studio (Insiders) & azdata cli
      - Download the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
      - Apply the *configmap.yml* file on the EKS cluster
      - Create the *azdata* config file in user Windows profile
      - Install the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
      - Create the Azure Data Studio desktop shortcut    
      - Download the *DC_Cleanup* and *DC_Deploy* Powershell scripts
      - Create the logon script
      - Create the Windows schedule task to run the logon script at first login

  3. *LogonScript.ps1* script will run on user first logon to Windows and will:
      - Create the *LogonScript.log* file
      - Open another Powershell session which will execute a command to watch the deployed Azure Arc Data Controller Kubernetes pods
      - Deploy the Arc Data Controller using the *TF_VAR* variables values
      - Unregister the logon script Windows schedule task so it will not run after first login

# Deployment

As mentioned, the Terraform plan will deploy an EKS cluster and an EC2 Windows Server 2019 Client instance.

* Before running the Terraform plan, edit the below *TF_VAR* values and export it (simply copy/paste it after you finished edit these). An example *TF_VAR* shell script file is located [here](../eks/terraform/example/TF_VAR_example.sh)

  ![](../img/eks_dc_vanilla_terraform/15.png)

  - *export TF_VAR_AWS_ACCESS_KEY_ID*='Your AWS Access Key ID (Created in the prerequisites section)'

  - *export TF_VAR_AWS_SECRET_ACCESS_KEY*='Your AWS Secret Key (Created in the prerequisites section)'

  - *export TF_VAR_key_name*='Your AWS Key Pair name (Created in the prerequisites section)'

  - *export TF_VAR_key_pair_filename*='Your AWS Key Pair *.pem filename (Created in the prerequisites section)'

  - *export TF_VAR_client_id*='Your Azure Service Principle name'

  - *export TF_VAR_client_secret*='Your Azure Service Principle password'

  - *export TF_VAR_tenant_id*='Your Azure tenant ID'

  - *export TF_VAR_AZDATA_USERNAME*='Azure Arc Data Controller admin username'

  - *export TF_VAR_AZDATA_PASSWORD*='Azure Arc Data Controller admin password' (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols)

  - *export TF_VAR_REGISTRY_USERNAME*='Azure Arc Data - Private Preview Container Registry username' (See note below)

  - *export TF_VAR_REGISTRY_PASSWORD*='Azure Arc Data - Private Preview Container Registry password' (See note below)

  - *export TF_VAR_ARC_DC_NAME*='Azure Arc Data Controller name' (The name must consist of lowercase alphanumeric characters or '-', and must start and end with a alphanumeric character. This name will be used for k8s namespace as well)

  - *export TF_VAR_ARC_DC_SUBSCRIPTION*='Azure Arc Data Controller Azure subscription ID'

  - *export TF_VAR_ARC_DC_RG*='Azure Resource Group where all future Azure Arc resources will be deployed'

  - *export TF_VAR_ARC_DC_REGION*='Azure location where the Azure Arc Data Controller resource will be created in Azure' (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)

  **Note: Currently, the REGISTRY_USERNAME / REGISTRY_PASSWORD values can only be found in the Azure Arc Data Services [Private Preview repository](https://github.com/microsoft/Azure-data-services-on-Azure-Arc/blob/master/scenarios/002-create-data-controller.md).**

* Navigate to the folder that has Terraform binaries.

  ```bash
  cd azure_arc_data_jumpstart/eks/terraform
  ```

* Run the ```terraform init``` command which is used to initialize a working directory containing Terraform configuration files and load the required Terraform providers.

  ![](../img/eks_dc_vanilla_terraform/16.png)

* (Optional but recommended) Run the ```terraform plan``` command to make sure everything is configured properly.

  ![](../img/eks_dc_vanilla_terraform/17.png)

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. **Runtime for deploying all the AWS resources for this plan is ~30min.**

* Once completed, the plan will output a decrypted password for your Windows Client instance. Before connecting to the Client instance, you can review the EKS cluster and the EC2 instances created. Notice how 3 instances were created; 2 EKS nodes and the Client instance.

  ![](../img/eks_dc_vanilla_terraform/18.png)

  ![](../img/eks_dc_vanilla_terraform/19.png)

  ![](../img/eks_dc_vanilla_terraform/20.png)

  ![](../img/eks_dc_vanilla_terraform/21.png)

  ![](../img/eks_dc_vanilla_terraform/22.png)

  ![](../img/eks_dc_vanilla_terraform/23.png)

* In the Azure Portal, a new empty Azure Resource Group was created. As mentioned, this Resource Group will be used for Azure Arc Data Service you will be deploying in the future.

  ![](../img/eks_dc_vanilla_terraform/24.png)

# Windows Login & Post Deployment

Now that we have both the EKS cluster and the Windows Server Client instance created, it is time to login to the Client VM.

* Select the Windows instance, click *"Connect"* and download the Remote Desktop file.

  ![](../img/eks_dc_vanilla_terraform/25.png)

  ![](../img/eks_dc_vanilla_terraform/26.png)

  ![](../img/eks_dc_vanilla_terraform/27.png)

* Using the decrypted password, RDP the Windows instance. In case you need to get the password later, use the ```terraform output``` command to re-present the plan output. 

* At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process. 

    Let the script to run it's course and **do not close** the Powershell session, this will be done for you once completed. You will notice that the Azure Arc Data Controller gets deployed on the EKS cluster. **The logon script run time is approximately 10min long**.

    Once the script will finish it's run, the logon script Powershell session will be close and the Azure Arc Data Controller will be deployed on the EKS cluster and be ready to use.

  ![](../img/eks_dc_vanilla_terraform/28.png)

  ![](../img/eks_dc_vanilla_terraform/29.png)

  ![](../img/eks_dc_vanilla_terraform/30.png)
   

* Using Powershell, login to the Data Controller and check it's health using the below commands.

    ```powershell
    azdata login --namespace $env:ARC_DC_NAME

    azdata arc dc status show
    ```

  ![](../img/eks_dc_vanilla_terraform/31.png)

* Another tool automatically deployed is Azure Data Studio (Insiders Build) along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions. 

  ![](../img/eks_dc_vanilla_terraform/32.png)

  ![](../img/eks_dc_vanilla_terraform/33.png)

# Cleanup

* To delete the Azure Arc Data Controller and all of it's Kubernetes resources, run the *DC_Cleanup.ps1* Powershell script located in *C:\tmp* on the Windows Client instance. At the end of it's run, the script will close all Powershell sessions. **The Cleanup script run time is ~2-3min long**.

  ![](../img/eks_dc_vanilla_terraform/34.png)

  ![](../img/eks_dc_vanilla_terraform/35.png)

# Re-Deploy Azure Arc Data Controller

In case you deleted the Azure Arc Data Controller from the EKS cluster, you can re-deploy it by running the *DC_Deploy.ps1* Powershell script located in *C:\tmp* on the Windows Client instance. **The Deploy script run time is approximately ~3-4min long** 

  ![](../img/eks_dc_vanilla_terraform/36.png)

  ![](../img/eks_dc_vanilla_terraform/37.png) 

# Delete the deployment

To completely delete the environment, follow the below steps:

  1. on the Windows Client instance, run the *DC_Cleanup.ps1* Powershell script.

  2. Run the ```terraform destroy --auto-approve``` which will delete all of the AWS resources as well as the Azure Resource Group. **The *terraform destroy* run time is approximately ~8-9min long** 

    ![](../img/eks_dc_vanilla_terraform/38.png)

    ![](../img/eks_dc_vanilla_terraform/39.png)

    ![](../img/eks_dc_vanilla_terraform/40.png)