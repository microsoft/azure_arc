# Onboard a VMWare Ubuntu server with Azure Arc

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an Ubuntu Server, VMware vSphere virtual machine and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* A VMware vCenter Server user with [permissions to deploy](https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.vm_admin.doc/GUID-8254CD05-CC06-491D-BA56-A773A32A8130.html) a Virtual Machine from a Template in the vSphere Web Client.

* Create Azure Service Principal (SP)   

    To connect the VMware vSphere virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

## Preparing an Ubuntu Server VMware vSphere VM Template

Before using the below guide to deploy an Ubuntu Server VM and connect it to Azure Arc, a VMware vSphere Template is required. [The following README](../docs/vmware_ubuntu_template.md) will instruct you how to easily create such a template using VMware vSphere 6.5 and above. 

**Note:** If you already have an Ubuntu Server VM template it is still recommended to use the guide as a reference. 

# Deployment

Before executing the Terraform plan, you must set the environment variables which will be used by the plan. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and your VMware vSphere credentials.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and VMware vSphere. It then executes a script on the virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your VMware vSphere and Azure environments. Edit [*scripts/vars.sh*](../vmware/ubuntu/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.
    
    * TF_VAR_subscription_id=Your Azure Subscription ID
    * TF_VAR_client_id=Your Azure Service Principle name
    * TF_VAR_client_secret=Your Azure Service Principle password
    * TF_VAR_tenant_id=Your Azure tenant ID
    * TF_VAR_resourceGroup=Azure Resource Group Name
    * TF_VAR_location=Azure Region
    * TF_VAR_vsphere_user=vCenter Admin Username
    * TF_VAR_vsphere_password=vCenter Admin Password
    * TF_VAR_vsphere_server=vCenter server FQDN/IP
    * TF_VAR_admin_user=OS Admin Username
    * TF_VAR_admin_password=OS Admin Password

* From CLI, navigate to the [*azure_arc_servers_jumpstart/vmware/ubuntu/terraform*](../vmware/ubuntu/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](../vmware/ubuntu/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly. Note that this script will also be automatically executed remotely on the virtual machine as part of the Terraform deployment. 

    ```source ./scripts/vars.sh```

* In addition to the *TF_VAR* environment variables you've just exported, edit the Terraform variables in the [*terraform.tfvars*](../vmware/ubuntu/terraform/terraform.tfvars) to match your VMware vSphere environment.

![](../img/vmware_terraform_ubuntu/01.png)

* Run the ```terraform init``` command which will download the Terraform AzureRM, Local and vSphere providers.

![](../img/vmware_terraform_ubuntu/02.png)

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish. 

Once the Terraform deployment is completed, a new Ubuntu Server VM will be up & running and will be projected as an Azure Arc server resource in a newly created Azure Resource Group. 

![](../img/vmware_terraform_ubuntu/03.png)

![](../img/vmware_terraform_ubuntu/04.png)

![](../img/vmware_terraform_ubuntu/05.png)

![](../img/vmware_terraform_ubuntu/06.png)

# Delete the deployment

The most straightforward way is to delete the Azure Arc resource via the Azure Portal, just select the resource and delete it. In addition, delete the VMware vSphere VM.

![](../img/vmware_terraform_ubuntu/07.png)

If you delete the instance manually, then you should also delete [install_arc_agent.sh](../vmware/ubuntu/terraform/scripts) which is created by the Terraform plan.

If you want to nuke the entire environment use the ```terraform destroy --auto-approve``` command as shown below.

![](../img/vmware_terraform_ubuntu/08.png)