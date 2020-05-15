# Azure Arc for Google Cloud

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a GCP virtual machine and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

* [Generate SSH Key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) (or use existing ssh key) 

* Google Cloud account - [create a free trial account](https://cloud.google.com/free)

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

### Create a new GCP Project

* Browse to https://console.developers.google.com and login with your Google Cloud account. Once logged in, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) named "Azure Arc Demo". After creating it, be sure to copy down the project id as it is usually different then the project name.

    <!-- ![](../img/gcp/04.png) -->

* Once the new project is created and selected in the dropdown at the top of the page, you must enable Compute Engine API access for the project. Click on "+Enable APIs and Services" and search for "Compute Engine". 

    <!-- ![](../img/gcp/05.png) -->

* Then click Enable to enable API access.

    <!-- ![](../img/gcp/01.png) -->

* Next, set up a service account key, which Terraform will use to create and manage resources in your GCP project. Go to the [create service account key page](https://console.cloud.google.com/apis/credentials/serviceaccountkey). Select the default service account or create a new one, give it a name, select Project then Owner as the role, JSON as the key type, and click Create. This downloads a JSON file with all the credentials that will be needed for Terraform to manage the resources. Copy the downloaded JSON file to the *azure_arc_servers_jumpstart/gcp/terraform* directory.

* Finally, make sure your SSH keys are available in *~/.ssh* and named *id_rsa.pub* and *id_rsa*. If you followed the ssh-keygen guide above to create your key then this should already be setup correctly. If not, you may need to modify [*main.tf*](../gcp/terraform/main.tf) to use a key with a different path.

### Create Azure Service Principal (SP)   

* To connect the GCP virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

    ```az login```

    ```az ad sp create-for-rbac -n "http://AzureArcGCP" --role contributor```

    Output should look similar to this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcGCP",
    "name": "http://AzureArcGCP",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Deployment

Before executing the Terraform plan, you must export the environment variables which will be used by the plan. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and the GCP project name.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and Google Cloud. It then executes a script on a Google Cloud virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your Google Cloud and Azure environments. Edit [*scripts/vars.sh*](../gcp/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.
    
    * TF_VAR_subscription_id=Your Azure Subscription ID
    * TF_VAR_client_id=Your Azure Service Principal app id
    * TF_VAR_client_secret=Your Azure Service Principal password
    * TF_VAR_tenant_id=Your Azure tenant ID
    * TF_VAR_gcp_project_id=GCP project id
    * TF_VAR_gcp_credentials_filename=GCP credentials json filename

* From CLI, navigate to the [*azure_arc_servers_jumpstart/gcp/terraform*](../gcp/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](../gcp/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly. Note that this script will also be automatically executed remotely on the GCP virtual machine as part of the Terraform deployment. 

    ```source ./scripts/vars.sh```

* Run the ```terraform init``` command which will download the Terraform AzureRM provider.

    ![](../img/gcp/08.png)

* Next, run the ```terraform apply --auto-approve``` command and wait for the plan to finish. Upon completion, you will have a GCP Ubuntu VM deployed and connected as a new Azure Arc server inside a new Resource Group.

# View the GCP VM from Azure Portal

* Open the Azure portal and navigate to the resource group "Arc-Servers-Demo". The virtual machine created in GCP will be visible as a resource.

    ![](../img/gcp/09.png)

# Semi-Automated Deployment (Optional)

As you may have noticed, the last step of the run is to register the VM as a new Arc server resource.
    ![](../img/gcp/10.png)

If you want to demo/control the actual registration process, do the following: 

1. In the [*install_arc_agent.sh.tmpl*](../gcp/terraform/scripts/install_arc_agent.sh.tmpl) script template, comment out the "Run connect command" section and save the file.

    ![](../img/gcp/11.png)

2. Get the public IP of the GCP VM by running ```terraform output```

    ![](../img/gcp/12.png)

3. SSH the VM using the ```ssh arcadmin@x.x.x.x``` where x.x.x.x is the host ip. 

    ![](../img/gcp/13.png)

4. Export all the environment variables in [*vars.sh*](../gcp/terraform/scripts/vars.sh)

    ![](../img/gcp/14.png)

5. Run the following command
    ```azcmagent connect --service-principal-id $TF_VAR_client_id --service-principal-secret $TF_VAR_client_secret --resource-group "Arc-Servers-Demo" --tenant-id $TF_VAR_tenant_id --location "westus2" --subscription-id $TF_VAR_subscription_id```

    ![](../img/gcp/15.png)

6. When complete, your VM will be registered with Azure Arc and visible in the resource group inside Azure Portal.

# Delete the deployment

To delete all the resources you created as part of this demo use the ```terraform destroy --auto-approve``` command.

Alternatively, you can delete the GCP VM directly from [GCP Console](https://console.cloud.google.com/compute/instances). 
    ![](../img/gcp/16.png)