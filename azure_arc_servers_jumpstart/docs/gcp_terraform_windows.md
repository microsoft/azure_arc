#  Onboard a GCP Windows server with Azure Arc

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a Windows Server GCP virtual machine and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* Google Cloud account with billing enabled - [Create a free trial account](https://cloud.google.com/free). To create Windows Server virtual machines, you must upgraded your account to enable billing. Click Billing from the menu and then select Upgrade in the lower right.

    ![](../img/gcp_windows/29.png)

    ![](../img/gcp_windows/30.png)

    ![](../img/gcp_windows/32.png)

    ***Disclaimer*** - **To prevent unexpected charges, please follow the "Delete the deployment" section at the end of this README**

* Create Azure Service Principal (SP)   

    To connect the GCP virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcGCP" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcGCP",
    "name": "http://AzureArcGCP",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Create a new GCP Project

* Browse to https://console.cloud.google.com and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different then the project name.

    ![](../img/gcp_windows/01.png)

    ![](../img/gcp_windows/02.png)

* Once the new project is created and selected in the dropdown at the top of the page, you must enable Compute Engine API access for the project. Click on "+Enable APIs and Services" and search for "Compute Engine". Then click Enable to enable API access.

    ![](../img/gcp_windows/03.png)

    ![](../img/gcp_windows/04.png)

* Next, set up a service account key, which Terraform will use to create and manage resources in your GCP project. Go to the [create service account key page](https://console.cloud.google.com/apis/credentials/serviceaccountkey). Select "New Service Account" from the dropdown, give it a name, select Project then Owner as the role, JSON as the key type, and click Create. This downloads a JSON file with all the credentials that will be needed for Terraform to manage the resources. Copy the downloaded JSON file to the [*azure_arc_servers_jumpstart/gcp/windows/terraform*](../gcp/windows/terraform/) directory.

    ![](../img/gcp_windows/05.png)

# Deployment

Before executing the Terraform plan, you must set and then export the environment variables which will be used by the plan. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and the GCP project name.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and Google Cloud. It then executes a script on a Google Cloud virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your Google Cloud and Azure environments. Edit [*scripts/vars.sh*](../gcp/windows/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.
    
    * TF_VAR_subscription_id=Your Azure Subscription ID
    * TF_VAR_client_id=Your Azure Service Principal app id
    * TF_VAR_client_secret=Your Azure Service Principal password
    * TF_VAR_tenant_id=Your Azure tenant ID
    * TF_VAR_gcp_project_id=GCP project id
    * TF_VAR_gcp_credentials_filename=GCP credentials json filename

* From CLI, navigate to the [*azure_arc_servers_jumpstart/gcp/windows/terraform*](../gcp/windows/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](../gcp/windows/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly.

    ```source ./scripts/vars.sh```

* Run the ```terraform init``` command which will download the Terraform AzureRM provider.

    ![](../img/gcp_windows/08.png)

* Next, run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Upon completion of the Terraform script, you will have deployed a GCP Windows Server 2019 VM and initiated a script to download the Azure Arc agent to the VM and connect the VM as a new Azure Arc server inside a new Azure Resource Group. It will take a few minutes for the agent to finish provisioning so grab a coffee.

    ![](../img/gcp_windows/09.png)

* After a few minutes, you should be able to open the Azure portal and navigate to the resource group "Arc-GCP-Demo". The Windows Server virtual machine created in GCP will be visible as a resource.

    ![](../img/gcp_windows/33.png)

# Semi-Automated Deployment (Optional)

The Terraform plan automatically installs the Azure Arc agent and connects the VM to Azure as a managed resource by executing a Powershell script when the VM is first booted.
    ![](../img/gcp_windows/12.png)

If you want to demo/control the actual registration process, do the following: 

1. Before running the ```terraform apply``` command, open [*main.tf*](../gcp/windows/terraform/main.tf) and comment out the ```windows-startup-script-ps1 = local_file.install_arc_agent_ps1.content``` line and save the file.

    ![](../img/gcp_windows/13.png)

2. Run ```terraform apply --auto-approve``` as instructed above.

3. Open the Google Cloud console and navigate to the [Compute Instance page](https://console.cloud.google.com/compute/instances), then click on the VM that was created. 

    ![](../img/gcp_windows/14.png)

    ![](../img/gcp_windows/15.png)

4. Create a user and password for the VM by clicking "Set Password" and specifying a username.

    ![](../img/gcp_windows/17.png)

5. RDP into the VM by clicking the RDP button from the VM page in Google Cloud console, and login with the username and password you just created.

    ![](../img/gcp_windows/18.png)

6. Once logged in, open Powershell ISE **as Administrator**. Make sure you are running the x64 version of Powershell ISE and not x86. Once open, select File->New to create an empty .ps1 file. Then paste in the entire contents of [./scripts/install_arc_agent.ps1](./scripts/install_arc_agent.ps1). Click the play button to execute the script. When complete, you should see the output showing successful onboarding of the machine.

    ![](../img/gcp_windows/19.png)

# Delete the deployment<a name="teardown"></a>

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command as shown below.
    ![](../img/gcp_windows/11.png)

Alternatively, you can delete the GCP VM directly from [GCP Console](https://console.cloud.google.com/compute/instances). 
    ![](../img/gcp_windows/16.png)