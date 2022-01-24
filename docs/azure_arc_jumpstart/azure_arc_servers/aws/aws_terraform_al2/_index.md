---
type: docs
title: "Amazon Linux 2 EC2 instance"
linkTitle: "Amazon Linux 2 EC2 instance"
weight: 2
description: >
---

## Deploy an AWS Amazon Linux 2 EC2 instance and connect it to Azure Arc using a Terraform plan

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an AWS Amazon Linux 2 EC2 instance and connect it as an Azure Arc-enabled server resource.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Generate SSH Key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) (or use existing ssh key)

* [Create free AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* Create Azure service principal (SP)

    To connect the AWS virtual machine to Azure Arc, an Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following commands:

    ```shell
    az login
    az ad sp create-for-rbac -n "http://AzureArcAWS" --role contributor
    ```

    Output should look similar to this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcAWS",
    "name": "http://AzureArcAWS",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)**

* Azure Arc-enabled servers depends on the following Azure resource providers in your subscription in order to use this service. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  * Microsoft.HybridCompute
  * Microsoft.GuestConfiguration

      ```shell
      az provider register --namespace 'Microsoft.HybridCompute'
      az provider register --namespace 'Microsoft.GuestConfiguration'
      ```

      You can monitor the registration process with the following commands:

      ```shell
      az provider show --namespace 'Microsoft.HybridCompute'
      az provider show --namespace 'Microsoft.GuestConfiguration'
      ```

## Create an AWS identity

In order for Terraform to create resources in AWS, we will need to create a new AWS IAM role with appropriate permissions and configure Terraform to use it.

* Login to the [AWS management console](https://console.aws.amazon.com)

* After logging in, click the "Services" dropdown in the top left. Under "Security, Identity, and Compliance" select "IAM" to access the [Identity and Access Management page](https://console.aws.amazon.com/iam/home)

    ![Screenshot of AWS cloud console](./01.png)

    ![Screenshot of IAM AWS cloud console](./02.png)

* Click on "Users" from the left menu and then click on "Add user" to create a new IAM user.

    ![Screenshot of new user creation in AWS cloud console](./03.png)

* On the "Add User" screen, name the user "terraform" and select the "Programmatic Access" checkbox then click "Next"

    ![Screenshot of new user creation in AWS cloud console](./04.png)

* On the next "Set Permissions" screen, select "Attach existing policies directly" and then check the box next to AmazonEC2FullAccess as seen in the screenshot then click "Next"

    ![Screenshot showing new user in AWS cloud console](./05.png)

* On the tags screen, assign a tag with a key of "azure-arc-demo" and click "Next" to proceed to the Review screen.

    ![Screenshot showing tags in AWS cloud console](./06.png)

* Double check that everything looks correct and click "Create user" when ready.

    ![Screenshot showing creating a user in AWS cloud console](./07.png)

* After the user is created, you will see the user's Access key ID and Secret access key. Copy these values down before clicking the Close button. In the screen below, you can see an example of what this should look like. Once you have these keys, you will be able to use them with Terraform to create AWS resources.

    ![Screenshot showing created user in AWS cloud console](./08.png)

## Configure Terraform

Before executing the Terraform plan, you must export the environment variables which will be used by the plan. These variables are based on your Azure subscription and tenant, the Azure service principal, and the AWS IAM user and keys you just created.

* Retrieve your Azure subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and AWS. It then executes a script on an AWS EC2 virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your AWS and Azure environments. Edit [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/aws/AL2/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.

  * TF_VAR_subscription_id=Your Azure subscription ID
  * TF_VAR_client_id=Your Azure service principal app id
  * TF_VAR_client_secret=Your Azure service principal password
  * TF_VAR_tenant_id=Your Azure tenant ID
  * AWS_ACCESS_KEY_ID=AWS access key
  * AWS_SECRET_ACCESS_KEY=AWS secret key

* From CLI, navigate to the *azure_arc_servers_jumpstart/aws/al2/terraform* directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/aws/AL2/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly. Note that this script will also be automatically executed remotely on the AWS virtual machine as part of the Terraform deployment.

    ```shell
    source ./scripts/vars.sh
    ```

* Make sure your SSH keys are available in *~/.ssh* and named *id_rsa.pub* and *id_rsa*. If you followed the ssh-keygen guide above to create your key then this should already be setup correctly. If not, you may need to modify [*main.tf*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/aws/AL2/terraform/main.tf) to use a key with a different path.

* Run the ```terraform init``` command which will download the Terraform AzureRM provider.

    ![Screenshot showing terraform init being run](./09.png)

## Deployment

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Upon completion, you will have an AWS Amazon Linux 2 EC2 instance deployed and connected as a new Azure Arc-enabled server inside a new resource group.

* Open the Azure portal and navigate to the resource group "Arc-Servers-Demo". The virtual machine created in AWS will be visible as a resource.

    ![Screenshot showing Azure Portal and Azure Arc-enabled server](./10.png)

## Semi-Automated Deployment (Optional)

As you may have noticed, the last step of the run is to register the VM as a new Azure Arc-enabled server resource.
    ![Screenshot showing azcmagent connect script](./11.png)

If you want to demo/control the actual registration process, do the following:

* In the [*install_arc_agent.sh.tmpl*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/aws/AL2/terraform/scripts/install_arc_agent.sh.tmpl) script template, comment out the "Run connect command" section and save the file.

    ![Screenshot showing azcmagent connect script commented out](./12.png)

* Get the public IP of the AWS VM by running ```terraform output```

    ![Screenshot showing terraform output](./13.png)

* SSH the VM using the ```ssh ec2-user@x.x.x.x``` where x.x.x.x is the host ip.

    ![Screenshot showing SSH into EC2 server](./14.png)

* Export all the environment variables in [*vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/aws/AL2/terraform/scripts/vars.sh)

    ![Screenshot showing export of environment variables in vars.sh](./15.png)

* Run the following command

    ```shell
    azcmagent connect --service-principal-id $TF_VAR_client_id --service-principal-secret $TF_VAR_client_secret --resource-group "Arc-Servers-Demo" --tenant-id $TF_VAR_tenant_id --location "westus2" --subscription-id $TF_VAR_subscription_id --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
    ```

    ![Screenshot showing azcmagent connect being run](./16.png)

* When complete, your VM will be registered with Azure Arc and visible in the resource group inside Azure Portal.

## Delete the deployment

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command as shown below.
    ![Screenshot showing terraform destroy being run](./17.png)

Alternatively, you can delete the AWS EC2 instance directly by terminating it from the [AWS Console](https://console.aws.amazon.com/ec2/v2/home).
    ![Screenshot showing AWS Console with terminating instance](./18.png)
