# Scaled Onboarding AWS EC2 instances to Azure Arc using Ansible

The following README will guide you on how to automatically perform scaled onboarding of AWS EC2 instances to Azure Arc by using [Ansible](https://www.ansible.com/). 

This guide assumes that you have a basic understanding of Ansible. A basic Ansible playbook and configuration is provided that uses the [amazon.aws.aws_ec2](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html) plugin for dynamic loading of EC2 server inventory. 

This guide can be used even if you do not already have an existing Ansible test environment and includes a Terraform plan that will create a sample AWS EC2 server inventory comprised of four (4) Windows Server 2019 servers and four (4) Ubuntu servers along with a basic CentOS 7 Ansible control server with a simple configuration.

***Warning***: *The provided Ansible sample workbook uses WinRM with password authentication and HTTP to configure Windows-based servers. This is not advisable for production environments. If you are planning to use Ansible with Windows hosts in a production environment then you should use [WinRM over HTTPS](https://docs.microsoft.com/en-us/troubleshoot/windows-client/system-management-components/configure-winrm-for-https) with a certificate.*

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Generate SSH Key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) (or use existing ssh key) 

* [Create free AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)

* [Install Terraform >=0.13](https://learn.hashicorp.com/terraform/getting-started/install.html)

## Create Azure Service Principal (SP)   

* To connect the AWS virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```console
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:
    ```console
    az ad sp create-for-rbac -n "http://AzureArcAWS" --role contributor
    ```

    Output should look like this:

    ```console
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcAWS",
    "name": "http://AzureArcAWS",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

## Create an AWS identity

In order for Ansible to dynamically generate a server inventory from AWS, we will need to create a new AWS IAM role with appropriate permissions.

* Login to the [AWS management console](https://console.aws.amazon.com)

* After logging in, click the "Services" dropdown in the top left. Under "Security, Identity, and Compliance" select "IAM" to access the [Identity and Access Management page](https://console.aws.amazon.com/iam/home)

    ![](../img/aws_ubuntu/01.png) 

    ![](../img/aws_ubuntu/02.png)

* Click on "Users" from the left menu and then click on "Add user" to create a new IAM user.

    ![](../img/aws_ubuntu/03.png)

* On the "Add User" screen, give the user a name (e.g. "ansible") and select the "Programmatic Access" checkbox then click "Next"

    ![](../img/aws_ubuntu/04.png)

* On the next "Set Permissions" screen, select "Attach existing policies directly" and then check the box next to *AmazonEC2FullAccess* as seen in the screenshot then click "Next"

    ![](../img/aws_ubuntu/05.png)

* On the tags screen, assign a tag with a key of "azure-arc-demo" and click "Next" to proceed to the Review screen.

    ![](../img/aws_ubuntu/06.png)

* Double check that everything looks correct and click "Create user" when ready.

    ![](../img/aws_ubuntu/07.png)

* After the user is created, you will see the user's Access key ID and Secret access key. Copy these values down before clicking the Close button. In the screen below, you can see an example of what this should look like. Once you have these keys, you will be able to use them with Terraform to create AWS resources.

    ![](../img/aws_ubuntu/08.png)

# <a name="option1"></a>Option 1- Creating a sample AWS server inventory and Ansible control server using Terraform and onboarding the servers to Azure Arc

**Note: If you already have an existing AWS server inventory and Ansible server, skip below to [Option 2](#option2).**

## Configure Terraform

Before executing the Terraform plan, you must export the environment variables which will be used by the plan. These variables are based on your Azure subscription and tenant, the Azure Service Principal, and the AWS IAM user and keys you just created.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and AWS. It then executes a script on an AWS EC2 virtual machine to install Ansible and all necessary artifacts. This Terraform plan requires certain information about your AWS and Azure environments which it accesses using environment variables. Edit [*scripts/vars.sh*](../aws/scale_deployment/ansible/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.
    
    * TF_VAR_subscription_id=Your Azure Subscription ID
    * TF_VAR_client_id=Your Azure Service Principal app id
    * TF_VAR_client_secret=Your Azure Service Principal password
    * TF_VAR_tenant_id=Your Azure tenant ID
    * AWS_ACCESS_KEY_ID=AWS access key
    * AWS_SECRET_ACCESS_KEY=AWS secret key

* From your shell, navigate to the [*azure_arc_servers_jumpstart/aws/scale_deployment/ansible/terraform*](../aws/scale_deployment/ansible/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](../aws/ubuntu/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly.

    ```source ./scripts/vars.sh```

* Make sure your SSH keys are available in *~/.ssh* and named *id_rsa.pub* and *id_rsa*. If you followed the ssh-keygen guide above to create your key then this should already be setup correctly. If not, you may need to modify [*aws_infra.tf*](../aws/scale_deployment/ansible/terraform/aws_infra.tf) to use a key with a different path.

* Run the ```terraform init``` command which will download the required Terraform providers.

    ![](../img/aws_scale_ansible/01.png)

## Deploy server infrastructure

* From the [*azure_arc_servers_jumpstart/aws/scale_deployment/ansible/terraform*](../aws/scale_deployment/ansible/terraform) directory, run ```terraform apply --auto-approve``` and wait for the plan to finish. Upon successful completion, you will have four (4) Windows Server 2019 servers, four (4) Ubuntu servers, and one (1) CentOS 7 Ansible control server.

* Open the AWS console and verify you can see the created servers.

    ![](../img/aws_scale_ansible/02.png)

## Run the Ansible playbook to onboard the AWS servers as Azure Arc enabled servers

* When the Terraform plan completes, it will display the public IP of the Ansible control server in an output variable named *ansible_ip*. SSH into the Ansible server by running the ```ssh centos@XX.XX.XX.XX``` where XX.XX.XX.XX is substituted for your Ansible server's IP address.

    ![](../img/aws_scale_ansible/03.png)

* Change directory to the *ansible* directory by running ```cd ansible```. This folder contains the sample Ansible configuration and the playbook we will use to onboard the servers to Azure Arc.

    ![](../img/aws_scale_ansible/04.png)

* The aws_ec2 Ansible plugin requires AWS credentials to dynamically read your AWS server inventory. We will export these as environment variables. Run the commands below, replacing the values for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY with AWS credentials you created earlier.

    ```
    export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXX"
    export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXX"
    ```

* Replace the placeholder values for Azure tenant ID and subscription id in the [group_vars/all.yml](../aws/scale_deployment/ansible/terraform/ansible_config/group_vars/all.yml) with the appropriate values for your environment.

    ![](../img/aws_scale_ansible/09.png)

* Run the Ansible playbook by executing the following command, substituting your Azure service principal id and service principal secret.

    ```
    ansible-playbook arc_agent.yml -i ansible_plugins/inventory_uswest2_aws_ec2.yml --extra-vars '{"service_principal_id": "XXXXXXX-XXXXX-XXXXXXX", "service_principal_secret": "XXXXXXXXXXXXXXXXXXXXXXXX"}'
    ```
    If the playbook run is successful, you should see output similar to the below screenshot. 

    ![](../img/aws_scale_ansible/05.png)

* Open Azure Portal and navigate to the Arc-AWS-Demo resource group. You should see the Azure Arc enabled servers listed.

    ![](../img/aws_scale_ansible/06.png)

## Clean up environment by deleting resources

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command as shown below.
    ![](../img/aws_scale_ansible/07.png)

# <a name="option2"></a>Option 2 - Onboarding an existing AWS server inventory to Azure Arc using your own Ansible control server

**Note: If you do not have an existing AWS server inventory and Ansible server, navigate back to [Option 1](#option1).**

## Review provided Ansible configuration and playbook

Navigate to the [ansible_config](../aws/scale_deployment/ansible/terraform/ansible_config) directory and review the provided configuration. The provided configuration contains a basic *ansible.cfg* file. This file enables the [amazon.aws.aws_ec2](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html) Ansible plugin which dynamically loads your server inventory by using an AWS IAM role. Ensure that the IAM role you are using has sufficient privileges to access the inventory you wish to onboard.
    ![](../img/aws_scale_ansible/08.png)

The file [inventory_uswest2_aws_ec2.yml](../aws/scale_deployment/ansible/terraform/ansible_config/ansible_plugins/inventory_uswest2_aws_ec2.yml) configures the aws_ec2 plugin to pull inventory from uswest-2 region and group assets by applied tags. Adjust this file as needed to support onboarding your server inventory (e.g., change region, or change groups or filters).

The files in [group_vars](../aws/scale_deployment/ansible/terraform/ansible_config/group_vars) should be adjusted to provide the credentials you wish to use to onboard various ansible host groups.

When you have adjusted the provided config to support your environment, run the Ansible playbook by executing the following command, substituting your Azure service principal id and service principal secret.

```console
ansible-playbook arc_agent.yml -i ansible_plugins/inventory_uswest2_aws_ec2.yml --extra-vars '{"service_principal_id": "XXXXXXX-XXXXX-XXXXXXX", "service_principal_secret": "XXXXXXXXXXXXXXXXXXXXXXXX"}'
```
    
If the playbook run is successful, you should see output similar to the below screenshot. 
    ![](../img/aws_scale_ansible/05.png)

Open Azure Portal and navigate to the Arc-Aws-Demo resource group. You should see the Azure Arc enabled servers listed.
    ![](../img/aws_scale_ansible/06.png)
