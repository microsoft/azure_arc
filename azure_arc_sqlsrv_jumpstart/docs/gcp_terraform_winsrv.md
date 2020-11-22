# Onboard a GCP VM instance with Windows Server & Microsoft SQL Server to Azure Arc

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a Windows Server installed with Microsoft SQL Server 2019 (Developer edition) in a Google Cloud Platform (GCP) virtual machine and connect it as an Azure Arc enabled SQL server resource.

By the end of the guide, you will have a GCP VM instance installed with Windows Server 2019 with SQL Server 2019, projected as an Azure Arc enabled SQL Server and a running SQL assessment with data injected to Azure Log Analytics workspace.

## Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Create a free Google Cloud account](https://cloud.google.com/free) if you don't have one already.

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* Create Azure Service Principal (SP)   

    To connect the GCP virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

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

## Create a new GCP Project, IAM Role & Service Account

* Create a new GCP Project, IAM Role & Service Account

In order to deploy resources in GCP, we will create a new GCP Project as well as a service account to allow Terraform to authenticate against GCP APIs and run the plan to deploy resources.

* Browse to https://console.cloud.google.com/ and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different then the project name.

  ![](../img/gcp_terraform_winsrv/01.png)
  ![](../img/gcp_terraform_winsrv/02.png)
  ![](../img/gcp_terraform_winsrv/03.png)

* Enable the Compute Engine API for the project, create a project Owner service account credentials and download the private key JSON file and copy the file to the directory where Terraform files are located. Change the JSON file name (for example *account.json*). The Terraform plan will be using the credentials stored in this file to authenticate against your GCP project.

  ![](../img/gcp_terraform_winsrv/04.png)
  ![](../img/gcp_terraform_winsrv/05.png)
  ![](../img/gcp_terraform_winsrv/06.png)
  ![](../img/gcp_terraform_winsrv/07.png)
  ![](../img/gcp_terraform_winsrv/08.png)
  ![](../img/gcp_terraform_winsrv/09.png)
  ![](../img/gcp_terraform_winsrv/10.png)
  ![](../img/gcp_terraform_winsrv/11.png)
  ![](../img/gcp_terraform_winsrv/12.png)
  ![](../img/gcp_terraform_winsrv/13.png)
  ![](../img/gcp_terraform_winsrv/14.png)
  ![](../img/gcp_terraform_winsrv/15.png)
  ![](../img/gcp_terraform_winsrv/16.png)

* Enable the Compute Engine API for the project

  ![](../img/gcp_terraform_winsrv/17.png)
  ![](../img/gcp_terraform_winsrv/18.png)

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User is exporting the Terraform environment variables (1-time export) which are being used throughout the deployment.

2. User is executing the Terraform plan which will deploy the VM as well as:

    1. Create an Administrator Windows user account and enabling WinRM on the VM

    2. Generate and execute the [*sql.ps1*](../gcp/winsrv/terraform/scripts/sql.ps1.tmpl) script. This script will:

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

        3. Disable and prevent Windows Server Manager from running on startup

3. Once Terraform plan deployment has completed and upon the user initial RDP login to Windows, *LogonScript.ps1* script will run automatically and execute all the above.

## Deployment

Before executing the Terraform plan, you must set the environment variables which will be used by the plan. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and your GCP project.

* Retrieve your Azure Subscription ID and tenant ID using the `az account list` command.

* The Terraform plan creates resources in both Microsoft Azure and GCP. It then executes a script on the virtual machine to install all the necessary artifacts. 

Both the script and the Terraform plan itself requires certain information about your GCP and Azure environments. Edit variables according to your environment and export it using the below commands

