# Azure Arc Data Controller Vanilla Deployment on GKE (Terraform)

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using Azure Arc Data Services and deploy Azure data services on a [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine) cluster, using [Terraform](https://www.terraform.io/).

By the end of this guide, you will have a GKE cluster deployed with an Azure Arc Data Controller and a Microsoft Windows Server 2019 (Datacenter) GKE compute instance VM, installed & pre-configured with all the required tools needed to work with Azure Arc Data Services.

## Deployment Process Overview

- Create a Google Cloud Platform (GCP) project, IAM Role & Service Account
- Download credentials file
- Clone this repository
- Edit *TF_VAR* variables values
- *terraform init*
- *terraform apply*
- *terraform destroy*

## Prerequisites

- Clone this repo

  ```console
  git clone https://github.com/microsoft/azure_arc.git
  ```

- [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

- [Create a free Google Cloud account](https://cloud.google.com/free) if you don't have one already.

- [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

- Create Azure Service Principal (SP)

To connect a Kubernetes cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure CloudShell](https://shell.azure.com/))

```console
az login
az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
```

For example:

```console
az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor
```

Output should look like this:

```console
{
"appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"displayName": "AzureArcK8s",
"name": "http://AzureArcK8s",
"password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```

> [!NOTE] It is optional, but highly recommended, to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest).

- Create a new GCP Project, IAM Role & Service Account

In order to deploy resources in GCP, we will create a new GCP Project as well as a service account to allow Terraform to authenticate against GCP APIs and run the plan to deploy resources.

- Browse to https://console.cloud.google.com/ and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different then the project name.

  ![](../img/gke_dc_vanilla_terraform/01.png)
  ![](../img/gke_dc_vanilla_terraform/02.png)
  ![](../img/gke_dc_vanilla_terraform/03.png)

- Enable the Compute Engine API for the project, create a project Owner service account credentials and download the private key JSON file and copy the file to the directory where Terraform files are located. Change the JSON file name (for example *account.json*). The Terraform plan will be using the credentials stored in this file to authenticate against your GCP project.

  ![](../img/gke_dc_vanilla_terraform/04.png)
  ![](../img/gke_dc_vanilla_terraform/05.png)
  ![](../img/gke_dc_vanilla_terraform/06.png)
  ![](../img/gke_dc_vanilla_terraform/07.png)
  ![](../img/gke_dc_vanilla_terraform/08.png)
  ![](../img/gke_dc_vanilla_terraform/09.png)
  ![](../img/gke_dc_vanilla_terraform/10.png)
  ![](../img/gke_dc_vanilla_terraform/11.png)
  ![](../img/gke_dc_vanilla_terraform/12.png)
  ![](../img/gke_dc_vanilla_terraform/13.png)
  ![](../img/gke_dc_vanilla_terraform/14.png)
  ![](../img/gke_dc_vanilla_terraform/15.png)
  ![](../img/gke_dc_vanilla_terraform/16.png)

- Enable the Compute Engine API for the project

  ![](../img/gke_dc_vanilla_terraform/17.png)
  ![](../img/gke_dc_vanilla_terraform/18.png)

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

- User is editing and exporting Terraform runtime environment variables, AKA *TF_VAR* (1-time edit). The variables values are being used throughout the deployment.

- User deploys the Terraform plan which will deploy the GKE cluster and the GCP compute instance VM as well as an Azure Resource Group. The Azure Resource Group is required to host the Azure Arc services you will be able to deploy such as Azure SQL Managed Instance and PostgresSQL Hyperscale.

- In addition, the plan will copy the *faster_sc.yaml* file which will be used to create a Kubernetes Storage Class that will get leveraged by Arc Data Controller to create [persistent volume claims (PVC)](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

- As part of the Windows Server 2019 VM deployment, there are 4 scripts executions:

  1. *azure_arc.ps1* script will be created automatically as part of the Terraform plan runtime and is responsible on injecting the *TF_VAR* variables values on to the Windows instance which will then be used in both the *ClientTools* and the *LogonScript* scripts.

  2. *password_reset.ps1* script will be created automatically as part of the Terraform plan runtime and is responsible on creating the Windows username & password.

  3. *ClientTools.ps1* script will run at the Terraform plan runtime Runtime and will:
      - Create the *ClientTools.log* file  
      - Install the required tools – az cli, az cli Powershell module, kubernetes-cli (Chocolaty packages)
      - Download & install the Azure Data Studio & azdata cli
      - Download the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
      - Apply the *faster_sc.yaml* file on the GKE cluster
      - Create the *azdata* config file in user Windows profile
      - Install the Azure Data Studio Azure Data CLI, Azure Arc & PostgreSQL extensions
      - Create the Azure Data Studio desktop shortcut
      - Download the *DC_Cleanup* and *DC_Deploy* Powershell scripts
      - Disable Windows Server Manager
      - Create the logon script
      - Create the Windows schedule task to run the logon script at first login

  4. *LogonScript.ps1* script will run on user first logon to Windows and will:
      - Create the *LogonScript.log* file
      - Open another Powershell session which will execute a command to watch the deployed Azure Arc Data Controller Kubernetes pods
      - Create Arc Data Controller config file (*control.json*) to setup the use of the Storage Class and Kubernetes LoadBalancer service
      - Deploy the Arc Data Controller using the *TF_VAR* variables values
      - Unregister the logon script Windows schedule task so it will not run after first login

## Deployment

As mentioned, the Terraform plan will deploy a GKE cluster and a Windows Server 2019 Client GCP compute instance.

- Before running the Terraform plan, edit the below *TF_VAR* values and export it (simply copy/paste it after you finished edit these). An example *TF_VAR* shell script file is located [here](../gke/terraform/example/TF_VAR_example.sh)

  ![](../img/gke_dc_vanilla_terraform/19.png)

  - *export TF_VAR_gcp_project_id*='Your GCP Project ID (Created in the prerequisites section)'
  - *export TF_VAR_gcp_credentials_filename*='Your GCP Credentials JSON filename (Created in the prerequisites section)'
  - *export TF_VAR_gcp_region*='GCP region where resource will be created'
  - *export TF_VAR_gcp_zone*='GCP zone where resource will be created'
  - *export TF_VAR_gke_cluster_name*='GKE cluster name'
  - *export TF_VAR_admin_username*='GKE cluster administrator username'
  - *export TF_VAR_admin_password*='GKE cluster administrator password'
  - *export TF_VAR_gke_cluster_node_count*='GKE cluster number of worker nodes'
  - *export TF_VAR_windows_username*='Windows Server Client compute instance VM administrator username'
  - *export TF_VAR_windows_password*='Windows Server Client compute instance VM administrator password' (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols as well as **not containing** the user's account name or parts of the user's full name that exceed two consecutive characters)
  - *export TF_VAR_client_id*='Your Azure Service Principal name'
  - *export TF_VAR_client_secret*='Your Azure Service Principal password'
  - *export TF_VAR_tenant_id*='Your Azure tenant ID'
  - *export TF_VAR_AZDATA_USERNAME*='Azure Arc Data Controller admin username'
  - *export TF_VAR_AZDATA_PASSWORD*='Azure Arc Data Controller admin password' (The password must be at least 8 characters long and contain characters from three of the following four sets: uppercase letters, lowercase letters, numbers, and symbols)
  - *export TF_VAR_ARC_DC_NAME*='Azure Arc Data Controller name' (The name must consist of lowercase alphanumeric characters or '-', and must start and end with a alphanumeric character. This name will be used for k8s namespace as well)
  - *export TF_VAR_ARC_DC_SUBSCRIPTION*='Azure Arc Data Controller Azure subscription ID'
  - *export TF_VAR_ARC_DC_RG*='Azure Resource Group where all future Azure Arc resources will be deployed'
  - *export TF_VAR_ARC_DC_REGION*='Azure location where the Azure Arc Data Controller resource will be created in Azure' (Currently, supported regions supported are eastus, eastus2, centralus, westus2, westeurope, southeastasia)

- Navigate to the folder that has Terraform binaries.

  ```console
  cd azure_arc_data_jumpstart/gke/terraform
  ```

- Run the ```terraform init``` command which is used to initialize a working directory containing Terraform configuration files and load the required Terraform providers.

  ![](../img/gke_dc_vanilla_terraform/20.png)

- (Optional but recommended) Run the ```terraform plan``` command to make sure everything is configured properly.

  ![](../img/gke_dc_vanilla_terraform/21.png)

- Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. **Runtime for deploying all the GCP resources for this plan is ~20-30min.**

- Once completed, you can review the GKE cluster and the worker nodes resources as well as the GCP compute instance VM created.

  ![](../img/gke_dc_vanilla_terraform/22.png)
  ![](../img/gke_dc_vanilla_terraform/23.png)
  ![](../img/gke_dc_vanilla_terraform/24.png)
  ![](../img/gke_dc_vanilla_terraform/25.png)
  ![](../img/gke_dc_vanilla_terraform/26.png)

- In the Azure Portal, a new empty Azure Resource Group was created. As mentioned, this Resource Group will be used for Azure Arc Data Service you will be deploying in the future.

  ![](../img/gke_dc_vanilla_terraform/27.png)

## Windows Login & Post Deployment

Now that we have both the GKE cluster and the Windows Server Client instance created, it is time to login to the Client VM.

- Select the Windows instance, click on the RDP dropdown and download the RDP file. Using your *windows_username* and *windows_password* credentials, log in to the VM. 

  ![](../img/gke_dc_vanilla_terraform/28.png)

  ![](../img/gke_dc_vanilla_terraform/29.png)

- At first login, as mentioned in the "Automation Flow" section, a logon script will get executed. This script was created as part of the automated deployment process. 

    Let the script to run it's course and **do not close** the Powershell session, this will be done for you once completed. You will notice that the Azure Arc Data Controller gets deployed on the GKE cluster. **The logon script run time is approximately 10min long**.

    Once the script will finish it's run, the logon script Powershell session will be close and the Azure Arc Data Controller will be deployed on the GKE cluster and be ready to use.

  ![](../img/gke_dc_vanilla_terraform/30.png)
  ![](../img/gke_dc_vanilla_terraform/31.png)
  ![](../img/gke_dc_vanilla_terraform/32.png)
  ![](../img/gke_dc_vanilla_terraform/33.png)

- Using Powershell, login to the Data Controller and check it's health using the below commands.

    ```powershell
    azdata login --namespace $env:ARC_DC_NAME
    azdata arc dc status show
    ```

  ![](../img/gke_dc_vanilla_terraform/34.png)

- Another tool automatically deployed is Azure Data Studio along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions.

  ![](../img/gke_dc_vanilla_terraform/35.png)
  ![](../img/gke_dc_vanilla_terraform/36.png) 

## Cleanup

- To delete the Azure Arc Data Controller and all of it's Kubernetes resources, run the *DC_Cleanup.ps1* Powershell script located in *C:\tmp* on the Windows Client instance. At the end of it's run, the script will close all Powershell sessions. **The Cleanup script run time is ~2-3min long**.

  ![](../img/gke_dc_vanilla_terraform/37.png)
  ![](../img/gke_dc_vanilla_terraform/38.png)

## Re-Deploy Azure Arc Data Controller

In case you deleted the Azure Arc Data Controller from the GKE cluster, you can re-deploy it by running the *DC_Deploy.ps1* Powershell script located in *C:\tmp* on the Windows Client instance. **The Deploy script run time is approximately ~3-4min long**.

  ![](../img/gke_dc_vanilla_terraform/39.png)

## Delete the deployment

To completely delete the environment, follow the below steps run the ```terraform destroy --auto-approve``` command which will delete all of the GCP resources as well as the Azure Resource Group. **The *terraform destroy* run time is approximately ~5-6min long**.

  ![](../img/gke_dc_vanilla_terraform/40.png)
