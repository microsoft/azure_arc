---
type: docs
title: "Ubuntu GCP instance"
linkTitle: "Ubuntu GCP instance"
weight: 1
description: >
---

## Deploy a GCP Ubuntu instance and connect it to Azure Arc using a Terraform plan

The following Jumpstart scenario will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an Ubuntu Server GCP virtual machine and connect it as an Azure Arc-enabled server resource.

## Prerequisites

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- [Install or update Azure CLI to version 2.49.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- [Generate a new SSH key pair](https://docs.microsoft.com/azure/virtual-machines/linux/create-ssh-keys-detailed) or use an existing one (Windows 10 and above now comes with a built-in ssh client).

  ```shell
  ssh-keygen -t rsa -b 4096
  ```

  To retrieve the SSH public key after it's been created, depending on your environment, use one of the below methods:
  - In Linux, use the `cat ~/.ssh/id_rsa.pub` command.
  - In Windows (CMD/PowerShell), use the SSH public key file that by default, is located in the _`C:\Users\WINUSER/.ssh/id_rsa.pub`_ folder.

  SSH public key example output:

  ```shell
  ssh-rsa o1djFhyNe5NXyYk7XVF7wOBAAABgQDO/QPJ6IZHujkGRhiI+6s1ngK8V4OK+iBAa15GRQqd7scWgQ1RUSFAAKUxHn2TJPx/Z/IU60aUVmAq/OV9w0RMrZhQkGQz8CHRXc28S156VMPxjk/gRtrVZXfoXMr86W1nRnyZdVwojy2++sqZeP/2c5GoeRbv06NfmHTHYKyXdn0lPALC6i3OLilFEnm46Wo+azmxDuxwi66RNr9iBi6WdIn/zv7tdeE34VAutmsgPMpynt1+vCgChbdZR7uxwi66RNr9iPdMR7gjx3W7dikQEo1djFhyNe5rrejrgjerggjkXyYk7XVF7wOk0t8KYdXvLlIyYyUCk1cOD2P48ArqgfRxPIwepgW78znYuwiEDss6g0qrFKBcl8vtiJE5Vog/EIZP04XpmaVKmAWNCCGFJereRKNFIl7QfSj3ZLT2ZXkXaoLoaMhA71ko6bKBuSq0G5YaMq3stCfyVVSlHs7nzhYsX6aDU6LwM/BTO1c= user@pc
  ```

- [Create free Google Cloud account]((https://cloud.google.com/free))

- [Install Terraform >=1.1.9](https://learn.hashicorp.com/terraform/getting-started/install.html)

- Google Cloud account with billing enabled - [Create a free trial account](https://cloud.google.com/free). To create Windows Server virtual machines, you must upgraded your account to enable billing. Click Billing from the menu and then select Upgrade in the lower right.

    ![Screenshot showing how to enable billing on GCP account](./01.png)

    ![Screenshot showing how to enable billing on GCP account](./02.png)

    ![Screenshot showing how to enable billing on GCP account](./03.png)

    **Disclaimer - To prevent unexpected charges, please follow the "Delete the deployment" section at the end of this README**

- Create Azure service principal (SP)

    To connect the GCP virtual machine to Azure Arc, an Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArc" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArc",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password**.

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

- Azure Arc-enabled servers depends on the following Azure resource providers in your subscription in order to use this service. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  - Microsoft.HybridCompute
  - Microsoft.GuestConfiguration
  - Microsoft.HybridConnectivity

      ```shell
      az provider register --namespace 'Microsoft.HybridCompute'
      az provider register --namespace 'Microsoft.GuestConfiguration'
      az provider register --namespace 'Microsoft.HybridConnectivity'
      ```

      You can monitor the registration process with the following commands:

      ```shell
      az provider show --namespace 'Microsoft.HybridCompute'
      az provider show --namespace 'Microsoft.GuestConfiguration'
      az provider show --namespace 'Microsoft.HybridConnectivity'
      ```

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User creates and configures a new GCP project along with a Service Account key which Terraform will use to create and manage resources

2. User edits the tfvars to match the environment.

3. User runs ```terraform init``` to download the required terraform providers

4. User runs the automation. The terraform plan will:

    - Create a Windows Server VM in GCP
    - Create an Azure Resource Group
    - Install the Azure Connected Machine agent by executing a PowerShell script when the VM is first booted. Optionally a semi-automated deployment is provided if you want to demo/control the actual registration process.

5. User verifies the VM is create in GCP and the new Azure Arc-enabled resource in the Azure portal.

## Create a new GCP Project

- Browse to <https://console.developers.google.com> and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different than the project name.

    ![Screenshot of GCP Cloud console create project screen](./04.png)

    ![Screenshot of GCP cloud new project screen](./05.png)

- Once the new project is created and selected in the dropdown at the top of the page, you must enable Compute Engine API access for the project. Click on "Enable APIs and Services" and search for "Compute Engine". Then click Enable to enable API access.

    ![Screenshot of GCP console showing enabling Compute Engine API](./06.png)

    ![Screenshot of GCP console showing enabling Compute Engine API](./07.png)

- Next, set up a service account key, which Terraform will use to create and manage resources in your GCP project. Go to the [create service account key page](https://console.cloud.google.com/apis/credentials/serviceaccountkey). Select "New Service Account" from the dropdown, give it a name, select Project then Owner as the role, JSON as the key type, and click Create. This downloads a JSON file with all the credentials that will be needed for Terraform to manage the resources. Copy the downloaded JSON file to the [_azure_arc_servers_jumpstart/gcp/ubuntu/terraform_](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/gcp/ubuntu/terraform) directory.

    ![Screenshot of GCP cloud console showing creation of service account](./08.png)

    ![Screenshot of GCP cloud console showing creation of service account](./09.png)

- Finally, make sure your SSH keys are available in _~/.ssh_ and named *id_rsa.pub* and *id_rsa*. If you followed the ssh-keygen guide above to create your key then this should already be setup correctly. If not, you may need to modify [_main.tf_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/gcp/ubuntu/terraform/main.tf) to use a key with a different path.

## Deployment

The only thing you need to do before executing the Terraform plan is to create the tfvars file which will be used by the plan. This is based on the Azure service principal you've just created and your subscription.

- Navigate to the [terraform folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_servers_jumpstart/gcp/ubuntu/terraform) and fill in the terraform.tfvars file with the values for your environment.

- Run the ```terraform init``` command which will download the required terraform providers.

    ![Screenshot showing terraform init being run](./10.png)

- Next, run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Upon completion, you will have a GCP Ubuntu VM deployed and connected as a new Azure Arc-enabled server inside a new resource group.

- Open the Azure portal and navigate to the resource group "Arc-GCP-Demo". The virtual machine created in GCP will be visible as a resource.

    ![Screenshot of Azure Portal showing Azure Arc-enabled server](./11.png)

## Semi-Automated Deployment (Optional)

- As you may have noticed, the last step of the run is to register the VM as a new Azure Arc-enabled server resource.

    ![Screenshot showing azcmagent connect script](./12.png)

- If you want to demo/control the actual registration process, do the following:

- In the [*install_arc_agent.sh.tmpl*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/gcp/ubuntu/terraform/scripts/install_arc_agent.sh.tmpl) script template, comment out the "Run connect command" section and save the file.

    ![Screenshot showing azcmagent connect commented out](./13.png)

- Get the public IP of the GCP VM by running ```terraform output```

    ![Screenshot showing terraform output](./14.png)

- SSH the VM using the ```ssh arcdemo@x.x.x.x``` where x.x.x.x is the host ip.

- Provide values to the environment variables to match your environment in the file [_vars.sh_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/gcp/ubuntu/terraform/scripts/vars.sh). Export the variables by copying and pasting the contents of the file

    ![Screenshot showing export of environment variables from vars.sh](./15.png)

- Run the following command:

    ```shell
    sudo azcmagent connect \
        --service-principal-id "${appId}" \
        --service-principal-secret "${appPassword}" \
        --tenant-id "${tenantId}" \
        --subscription-id "${subscriptionId}" \
        --location "${location}" \
        --resource-group "${resourceGroup}" \
        --resource-name $HOSTNAME \
        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
    ```

    ![Screenshot of azcmagent connect being run](./16.png)

- When complete, your VM will be registered with Azure Arc and visible in the resource group inside Azure Portal.

## Delete the deployment

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command as shown below.

![Screenshot of terraform destroy being run](./17.png)

Alternatively, you can delete the GCP VM directly from [GCP Console](https://console.cloud.google.com/compute/instances).

![Screenshot of deleting VM from GCP cloud console](./18.png)
