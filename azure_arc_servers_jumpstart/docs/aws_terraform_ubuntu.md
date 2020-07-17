#  Onboard an AWS Ubuntu server with Azure Arc

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an AWS EC2 virtual machine and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Generate SSH Key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) (or use existing ssh key) 

* [Create free AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

## Create Azure Service Principal (SP)   

* To connect the AWS virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcAWS" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcAWS",
    "name": "http://AzureArcAWS",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Create an AWS identity

In order for Terraform to create resources in AWS, we will need to create a new AWS IAM role with appropriate permissions and configure Terraform to use it.

* Login to the [AWS management console](https://console.aws.amazon.com)

* After logging in, click the "Services" dropdown in the top left. Under "Security, Identity, and Compliance" select "IAM" to access the [Identity and Access Management page](https://console.aws.amazon.com/iam/home)

    ![](../img/aws_ubuntu/01.png) 

    ![](../img/aws_ubuntu/02.png)

* Click on "Users" from the left menu and then click on "Add user" to create a new IAM user.

    ![](../img/aws_ubuntu/03.png)

* On the "Add User" screen, name the user "terraform" and select the "Programmatic Access" checkbox then click "Next"

    ![](../img/aws_ubuntu/04.png)

* On the next "Set Permissions" screen, select "Attach existing policies directly" and then check the box next to AmazonEC2FullAccess as seen in the screenshot then click "Next"

    ![](../img/aws_ubuntu/05.png)

* On the tags screen, assign a tag with a key of "azure-arc-demo" and click "Next" to proceed to the Review screen.

    ![](../img/aws_ubuntu/06.png)

* Double check that everything looks correct and click "Create user" when ready.

    ![](../img/aws_ubuntu/07.png)

* After the user is created, you will see the user's Access key ID and Secret access key. Copy these values down before clicking the Close button. In the screen below, you can see an example of what this should look like. Once you have these keys, you will be able to use them with Terraform to create AWS resources.

    ![](../img/aws_ubuntu/08.png)

## Configure Terraform

Before executing the Terraform plan, you must export the environment variables which will be used by the plan. These variables are based on your Azure subscription and tenant, the Azure Service Principal, and the AWS IAM user and keys you just created.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and AWS. It then executes a script on an AWS EC2 virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your AWS and Azure environments. Edit [*scripts/vars.sh*](../aws/ubuntu/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.
    
    * TF_VAR_subscription_id=Your Azure Subscription ID
    * TF_VAR_client_id=Your Azure Service Principal app id
    * TF_VAR_client_secret=Your Azure Service Principal password
    * TF_VAR_tenant_id=Your Azure tenant ID
    * AWS_ACCESS_KEY_ID=AWS access key
    * AWS_SECRET_ACCESS_KEY=AWS secret key

* From CLI, navigate to the [*azure_arc_servers_jumpstart/aws/ubuntu/terraform*](../aws/ubuntu/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](../aws/ubuntu/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly. Note that this script will also be automatically executed remotely on the AWS virtual machine as part of the Terraform deployment. 

    ```source ./scripts/vars.sh```

* Make sure your SSH keys are available in *~/.ssh* and named *id_rsa.pub* and *id_rsa*. If you followed the ssh-keygen guide above to create your key then this should already be setup correctly. If not, you may need to modify [*main.tf*](../aws/ubuntu/terraform/main.tf) to use a key with a different path.

* Run the ```terraform init``` command which will download the Terraform AzureRM provider.

    ![](../img/aws_ubuntu/09.png)

# Deployment

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Upon completion, you will have an AWS Amazon Linux 2 VM deployed and connected as a new Azure Arc server inside a new Resource Group.

* Open the Azure portal and navigate to the resource group "Arc-AWS-Demo". The virtual machine created in AWS will be visible as a resource.

    ![](../img/aws_ubuntu/10.png)

    ![](../img/aws_ubuntu/19.png)

# Semi-Automated Deployment (Optional)

As you may have noticed, the last step of the run is to register the VM as a new Arc server resource.
    ![](../img/aws_ubuntu/11.png)

If you want to demo/control the actual registration process, do the following: 

1. In the [*install_arc_agent.sh.tmpl*](../aws/ubuntu/terraform/scripts/install_arc_agent.sh.tmpl) script template, comment out the "Run connect command" section and save the file.

    ![](../img/aws_ubuntu/12.png)

2. Get the public IP of the AWS VM by running ```terraform output```

    ![](../img/aws_ubuntu/13.png)

3. SSH the VM using the ```ssh ubuntu@x.x.x.x``` where x.x.x.x is the host ip. 

    ![](../img/aws_ubuntu/14.png)

4. Export all the environment variables in [*vars.sh*](../aws/ubuntu/terraform/scripts/vars.sh)

    ![](../img/aws_ubuntu/15.png)

5. Run the following command
    ```bash
    azcmagent connect --service-principal-id $TF_VAR_client_id --service-principal-secret $TF_VAR_client_secret --resource-group "Arc-AWS-Demo" --tenant-id $TF_VAR_tenant_id --location "westus2" --subscription-id $TF_VAR_subscription_id
    ```
    ![](../img/aws_ubuntu/16.png)

6. When complete, your VM will be registered with Azure Arc and visible in the resource group inside Azure Portal.

# Delete the deployment<a name="teardown"></a>

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command as shown below.
    ![](../img/aws_ubuntu/17.png)

Alternatively, you can delete the AWS EC2 instance directly by terminating it from the [AWS Console](https://console.aws.amazon.com/ec2/v2/home). Note that it will take a few minutes for the instance to actually be removed.
    ![](../img/aws_ubuntu/18.png)

If you delete the instance manually, then you should also delete [install_arc_agent.sh](../aws/ubuntu/terraform/scripts/install_arc_agent.sh) which is created by the Terraform plan.