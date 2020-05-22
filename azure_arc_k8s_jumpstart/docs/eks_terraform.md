# Overview

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an Amazon Web Services (AWS) [Kubernetes Engine cluster](https://aws.amazon.com/eks/) and connected it as an Azure Arc cluster resource.

# Prerequisites

### Install AWS CLI
  * **[MAC]** Use the package manager ```homebrew``` to install the AWS CLI.
  ```bash
  $ brew install awscli
  ```
  * **[PC]** Use the package manager ```Chocolatey``` to install the AWS CLI.
  ```powershell
  $ choco install awscli
  ```

### Install **wget** package (required for the eks module)
  * **[MAC]** Use the package manager ```homebrew``` to install the AWS CLI.
  ```bash
  $ brew install wget
  ```
  * **[PC]** Use the package manager ```Chocolatey``` to install the AWS CLI.
  ```powershell
  $ choco install wget
  ```

### Install AWS IAM Authenticator
  * **[MAC]** Use the package manager ```homebrew``` to install the AWS CLI.
  ```bash
  $ brew install aws-iam-authenticator
  ```
  * **[PC]** Use the package manager ```Chocolatey``` to install the AWS CLI.
  ```powershell
  $ choco install aws-iam-authenticator
  ```

### [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). 
* Azure CLI should be running version 2.6.0 or later. Use ```az --version``` to check your current installed version.
### [Create a free Amazon Web Service's account](https://aws.amazon.com/free/)

### [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

### Create Azure Service Principal (SP)   

    To connect the EKS cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

    ```az login```

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

### Create AWS User IAM Key

An access key grants programmatic access to your resources. To create an AWS Access Key for a user:
  1. Navigate to the [IAM Access page](https://console.aws.amazon.com/iam/home#/home). 
    ![](../img/eks_terraform/image0.png)
  2. Select the **Users** from the side menue. 
    ![](../img/eks_terraform/image1.png)
  3. Select the **User** you want to create the access key for. 
   ![](../img/eks_terraform/image2.png)
  4. Select ***Security credentials** of the **User** selected. 
   ![](../img/eks_terraform/image3.png)
  5. Under **Access Keys** select **Create Access Keys**, this will download the
  ![](../img/eks_terraform/image4.png)
  6. In the popup window it will show you the ***Access key ID*** and ***Secret access key***. Save both of these values to configure **AWS CLI** later
  ![](../img/eks_terraform/image5.png)

### Configure AWS CLI using ***Access Key***
To configure **AWS CLI** run ```aws configure``` and when prompted, enter your ***AWS Access Key ID***, ***Secret Access Key***, ***region*** and output format (type ***json***).
```bash
$ aws configure
AWS Access Key ID [None]: YOUR_AWS_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_AWS_SECRET_ACCESS_KEY
Default region name [None]: YOUR_AWS_REGION
Default output format [None]: json
```

# Deployment

### Clone the repo
```bash
git clone https://github.com/alihhussain/azure_arc
``` 
Navigate to the folder that has **EKS** terraform binaries.
```bash
cd azure_arc_k8s_jumpstart/eks/terraform
```

### Initialize Terraform
Run the ```terraform init``` command which will initialize Terraform, creating the state file to track our work:
![](../img/eks_terraform/image6.png)

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. 


Once done, you will have a ready GKE cluster under the *Kubernetes Engine* page in your GCP console.

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