```bash
export TF_VAR_subId='Your Azure Subscription ID'
export TF_VAR_servicePrincipalAppId='Your Azure Service Principal App ID'
export TF_VAR_servicePrincipalSecret='Your Azure Service Principal App Password'
export TF_VAR_servicePrincipalTenantId='Your Azure tenant ID'
export TF_VAR_location='Azure Region'
export TF_VAR_resourceGroup='Azure Resource Group Name'
export TF_VAR_gcp_project_id='GCP Project ID'
export TF_VAR_gcp_credentials_filename='GCP Project credentials filename'
export TF_VAR_gcp_region='GCP region where resource will be created'
export TF_VAR_gcp_zone='GCP zone where resource will be created'
export TF_VAR_gcp_instance_name='GCP VM instance name'
export TF_VAR_gcp_instance_machine_type='GCP VM instance type'
export TF_VAR_admin_user='Guest OS Admin Username'
export TF_VAR_admin_password='Guest OS Admin Password'
```

![](../img/gcp_terraform_winsrv/19.png)

* From the folder within your cloned repo where the Terraform binaries are, the below commands to download the needed TF providers and to run the plan. 

    ```terminal
    terraform init
    terraform apply --auto-approve
    ``` 

Once the Terraform plan deployment has completed, a new Windows Server VM will be up & running as well as an empty Azure Resource Group will be created. 

![](../img/gcp_terraform_winsrv/20.png)

![](../img/gcp_terraform_winsrv/21.png)

![](../img/gcp_terraform_winsrv/22.png)

* Download the RDP file and log in to the VM (**using data from the *TF_VAR_admin_user* and *TF_VAR_admin_password* environment variables**) which will initiate the *LogonScript* run. Let the script to run it's course and which will also close the PowerShell session when completed. 

![](../img/gcp_terraform_winsrv/23.png)

**Note: The script runtime will take ~10-15min to complete**

![](../img/gcp_terraform_winsrv/24.png)

![](../img/gcp_terraform_winsrv/25.png)

![](../img/gcp_terraform_winsrv/26.png)

![](../img/gcp_terraform_winsrv/27.png)

![](../img/gcp_terraform_winsrv/28.png)

![](../img/gcp_terraform_winsrv/29.png)

![](../img/gcp_terraform_winsrv/30.png)

![](../img/gcp_terraform_winsrv/31.png)

![](../img/gcp_terraform_winsrv/32.png)

* Open Microsoft SQL Server Management Studio (a Windows shortcut will be created for you) and validate the *AdventureWorksLT2019* sample database is deployed as well.

![](../img/gcp_terraform_winsrv/33.png)

![](../img/gcp_terraform_winsrv/34.png)

* In the Azure Portal, notice you now have an Azure Arc enabled Server resource (with the MMA agent installed via an Extension), Azure Arc enabled SQL resource and Azure Log Analytics deployed.

![](../img/gcp_terraform_winsrv/35.png)

![](../img/gcp_terraform_winsrv/36.png)

![](../img/gcp_terraform_winsrv/37.png)

![](../img/gcp_terraform_winsrv/38.png)

## Azure SQL Assessment

Now that you have both the server and SQL projected as Azure Arc resources, the last step is complete the initiation of the SQL Assessment run. 

* On the SQL Azure Arc resource, click on "Environment Health" followed by clicking the "Download configuration script". 

Since the *LogonScript* run in the deployment step took care of deploying and installing the required binaries, you safety ignore and delete the downloaded *AddSqlAssessment.ps1* file. 
Clicking the "Download configuration script" will simply send a REST API call to the Azure portal which will make "Step3" available and will result with a grayed-out "View SQL Assessment Results" button. 

![](../img/gcp_terraform_winsrv/39.png)

![](../img/gcp_terraform_winsrv/40.png)

![](../img/gcp_terraform_winsrv/41.png)

* After few minutes you will notice how the "View SQL Assessment Results" button is available for you to click on. At this point, the SQL assessment data and logs is getting injected to Azure Log Analytics. 

Initially, the amount of data will be limited as it take a while for the assessment to complete a full cycle but after few hours you should be able to see much more data coming in.  

![](../img/gcp_terraform_winsrv/42.png)

![](../img/gcp_terraform_winsrv/43.png)

## Cleanup

To delete the environment, use the *`terraform destroy --auto-approve`* command which will delete the GCP and the Azure resources.

![](../img/gcp_terraform_winsrv/44.png)
