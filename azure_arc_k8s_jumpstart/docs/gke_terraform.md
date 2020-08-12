# Overview

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a Google Cloud Platform [Kubernetes Engine cluster](https://cloud.google.com/kubernetes-engine) and connected it as an Azure Arc cluster resource.

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Create a free Google Cloud account](https://cloud.google.com/free)

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

* Enable subscription for two providers for Azure Arc enabled Kubernetes<br> 
  Registration is an asynchronous process, and registration may take approximately 10 minutes.
  ```bash
  az provider register --namespace Microsoft.Kubernetes
  Registering is still on-going. You can monitor using 'az provider show -n Microsoft.Kubernetes'

  az provider register --namespace Microsoft.KubernetesConfiguration
  Registering is still on-going. You can monitor using 'az provider show -n Microsoft.KubernetesConfiguration'
  ```
  You can monitor the registration process with the following commands:
  ```bash
  az provider show -n Microsoft.Kubernetes -o table
 
  az provider show -n Microsoft.KubernetesConfiguration -o table
  ```

## Create a new GCP Project

* Browse to https://console.cloud.google.com/ and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different then the project name.

![](../img/gke_terraform/01.png)

![](../img/gke_terraform/02.png)

![](../img/gke_terraform/03.png)

* Enable the Compute Engine API for the project, create a project Owner service account credentials and download the private key JSON file and copy the file to the directory where Terraform files are located. Change the JSON file name (for example *account.json*). The Terraform plan will be using the credentials stored in this file to authenticate against your GCP project.   

![](../img/gke_terraform/04.png)

![](../img/gke_terraform/05.png)

![](../img/gke_terraform/06.png)

![](../img/gke_terraform/07.png)

![](../img/gke_terraform/08.png)

![](../img/gke_terraform/09.png)

![](../img/gke_terraform/10.png)

![](../img/gke_terraform/11.png)

![](../img/gke_terraform/12.png)

![](../img/gke_terraform/13.png)

![](../img/gke_terraform/14.png)

![](../img/gke_terraform/15.png)

* Enable the Compute Engine API for the project

![](../img/gke_terraform/16.png)

![](../img/gke_terraform/17.png)

# Deployment

The only thing you need to do before executing the Terraform plan is to export the environment variables which will be used by the plan. This is based on the Azure Service Principle you've just created and your subscription.  

* Export the environment variables needed for the Terraform plan.

  ```bash
    export TF_VAR_gcp_project_id=<Your GCP Project ID   
    export TF_VAR_gcp_credentials_filename=<Location on the Keys JSON file   
    export TF_VAR_gcp_region=<GCP Region to deploy resources   
    export TF_VAR_gke_cluster_name=<GKE cluster name>
    export TF_VAR_admin_username=<GKE cluster admin username>
    export TF_VAR_admin_password=<GKE cluster admin password>
    export TF_VAR_gke_cluster_node_count<GKE cluster node count>
  ```  

    For example:

  ```bash
    export TF_VAR_gcp_project_id=azure-arc-demo-273150   
    export TF_VAR_gcp_credentials_filename=account.json   
    export TF_VAR_gcp_region=us-west1
    export TF_VAR_gke_cluster_name=arc-gke-demo
    export TF_VAR_admin_username=arcdemo
    export TF_VAR_admin_password='arcdemo1234567!!'
    export TF_VAR_gke_cluster_node_count=1
  ```    

* Run the ```terraform init``` command which will download the Terraform Google provider.

![](../img/gke_terraform/18.png)

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Once done, you will have a ready GKE cluster under the *Kubernetes Engine* page in your GCP console.

![](../img/gke_terraform/19.png)

![](../img/gke_terraform/20.png)

![](../img/gke_terraform/21.png)

# Connecting to Azure Arc

* Now that you have a running GKE cluster, retrieve your Azure Subscription ID using the ```az account list``` command and edit the environment variables section in the included [az_connect_gke](../gke/terraform/scripts/az_connect_gke.sh) shell script.

![](../img/gke_terraform/22.png)

* Open a new Cloud Shell session which will pre-authenticated against your GKE cluster. 

![](../img/gke_terraform/23.png)

![](../img/gke_terraform/24.png)

![](../img/gke_terraform/25.png)

* Upload the *az_connect_gke* shell script and run it using the ```. ./az_connect_gke.sh``` command. 

**Note**: The extra dot is due to the script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands. 

![](../img/gke_terraform/26.png)

![](../img/gke_terraform/27.png)

![](../img/gke_terraform/28.png)

* Upon completion, you will have your GKE cluster connect as a new Azure Arc Kubernetes cluster resource in a new Resource Group.

![](../img/gke_terraform/29.png)

![](../img/gke_terraform/30.png)

![](../img/gke_terraform/31.png)

# Delete the deployment

In Azure, the most straightforward way is to delete the cluster or the Resource Group via the Azure Portal.

![](../img/gke_terraform/32.png)

![](../img/gke_terraform/33.png)

On your GCP console, select the cluster and delete it or alternatively, you can use the ```terraform destroy --auto-approve``` command.

![](../img/gke_terraform/34.png)

![](../img/gke_terraform/35.png)
