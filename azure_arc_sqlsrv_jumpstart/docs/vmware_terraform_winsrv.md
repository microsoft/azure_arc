# Onboard a VMware vSphere-based Windows Server with SQL to Azure Arc

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a Windows Server installed with Microsoft SQL Server 2019 (Developer edition) in a VMware vSphere virtual machine and connect it as an Azure Arc enabled SQL server resource.

By the end of the guide, you will have a VMware vSphere VM installed with Windows Server 2019 with SQL Server 2019, projected as an Azure Arc enabled SQL Server and a running Azure SQL assessment.

## Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* A VMware vCenter Server user with [permissions to deploy](https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.vm_admin.doc/GUID-8254CD05-CC06-491D-BA56-A773A32A8130.html) a Virtual Machine from a Template in the vSphere Web Client.

* Create Azure Service Principal (SP)   

    To connect the VMware vSphere virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```terminal
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```terminal
    az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor
    ```

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

### Preparing a Window Server VMware vSphere VM Template

Before using the below guide to deploy a Windows Server VM and connect it to Azure Arc, a VMware vSphere Template is required. [The following README](..\..\azure_arc_servers_jumpstart\docs\vmware_terraform_winsrv.md) will instruct you how to easily create such a template using VMware vSphere 6.5 and above. 

**The Terraform plan leveraged the *remote-exec* provisioner which uses the WinRM protocol to copy and execute the required Azure Arc script. To allow WinRM connectivity to the VM, run the [*allow_winrm*](../vmware/winsrv/terraform/scripts/allow_winrm.ps1) Powershell script on your VM before converting it to template.** 

**Note:** If you already have a Windows Server VM template it is still recommended to use the guide as a reference.

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User is exporting the Terraform environment variables (1-time export) which are being used throughout the deployment.

2. User is executing the Terraform plan which will deploy the VM as well as generate and execute the [*sql.ps1*](../vmware/winsrv/terraform/scripts/sql.ps1.tmpl) script. This script will:

    1. Install Azure CLI, Azure PowerShell module and SQL Server Management Studio (SSMS) [Chocolaty packages](https://chocolatey.org/).

    2. Create a runtime logon script (*LogonScript.ps1*) which will run upon the user first logon to Windows. Runtime script will:
        * Install SQL Server Developer Edition
        * Enable SQL TCP protocol on the default instance
        * Create SQL Server Management Studio Desktop shortcut
        * Restore [*AdventureWorksLT2019*](https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=ssms) Sample Database
        * Onboard both the server and SQL to Azure Arc
        * Deploy Azure Log Analytics and a workspace 
        * Install the [Microsoft Monitoring Agent (MMA) agent](https://docs.microsoft.com/en-us/services-hub/health/mma-setup)
        * Enable Log Analytics Solutions
        * Deploy MMA Azure Extension ARM Template from within the VM
        * Configure SQL Azure Assessment

    3. Disable Windows Firewall

    4. Disable and prevent Windows Server Manager from running on startup

3. Once Terraform plan deployment has completed and upon the user initial RDP login to Windows, *LogonScript.ps1* script will run automatically and execute all the above.

## Deployment

Before executing the Terraform plan, you must set the environment variables which will be used by the plan. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and your VMware vSphere environment.

* Retrieve your Azure Subscription ID and tenant ID using the `az account list` command.

* The Terraform plan creates resources in both Microsoft Azure and VMware vSphere. It then executes a script on the virtual machine to install all the necessary artifacts. 

Both the script and the Terraform plan itself requires certain information about your VMware vSphere and Azure environments. Edit variables according to your environment and export it using the below commands

```bash
export TF_VAR_subId='Your Azure Subscription ID'
export TF_VAR_servicePrincipalAppId='Your Azure Service Principal App ID'
export TF_VAR_servicePrincipalSecret='Your Azure Service Principal App Password'
export TF_VAR_servicePrincipalTenantId='Your Azure tenant ID'
export TF_VAR_location='Azure Region'
export TF_VAR_resourceGroup='Azure Resource Group Name'
export TF_VAR_vsphere_datacenter='VMware vSphere Datacenter Name'
export TF_VAR_vsphere_datastore='VMware vSphere Datastore Name'
export TF_VAR_vsphere_resource_pool='VMware vSphere Cluster or Resource Pool Name'
export TF_VAR_network_cards='VMware vSphere Network Name'
export TF_VAR_vsphere_folder='VMware vSphere Folder Name'
export TF_VAR_vsphere_vm_template_name='VMware vSphere VM Template Name'
export TF_VAR_vsphere_virtual_machine_name='VMware vSphere VM Name'
export TF_VAR_vsphere_virtual_machine_cpu_count='VMware vSphere VM CPU Count'
export TF_VAR_vsphere_virtual_machine_memory_size='VMware vSphere VM Memory Size in Megabytes'
export TF_VAR_domain='Domain'
export TF_VAR_vsphere_user='VMware vSphere vCenter Admin Username'
export TF_VAR_vsphere_password='VMware vSphere vCenter Admin Password'
export TF_VAR_vsphere_server='VMware vSphere vCenter server FQDN/IP'
export TF_VAR_admin_user='Guest OS Admin Username'
export TF_VAR_admin_password='Guest OS Admin Password'
```

**Note: Use the Terraform plan [*variables.tf*](..\vmware\winsrv\terraform\variables.tf) file for more details around VMware vSphere vars structure if needed**

![](../img/vmware_terraform_winsrv/01.jpg)

* From the folder within your cloned repo where the Terraform binaries are, the below commands to download the needed TF providers and to run the plan. 

    ```terminal
    terraform init
    terraform apply --auto-approve
    ``` 

Once the Terraform plan deployment has completed, a new Windows Server VM will be up & running as well as an empty Azure Resource Group will be created. 

![](../img/vmware_terraform_winsrv/02.jpg)

![](../img/vmware_terraform_winsrv/03.jpg)

![](../img/vmware_terraform_winsrv/04.jpg)

* og in to the VM (**using data from the *TF_VAR_admin_user* and *TF_VAR_admin_password* environment variables**) which will initiate the *LogonScript* run. Let the script to run it's course and which will also close the PowerShell session when completed. 

**Note: The script runtime will take ~10-15min to complete**

![](../img/vmware_terraform_winsrv/05.jpg)

![](../img/vmware_terraform_winsrv/06.jpg)

![](../img/vmware_terraform_winsrv/07.jpg)

![](../img/vmware_terraform_winsrv/08.jpg)

![](../img/vmware_terraform_winsrv/09.jpg)

![](../img/vmware_terraform_winsrv/10.jpg)

![](../img/vmware_terraform_winsrv/11.jpg)

![](../img/vmware_terraform_winsrv/12.jpg)

![](../img/vmware_terraform_winsrv/13.jpg)

* Open Microsoft SQL Server Management Studio (a Windows shortcut will be created for you) and validate the *AdventureWorksLT2019* sample database is deployed as well.

![](../img/vmware_terraform_winsrv/14.jpg)

![](../img/vmware_terraform_winsrv/15.jpg)

* In the Azure Portal, notice you now have an Azure Arc enabled Server resource (with the MMA agent installed via an Extension), Azure Arc enabled SQL resource and Azure Log Analytics deployed.

![](../img/vmware_terraform_winsrv/16.jpg)

![](../img/vmware_terraform_winsrv/17.jpg)

![](../img/vmware_terraform_winsrv/18.jpg)

![](../img/vmware_terraform_winsrv/19.jpg)

## Azure SQL Assessment

Now that you have both the server and SQL projected as Azure Arc resources, the last step is complete the initiation of the SQL Assessment run. 

* On the SQL Azure Arc resource, click on "Environment Health" followed by clicking the "Download configuration script". 

Since the *LogonScript* run in the deployment step took care of deploying and installing the required binaries, you safety ignore and delete the downloaded *AddSqlAssessment.ps1* file. 
Clicking the "Download configuration script" will simply send a REST API call to the Azure portal which will make "Step3" available and will result with a grayed-out "View SQL Assessment Results" button. 

![](../img/vmware_terraform_winsrv/20.jpg)

![](../img/vmware_terraform_winsrv/21.jpg)

![](../img/vmware_terraform_winsrv/22.jpg)

* After few minutes you will notice how the "View SQL Assessment Results" button is available for you to click on. At this point, the SQL assessment data and logs is getting injected to Azure Log Analytics. 

Initially, the amount of data will be limited as it take a while for the assessment to complete a full cycle but after few hours you should be able to see much more data coming in.  

![](../img/vmware_terraform_winsrv/23.jpg)

![](../img/vmware_terraform_winsrv/24.jpg)

![](../img/vmware_terraform_winsrv/25.jpg)

## Cleanup

To delete the environment, use the *`terraform destroy --auto-approve`* command which will delete the VMware vSphere VM and the Azure Resource Group along with it's resources.

![](../img/vmware_terraform_winsrv/26.jpg)
