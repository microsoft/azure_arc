---
type: docs
linkTitle: "Jumpstart ArcBox for DevOps"
weight: 3
---

## Jumpstart ArcBox for DevOps

ArcBox for DevOps is a special "flavor" of ArcBox that is intended for users who want to experience Azure Arc-enabled Kubernetes capabilities in a sandbox environment.

![ArcBox architecture diagram](./arch_devops.png)

### Use cases

- Sandbox environment for getting hands-on with Azure Arc technologies and [Azure Arc-enabled Kubernetes landing zone accelerator](https://aka.ms/ArcK8sLZSandbox)
- Accelerator for Proof-of-concepts or pilots
- Training solution for Azure Arc skills development
- Demo environment for customer presentations or events
- Rapid integration testing platform
- Infrastructure-as-code and automation template library for building hybrid cloud management solutions

## Azure Arc capabilities available in ArcBox for DevOps

### Azure Arc-enabled Kubernetes

ArcBox for DevOps deploys two Kubernetes clusters to give you multiple options for exploring Azure Arc-enabled Kubernetes capabilities and potential integrations.

- _**ArcBox-CAPI-Data**_ - A single-node Rancher K3s cluster which is then transformed to a [Cluster API](https://cluster-api.sigs.k8s.io/user/concepts.html) management cluster using the Cluster API Provider for Azure (CAPZ), and a workload cluster (_ArcBox-CAPI-Data_) is deployed onto the management cluster. The workload cluster is onboarded as an Azure Arc-enabled Kubernetes resource. ArcBox automatically deploys multiple [GitOps configurations](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#gitops-configurations) on this cluster for you, so you have an easy way to get started exploring GitOps capabilities.
- _**ArcBox-K3s**_ - One single-node Rancher K3s cluster running on an Azure virtual machine. This cluster is then connected to Azure as an Azure Arc-enabled Kubernetes resource. ArcBox provides the user with [PowerShell scripts](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#additional-optional-scenarios-on-the-arcbox-k3s-cluster) that can be manually run to apply GitOps configurations on this cluster.

### Sample applications

ArcBox for DevOps deploys two sample applications on the _ArcBox-CAPI-Data_ cluster. The cluster has multiple [GitOps configurations](https://docs.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2) that deploy and configure the sample apps. You can use your own fork of the [sample applications GitHub repo](https://github.com/microsoft/azure-arc-jumpstart-apps) to experiment with GitOps configuration flows.

The sample applications included in ArcBox are:

- [Hello-Arc](https://github.com/microsoft/azure-arc-jumpstart-apps/tree/main/hello-arc) - A simple Node.js web application. ArcBox will deploy **three Kubernetes pod replicas** of the _Hello-Arc_ application in the _hello-arc_ namespace onto the _ArcBox-CAPI-Data_ cluster.

- [Bookstore](https://release-v0-11.docs.openservicemesh.io/docs/getting_started/quickstart/manual_demo/) - A sample microservices Golang (Go) application. ArcBox will deploy the following **five different Kubernetes pods** as part of the Bookstore app.

  - _bookbuyer_ is an HTTP client making requests to bookstore.
  - _bookstore_ is a server, which responds to HTTP requests. It is also a client making requests to the _bookwarehouse_ service.
  - _bookwarehouse_ is a server and should respond only to _bookstore_.
  - _mysql_ is a MySQL database only reachable by _bookwarehouse_.
  - _bookstore-v2_ - this is the same container as the first bookstore, but for [Open Service Mesh (OSM)](#open-service-mesh-integration) traffic split scenario we will assume that it is a new version of the app we need to upgrade to.

The _bookbuyer_, _bookstore_, and _bookwarehouse_ pods will be in separate Kubernetes namespaces with the same names. _mysql_ will be in the _bookwarehouse_ namespace. _bookstore-v2_ will be in the _bookstore_ namespace.

### Open Service Mesh (OSM) integration

ArcBox deploys OSM by installing the [Open Service Mesh cluster extension](https://aka.ms/arc-osm-doc) on the _ArcBox-CAPI-Data_ cluster. Bookstore application namespaces will be added to OSM control plane. Each new pod in the service mesh will be injected with an Envoy sidecar container.

[OSM](https://openservicemesh.io/) is a lightweight, extensible, cloud-native service mesh that allows users to uniformly manage, secure, and get out-of-the-box observability features for highly dynamic microservice environments.

### GitOps

GitOps on Azure Arc-enabled Kubernetes uses [Flux](https://fluxcd.io/docs/). Flux is deployed by installing the [Flux extension](https://docs.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2#flux-cluster-extension) on the Kubernetes cluster. Flux is a tool for keeping Kubernetes clusters in sync with sources of configuration (such as Git repositories) and automating updates to the configuration when there is a new code to deploy. Flux provides support for common file sources (Git and Helm repositories, Buckets) and template types (YAML, Helm, and Kustomize).

ArcBox deploys five GitOps configurations onto the _ArcBox-CAPI-Data_ cluster:

- Cluster scope config to deploy [NGINX-ingress controller](https://kubernetes.github.io/ingress-nginx/).
- Cluster scope config to deploy the "Bookstore" application.
- Namespace scope config to deploy the "Bookstore" application Role-based access control (RBAC).
- Namespace scope config to deploy the "Bookstore" application open service mesh traffic split policies.
- Namespace scope config to deploy the "Hello-Arc" web application.

### Key Vault integration

The Azure Key Vault Provider for Secrets Store CSI Driver allows for the integration of Azure Key Vault as a secrets store with a Kubernetes cluster via a [CSI volume](https://kubernetes-csi.github.io/docs/).

ArcBox deploys Azure Key Vault during the automation scripts that run after logging into _ArcBox-Client_ for the first time. The automation configures the _ArcBox-CAPI-Data_ cluster to Azure Key Vault by deploying the [Azure Key Vault Secrets Provider extension](https://docs.microsoft.com/azure/azure-arc/kubernetes/tutorial-akv-secrets-provider).  

A self-signed certificate is synced from the Key Vault and configured as the secret for the Kubernetes ingress for the Bookstore and Hello-Arc applications.

### Microsoft Defender for Cloud / k8s integration

ArcBox deploys several management and operations services that work with ArcBox's Azure Arc resources. One of these services is Microsoft Defender for Cloud that is deployed by installing the [Defender extension](https://docs.microsoft.com/azure/defender-for-cloud/defender-for-containers-enable?tabs=aks-deploy-portal%2Ck8s-deploy-cli%2Ck8s-verify-cli%2Ck8s-remove-arc%2Caks-removeprofile-api#protect-arc-enabled-kubernetes-clusters) on your Kubernetes cluster in order to start collecting security related logs and telemetry.  

### Hybrid Unified Operations

ArcBox deploys several management and operations services that work with ArcBox's Azure Arc resources. These resources include an an Azure Automation account, an Azure Log Analytics workspace, an Azure Monitor workbook, Azure Policy assignments for deploying Kubernetes cluster monitoring and security extensions on the included clusters, Azure Policy assignment for adding tags to resources, and a storage account used for staging resources needed for the deployment automation.

## ArcBox Azure Consumption Costs

ArcBox resources generate Azure consumption charges from the underlying Azure resources including core compute, storage, networking, and auxiliary services. Note that Azure consumption costs vary depending on the region where ArcBox is deployed. Be mindful of your ArcBox deployments and ensure that you disable or delete ArcBox resources when not in use to avoid unwanted charges. Please see the [Jumpstart FAQ](https://aka.ms/Jumpstart-FAQ) for more information on consumption costs.

## Deployment Options and Automation Flow

ArcBox provides multiple paths for deploying and configuring ArcBox resources. Deployment options include:

- Azure portal
- ARM template via Azure CLI
- Azure Bicep
- HashiCorp Terraform

![Deployment flow diagram for ARM-based deployments](./deployment_flow.png)

![Deployment flow diagram for Terraform-based deployments](./deployment_flow_tf.png)

ArcBox uses an advanced automation flow to deploy and configure all necessary resources with minimal user interaction. The previous diagrams provide an overview of the deployment flow. A high-level summary of the deployment is:

- User deploys the primary ARM template (_azuredeploy.json_), Bicep file (_main.bicep_), or Terraform plan (_main.tf_). These objects contain several nested objects that will run simultaneously.
  - Client virtual machine ARM template/plan - deploys the Client Windows VM. This is a Windows Server VM that comes preconfigured with kubeconfig files to work with the two Kubernetes clusters, as well multiple tools such as VSCode to make working with ArcBox simple and easy.
  - Storage account template/plan - used for staging files in automation scripts.
  - Management artifacts template/plan - deploys Azure Log Analytics workspace, its required Solutions, and Azure Policy artifacts.
- User remotes into Client Windows VM, which automatically kicks off multiple scripts that:
  - Deploys OSM Extension on the _ArcBox-CAPI-Data_ cluster, create application namespaces and add namespaces to OSM control plane.
  - Applies five GitOps configurations on the _ArcBox-CAPI-Data_ cluster to deploy nginx-ingress controller, Hello Arc web application, Bookstore application and Bookstore RBAC/OSM configurations.
  - Creates certificate with DNS name _arcbox.devops.com_ and imports to Azure Key Vault.
  - Deploys Azure Key Vault Secrets Provider extension on the _ArcBox-CAPI-Data_ cluster.
  - Configures Ingress for Hello-Arc and Bookstore application with a self-signed TLS certificate from the Azure Key Vault.  
  - Deploy an Azure Monitor workbook that provides example reports and metrics for monitoring and visualizing ArcBox's various components.

## Prerequisites

- [Install or update Azure CLI to version 2.40.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- Login to AZ CLI using the ```az login``` command.

- Ensure that you have selected the correct subscription you want to deploy ArcBox to by using the ```az account list --query "[?isDefault]"``` command. If you need to adjust the active subscription used by Az CLI, follow [this guidance](https://docs.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription).

- ArcBox must be deployed to one of the following regions. **Deploying ArcBox outside of these regions may result in unexpected behavior or deployment errors.**

  - East US
  - East US 2
  - Central US
  - West US 2
  - North Europe
  - West Europe
  - France Central
  - UK South
  - Australia East
  - Japan East
  - Korea Central
  - Southeast Asia

- **ArcBox DevOps requires 30 B-series vCPUs** when deploying with default parameters such as VM series/size. Ensure you have sufficient vCPU quota available in your Azure subscription and the region where you plan to deploy ArcBox. You can use the below Az CLI command to check your vCPU utilization.

  ```shell
  az vm list-usage --location <your location> --output table
  ```

  ![Screenshot showing az vm list-usage](./az_vm_list_usage.png)

- Some Azure subscriptions may also have SKU restrictions that prevent deployment of specific Azure VM sizes. You can check for SKU restrictions used by ArcBox by using the below command:

  ```shell
  az vm list-skus --location <your location> --size Standard_D2s --all --output table
  az vm list-skus --location <your location> --size Standard_D4s --all --output table
  ```

  In the screenshots below, the first screenshot shows a subscription with no SKU restrictions in West US 2. The second shows a subscription with SKU restrictions on D4s_v4 in the East US 2 region. In this case, ArcBox will not be able to deploy due to the restriction.

  ![Screenshot showing az vm list-skus with no restrictions](./list_skus_unrestricted.png)

  ![Screenshot showing az vm list-skus with restrictions](./list_skus.png)

- Fork the [sample applications GitHub repo](https://github.com/microsoft/azure-arc-jumpstart-apps) to your own GitHub account. You will use this forked repo to make changes to the sample apps that will be applied using GitOps configurations. The name of your GitHub account is passed as a parameter to the template files so take note of your GitHub user name.

  ![Screenshot showing forking sample apps repo](./apps_fork01.png)

  ![Screenshot showing forking sample apps repo](./apps_fork02.png)

- The name of your GitHub account is passed as the _`githubUser`_ parameter to the template files so take note of your GitHub user name in your forked repo.

  ![Screenshot showing forking sample apps repo](./apps_fork03.png)

- Create Azure service principal (SP). To deploy ArcBox, an Azure service principal assigned with the _Owner_ role-based access control (RBAC) role is required. You can use Azure Cloud Shell (or other Bash shell), or PowerShell to create the service principal.

  - (Option 1) Create service principal using [Azure Cloud Shell](https://shell.azure.com/) or Bash shell with Azure CLI:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArcBoxSPN" --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    Output should look similar to this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArcBox",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
  
  - (Option 2) Create service principal using PowerShell. If necessary, follow [this documentation](https://learn.microsoft.com/powershell/azure/install-az-ps?view=azps-8.3.0) to install Azure PowerShell modules.

    ```PowerShell
    $account = Connect-AzAccount
    $spn = New-AzADServicePrincipal -DisplayName "<Unique SPN name>" -Role "Owner" -Scope "/subscriptions/$($account.Context.Subscription.Id)"
    echo "SPN App id: $($spn.AppId)"
    echo "SPN secret: $($spn.PasswordCredentials.SecretText)"
    ```

    For example:

    ```PowerShell
    $account = Connect-AzAccount
    $spn = New-AzADServicePrincipal -DisplayName "JumpstartArcBoxSPN" -Role "Owner" -Scope "/subscriptions/$($account.Context.Subscription.Id)"
    echo "SPN App id: $($spn.AppId)"
    echo "SPN secret: $($spn.PasswordCredentials.SecretText)"
    ```

    Output should look similar to this:

    ![Screenshot showing creating an SPN with PowerShell](./create_spn_powershell.png)

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password.**
    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

- [Generate a new SSH key pair](https://docs.microsoft.com/azure/virtual-machines/linux/create-ssh-keys-detailed) or use an existing one (Windows 10 and above now comes with a built-in ssh client). The SSH key is used to configure secure access to the Linux virtual machines that are used to run the Kubernetes clusters.

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

## Deployment Option 1: Azure portal

- Click the <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fazure_arc%2Fmain%2Fazure_jumpstart_arcbox%2FARM%2Fazuredeploy.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a> button and enter values for the the ARM template parameters.

  ![Screenshot showing Azure portal deployment of ArcBox](./portal_deploy01.png)

  ![Screenshot showing Azure portal deployment of ArcBox](./portal_deploy02.png)

  ![Screenshot showing Azure portal deployment of ArcBox](./portal_deploy03.png)

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/devops/#basic-troubleshooting).**

## Deployment Option 2: ARM template with Azure CLI

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- Edit the [azuredeploy.parameters.json](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_arcbox/ARM/azuredeploy.parameters.json) ARM template parameters file and supply some values for your environment.
  - _`sshRSAPublicKey`_ - Your SSH public key
  - _`spnClientId`_ - Your Azure service principal id
  - _`spnClientSecret`_ - Your Azure service principal secret
  - _`spnTenantId`_ - Your Azure tenant id
  - _`windowsAdminUsername`_ - Client Windows VM Administrator name
  - _`windowsAdminPassword`_ - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - _`logAnalyticsWorkspaceName`_ - Name for the ArcBox Log Analytics workspace
  - _`flavor`_ - Use the value "DevOps" to specify that you want to deploy the DevOps flavor of ArcBox
  - _`githubUser`_ - Specify the name of your GitHub account where you cloned the Sample Apps repo

  ![Screenshot showing example parameters](./parameters.png)

- Now you will deploy the ARM template. Navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_arcbox) and run the below command:

  ```shell
  az group create --name <Name of the Azure resource group> --location <Azure Region>
  az deployment group create \
  --resource-group <Name of the Azure resource group> \
  --template-file azuredeploy.json \
  --parameters azuredeploy.parameters.json 
  ```

  ![Screenshot showing az group create](./az_group_create.png)

  ![Screenshot showing az deployment group create](./az_deploy.png)

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/devops/#basic-troubleshooting).**

## Deployment Option 3: Azure Bicep deployment via Azure CLI

- Clone the Azure Arc Jumpstart repository

  ```shell
  git clone https://github.com/microsoft/azure_arc.git
  ```

- Upgrade to latest Bicep version

  ```shell
  az bicep upgrade
  ```

- Edit the [main.parameters.json](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_arcbox/bicep/main.parameters.json) template parameters file and supply some values for your environment.
  - _`sshRSAPublicKey`_ - Your SSH public key
  - _`spnClientId`_ - Your Azure service principal id
  - _`spnClientSecret`_ - Your Azure service principal secret
  - _`spnTenantId`_ - Your Azure tenant id
  - _`windowsAdminUsername`_ - Client Windows VM Administrator name
  - _`windowsAdminPassword`_ - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - _`logAnalyticsWorkspaceName`_ - Name for the ArcBox Log Analytics workspace
  - _`flavor`_ - Use the value "DevOps" to specify that you want to deploy the Devops flavor of ArcBox
  - _`deployBastion`_ - Set to true if you want to use Azure Bastion to connect to _ArcBox-Client_
  - _`githubUser`_ - Specify the name of your GitHub account where you cloned the Sample Apps repo

  ![Screenshot showing example parameters](./parameters.png)

- Now you will deploy the Bicep file. Navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_arcbox/bicep) and run the below command:

  ```shell
  az login
  az group create --name "<resource-group-name>"  --location "<preferred-location>"
  az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
  ```

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/devops/#basic-troubleshooting).**

## Deployment Option 4: HashiCorp Terraform Deployment

- Clone the Azure Arc Jumpstart repository

  ```shell
  git clone https://github.com/microsoft/azure_arc.git
  ```

- Download and install the latest version of Terraform [here](https://www.terraform.io/downloads.html)

  > **NOTE: Terraform 1.x or higher is supported for this deployment. Tested with Terraform v1.0.9+.**

- Create a `terraform.tfvars` file in the root of the terraform folder and supply some values for your environment.

  ```HCL
  azure_location      = "westus2"
  resource_group_name = "ArcBoxDevOps"
  spn_client_id       = "1414133c-9786-53a4-b231-f87c143ebdb1"
  spn_client_secret   = "fakeSecretValue123458125712ahjeacjh"
  spn_tenant_id       = "33572583-d294-5b56-c4e6-dcf9a297ec17"
  client_admin_ssh    = "C:/Temp/rsa.pub"
  deployment_flavor   = "DevOps"
  deploy_bastion      = false
  github_username     = "GitHubUser"
  ```

- Variable Reference:
  - **_`azure_location`_** - Azure location code (e.g. 'eastus', 'westus2', etc.)
  - **_`resource_group_name`_** - Resource group which will contain all of the ArcBox artifacts
  - **_`spn_client_id`_** - Your Azure service principal id
  - **_`spn_client_secret`_** - Your Azure service principal secret
  - **_`spn_tenant_id`_** - Your Azure tenant id
  - **_`client_admin_ssh`_** - SSH public key path, used for Linux VMs
  - **_`deployment_flavor`_** - Use the value "DevOps" to specify that you want to deploy the DevOps flavor of ArcBox
  - _`deployBastion`_ - Set to true if you want to use Azure Bastion to connect to _ArcBox-Client_
  - _`client_admin_username`_ - Admin username for Windows & Linux VMs
  - _`client_admin_password`_ - Admin password for Windows VMs. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - **_`workspace_name`_** - Unique name for the ArcBox Log Analytics workspace
  - _`github_username`_ - Specify the name of your GitHub account where you cloned the Sample Apps repo

  > **NOTE: Any variables in bold are required. If any optional parameters are not provided, defaults will be used.**

- Now you will deploy the Terraform file. Navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_arcbox/bicep) and run the commands below:

  ```shell
  terraform init
  terraform plan -out=infra.out
  terraform apply "infra.out"
  ```
  
- Example output from `terraform init`:

  ![terraform init](./terraform_init.png)

- Example output from `terraform plan -out=infra.out`:

  ![terraform plan](./terraform_plan.png)

- Example output from `terraform apply "infra.out"`:

  ![terraform plan](./terraform_apply.png)

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/devops/#basic-troubleshooting).**

## Start post-deployment automation

Once your deployment is complete, you can open the Azure portal and see the ArcBox resources inside your resource group. You will be using the _ArcBox-Client_ Azure virtual machine to explore various capabilities of ArcBox such as GitOps configurations and Key Vault integration. You will need to remotely access _ArcBox-Client_.

  ![Screenshot showing all deployed resources in the resource group](./deployed_resources.png)

   > **NOTE: For enhanced ArcBox security posture, RDP (3389) and SSH (22) ports are not open by default in ArcBox deployments. You will need to create a network security group (NSG) rule to allow network access to port 3389, or use [Azure Bastion](https://docs.microsoft.com/azure/bastion/bastion-overview) or [Just-in-Time (JIT)](https://docs.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage?tabs=jit-config-asc%2Cjit-request-asc) access to connect to the VM.**

### Connecting to the ArcBox Client virtual machine

Various options are available to connect to _ArcBox-Client_ VM, depending on the parameters you supplied during deployment.

- [RDP](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#connecting-directly-with-rdp) - available after configuring access to port 3389 on the _ArcBox-NSG_, or by enabling [Just-in-Time access (JIT)](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#connect-using-just-in-time-accessjit).
- [Azure Bastion](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#connect-using-azure-bastion) - available if ```true``` was the value of your _`deployBastion`_ parameter during deployment.

#### Connecting directly with RDP

By design, ArcBox does not open port 3389 on the network security group. Therefore, you must create an NSG rule to allow inbound 3389.

- Open the _ArcBox-NSG_ resource in Azure portal and click "Add" to add a new rule.

  ![Screenshot showing ArcBox-Client NSG with blocked RDP](./rdp_nsg_blocked.png)

  ![Screenshot showing adding a new inbound security rule](./nsg_add_rule.png)

- Specify the IP address that you will be connecting from and select RDP as the service with "Allow" set as the action. You can retrieve your public IP address by accessing [https://icanhazip.com](https://icanhazip.com) or [https://whatismyip.com](https://whatismyip.com).

  <img src="./nsg_add_rdp_rule.png" alt="Screenshot showing adding a new allow RDP inbound security rule" width="400">

  ![Screenshot showing all inbound security rule](./rdp_nsg_all_rules.png)

  ![Screenshot showing connecting to the VM using RDP](./rdp_connect.png)

#### Connect using Azure Bastion

- If you have chosen to deploy Azure Bastion in your deployment, use it to connect to the VM.

  ![Screenshot showing connecting to the VM using Bastion](./bastion_connect.png)

  > **NOTE: When using Azure Bastion, the desktop background image is not visible. Therefore some screenshots in this guide may not exactly match your experience if you are connecting to _ArcBox-Client_ with Azure Bastion.**

#### Connect using just-in-time access (JIT)

If you already have [Microsoft Defender for Cloud](https://docs.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage?tabs=jit-config-asc%2Cjit-request-asc) enabled on your subscription and would like to use JIT to access the Client VM, use the following steps:

- In the Client VM configuration pane, enable just-in-time. This will enable the default settings.

  ![Screenshot showing the Microsoft Defender for cloud portal, allowing RDP on the client VM](./jit_allowing_rdp.png)

  ![Screenshot showing connecting to the VM using RDP](./rdp_connect.png)

  ![Screenshot showing connecting to the VM using JIT](./jit_connect_rdp.png)

#### The Logon scripts

- Once you log into the _ArcBox-Client_ VM, multiple automated scripts will open and start running. These scripts usually take 10-20 minutes to finish, and once completed, the script windows will close automatically. At this point, the deployment is complete.

  ![Screenshot showing ArcBox-Client](./automation.png)

- Deployment is complete! Let's begin exploring the features of Azure Arc-enabled Kubernetes with ArcBox for DevOps!

  ![Screenshot showing complete deployment](./arcbox_complete.png)

  ![Screenshot showing ArcBox resources in Azure portal](./rg_arc.png)

## Using ArcBox

After deployment is complete, it's time to start exploring ArcBox. Most interactions with ArcBox will take place either from Azure itself (Azure portal, CLI, or similar) or from inside the _ArcBox-Client_ virtual machine. When remoted into the VM, here are some things to try:

### Key Vault integration

 ArcBox uses Azure Key Vault to store the TLS certificate used by the sample Hello-Arc and OSM applications. Here are some things to try to explore this integration with Key Vault further:

- Configure Azure Key Vault to allow your access to certificates.

  - Navigate to the deployed Key Vault in the Azure portal, open the "Access Policies" blade, and click on Create.

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault01.png)

  - Under "Certificate Permissions" check the "Get" and "List" permissions. Click Next.

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault02.png)

  - Search for your user name and select it. Click Next.

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault03.png)

  - You can skip adding the Application. Click Next.

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault04.png)

  - Review the configuration and click Create.

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault05.png)

    ![Screenshot showing Azure Arc extensions ](./capi_keyvault06.png)

- Open the extension tab section of the _ArcBox-CAPI-Data_ cluster resource in the Azure portal. You can now see that Azure Key Vault Secrets Provider, Flux (GitOps), and Open Service Mesh extensions are installed.

  ![Screenshot showing Azure Arc extensions ](./capi_keyvault07.png)

- Click on the _CAPI Hello-Arc_ icon on the desktop to open Hello-Arc application and validate the Ingress certificate _arcbox.devops.com_ used from the Key Vault.

  ![Screenshot showing Hello-Arc desktop Icon](./capi_keyvault08.png)

  ![Screenshot showing Hello-Arc App](./capi_keyvault09.png)

- Validate that Key Vault certificate is being used by comparing the certificate thumbprint reported in the browser with your certificate thumbprint in Key Vault. Click on the lock icon and then select "Connection is secure".

  ![Screenshot showing Hello-Arc certificate](./capi_keyvault10.png)

- Click on the certificate icon to view the thumbprint of the certificate.

  ![Screenshot showing Hello-Arc certificate](./capi_keyvault11.png)

- Browse to the certificate "ingress-cert" in Key Vault to view and compare the thumbprint.

  ![Screenshot showing Hello-Arc certificate](./capi_keyvault12.png)

### GitOps configurations

ArcBox deploys multiple GitOps configurations on the _ArcBox-CAPI-Data_ workload cluster. Click on the GitOps tab of the cluster to explore these configurations:

- You can now see the five GitOps configurations on the _ArcBox-CAPI-Data_ cluster.

  - config-nginx to deploy NGINX-ingress controller.
  - config-bookstore to deploy the "Bookstore" application.
  - config-bookstore-rbac to deploy the "Bookstore" application RBAC.
  - config-bookstore-osm to deploy the "Bookstore" application open service mesh traffic split policy.
  - config-helloarc to deploy the "Hello Arc" web application.

  ![Screenshot showing Azure Arc GitOps configurations](./capi_gitops01.png)

- We have installed the “Tab Auto Refresh” extension for the browser. This will help you to show the real-time changes on the application in an automated way. Open "CAPI Hello-Arc" application to configure the “Tab Auto Refresh” extension for the browser to refresh every 3 seconds.

  ![Screenshot showing Hello-Arc app](./capi_gitops02.png)

  ![Screenshot showing Tab Auto Refresh ](./capi_gitops03.png)

- To show the GitOps flow for the Hello-Arc application open two side-by-side windows.

  - A browser window with the open Hello-Arc application _`https://arcbox.devops.com/`_ URL.
  - PowerShell running the command _`kubectl get pods -n hello-arc -w`_ command.
  
    The result should look like this:

    ![Screenshot showing Hello-Arc app and shell](./capi_gitops04.png)

- In your fork of the “Azure Arc Jumpstart Apps” GitHub repository, open the _`hello_arc.yaml`_ file (_`/hello-arc/yaml/hello_arc.yaml`_), change the text under the “MESSAGE” section and commit the change.
  
    ![Screenshot showing hello-arc repo](./capi_gitops05.png)
  
- Upon committing the changes, notice how the Kubernetes pods rolling upgrade will begin. Once the pods are up & running, refresh the browser, the new “Hello Arc” application version window will show the new message, showing the rolling upgrade is completed and the GitOps flow is successful.
  
    ![Screenshot showing Hello-Arc app and shell GitOps](./capi_gitops06.png)

### RBAC configurations

ArcBox deploys Kubernetes RBAC configuration on the bookstore application for limiting access to deployed Kubernetes resources. You can explore this configuration by following these steps:

- Show Kubernetes RBAC Role and Role binding applied using GitOps Configuration.

  - Review the [RBAC configuration](https://github.com/microsoft/azure-arc-jumpstart-apps/blob/main/k8s-rbac-sample/namespace/namespacerole.yaml) applied to the _ArcBox-CAPI-Data_ cluster.  
  
  - Show the bookstore namespace Role and Role Binding.
  
    ```shell
    kubectl --namespace bookstore get role
    kubectl --namespace bookstore get rolebindings.rbac.authorization.k8s.io
    ```

    ![Screenshot showing bookstore RBAC get Role](./capi_rbac01.png)

  - Validate the RBAC role to get the pods as user "Jane".

    ```shell
    kubectl --namespace bookstore get pods --as=jane
    ```

    ![Screenshot showing bookstore RBAC get pods](./capi_rbac02.png)

  - To test the RBAC role assignment, as user "Jane", try to delete the pods. As you can see, the operation fails since Jane is assigned with the role of "pod-reader".
  
    The "pod-reader" role only allows _get_, _watch_ and _list_ Kubernetes operations permissions in the _bookstore_ namespace but does not allow for _delete_ operations permissions.

      ```shell
      $pod=kubectl --namespace bookstore get pods --selector=app=bookstore --output="jsonpath={.items..metadata.name}"
      kubectl --namespace bookstore delete pods $pod --as=jane
      ```

      ![Screenshot showing bookstore RBAC delete pods](./capi_rbac03.png)

  - Optionally, you can test the access using [auth can-i](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access) command to validate RBAC access.
  
    ```shell
    kubectl --namespace bookstore auth can-i get pods --as=jane
    kubectl --namespace bookstore auth can-i delete pods --as=jane
    ```
  
    ![Screenshot showing bookstore RBAC auth can-i pods](./capi_rbac04.png)

### OSM Traffic Split using GitOps

ArcBox uses a GitOps configuration on the OSM bookstore application to split traffic to the bookstore APIs using weighted load balancing. Follow these steps to explore this capability further:

  ![Diagram of OSM bookstore app architecture](./osm_bookstore_architecture.png)

  ![Diagram of OSM bookstore app traffic split](./smi_traffic_split.png)

- Review the [OSM Traffic Split Policy](https://github.com/microsoft/azure-arc-jumpstart-apps/blob/main/bookstore/osm-sample/traffic-split.yaml) applied to the _ArcBox-CAPI-Data_ cluster  

- To show OSM traffic split, open below windows.

  - PowerShell running the below commands to show the bookbuyer pod logs.
  
    ```powershell
    $pod=kubectl --namespace bookbuyer get pods --selector=app=bookbuyer --output="jsonpath={.items..metadata.name}"
    kubectl --namespace bookbuyer logs $pod bookbuyer -f | Select-String Identity:
    ```

  - Click on the _CAPI Bookstore_ icon on the desktop to open bookstore applications.

    ![Screenshot showing Bookstore desktop Icon](./capi_osm01.png)

    ![Screenshot showing Bookstore Apps](./capi_osm02.png)

  - Move the browser tabs and PowerShell window, so the end result should look like this:
  
    ![Screenshot showing Bookstore Apps and shell 01](./capi_osm03.png)

  - The count for the books sold from the bookstore-v2 browser window should remain at 0. This is because the current traffic split policy is configured as weighted 100 for bookstore as well because the bookbuyer client is sending traffic to the bookstore service and no application is sending requests to the bookstore-v2 service.

    ![Screenshot showing Bookstore apps and shell 02](./capi_osm04.png)

- In your fork of the “Azure Arc Jumpstart Apps” GitHub repository, open the _`traffic-split.yaml`_ file (_`/bookstore/osm-sample/traffic-split.yaml`_), update the bookstore weight to "75" and bookstore-v2 weight to "25" and commit the change.

  ![Screenshot showing Bookstore repo Traffic split 01](./capi_osm05.png)

- Wait for the changes to propagate and observe the counters increment for bookstore and bookstore-v2 as well.

  We have updated the Service Mesh Interface (SMI) Traffic Split policy to direct 75 percent of the traffic sent to the root bookstore service and 25 percent to the bookstore-v2 service by modifying the weight fields for the bookstore-v2 backend. Also, observe the changes on the bookbuyer pod logs in the PowerShell window.

  ![Screenshot showing Bookstore apps and shell GitOps and OSM 01](./capi_osm06.png)

- You can verify the traffic split policy by running the below command and examine the Backends properties.

  ```shell
  kubectl describe trafficsplit bookstore-split -n bookstore
  ```

  ![Screenshot showing Bookstore repo Traffic split 02](./capi_osm07.png)

- In your fork of the “Azure Arc Jumpstart Apps” GitHub repository, open the _`traffic-split.yaml`_ file (_`/bookstore/osm-sample/traffic-split.yaml`_), update the bookstore weight to "0" and bookstore weight to "100" and commit the change.

  ![Screenshot showing Bookstore repo Traffic split 02](./capi_osm08.png)

- Wait for the changes to propagate and observe the counters increment for bookstore-v2 and freeze for bookstore. Also, observe pod logs to validate bookbuyer is sending all the traffic to bookstore-v2.

  ![Screenshot showing Bookstore apps and shell GitOps and OSM 02](./capi_osm09.png)

- Optional, you may want to reset the traffic split demo to start over with the counters at zero. If so, follow the below steps to reset the bookstore counters.
  
  - Browse to the _ResetBookstore.ps1_ script placed under _C:\ArcBox\GitOps_. The script will:
    - Connect to _ArcBox-CAPI-Data_ cluster
    - Deploy a Kubernetes Ingress resource for each bookstore apps reset API
    - Invoke bookstore apps rest API to reset the counter
  
  - Before we run the reset script, did you update the Traffic split on GitHub? In your fork of the “Azure Arc Jumpstart Apps” GitHub repository, open the _`traffic-split.yaml`_ file (_`/bookstore/osm-sample/traffic-split.yaml`_), update the bookstore weight to "100" and bookstore weight to "0" and commit the change.

    ![Screenshot showing Bookstore repo Traffic split rest](./capi_osm10.png)

  - Right click _ResetBookstore.ps1_ script and select Run with PowerShell to execute the script.
  
    ![Screenshot showing Script execution reset](./capi_osm11.png)

  - Counters for Bookbuyer, Bookstore-v1, and Bookstore-v2 will reset.

    ![Screenshot showing Bookstore apps and shell GitOps and OSM reset](./capi_osm12.png)

### Microsoft Defender for Cloud

After you have finished the deployment of ArcBox, you can verify that Microsoft Defender for Cloud is working properly and alerting on security threats by running the below command to simulate an alert on the _ArcBox-CAPI-Data_ workload cluster:

  ```bash
  kubectx arcbox-capi
  kubectl get pods --namespace=asc-alerttest-662jfi039n
  ```

After a period of time (typically less than an hour), Microsoft Defender for Cloud will detect this event and trigger a security alert that you will see in the Azure portal under Microsoft Defender for Cloud's security alerts and also on the security tab of your Azure Arc-enabled Kubernetes cluster.

![Screenshot security alert in Microsoft Defender for Cloud](./defender_alert01.png)

![Screenshot security alert in Microsoft Defender for Cloud](./defender_alert02.png)

![Screenshot security alert in Microsoft Defender for Cloud](./defender_alert03.png)

> **NOTE: This feature requires Microsoft Defender for Cloud to be [enabled on your Azure subscription](https://docs.microsoft.com/azure/defender-for-cloud/enable-enhanced-security).**

### Additional optional scenarios on the _ArcBox-K3s_ cluster

Optionally, you can explore additional GitOps and RBAC scenarios in a manual fashion using the _ArcBox-K3s_ cluster. When remoted into the _ArcBox-Client_ virtual machine, here are some things to try:

- Browse to the Azure portal and notice how currently there is no GitOps configuration and Flux extension installed on the _ArcBox-K3s_ cluster.
  
  ![Screenshot showing K3s cluster extensions](./k3s_gitops01.png)

  ![Screenshot showing K3s cluster GitOps](./k3s_gitops02.png)

- Deploy multiple GitOps configurations on the _ArcBox-K3s_ cluster.

  - Browse to the _K3sGitOps.ps1_ script placed under _C:\ArcBox\GitOps_. The script will:
    - Log in to your Azure subscription using your previously created service principal credentials
    - Connect to _ArcBox-K3s_ cluster
    - Create the GitOps configurations to install the Flux extension as well deploying the NGINX ingress controller and the “Hello Arc” application
    - Create a certificate with _arcbox.k3sdevops.com_ DNS name and import to Azure Key Vault
    - Deploy the Azure Key Vault k8s extension instance
    - Create Kubernetes _SecretProviderClass_ to fetch the secrets from Azure Key Vault
    - Deploy a Kubernetes Ingress resource referencing the Secret created by the CSI driver
    - Create an icon for the Hello-Arc application on the desktop
  
  - Optionally, you can open the script with VSCode to review.
  
    ![Screenshot showing Script VSCode](./k3s_gitops03.png)

    ![Screenshot showing Script VSCode](./k3s_gitops04.png)
  
  - Right click _K3sGitOps.ps1_ script and select Run with PowerShell to execute the script. This will take about 5-10 minutes to run.
  
    ![Screenshot showing Script execution](./k3s_gitops05.png)

  - You can verify that Azure Key Vault Secrets Provider and the Flux (GitOps) extensions are now installed under the extension tab section of the _ArcBox-K3s_ cluster resource in the Azure portal.

    ![Screenshot showing K3s cluster extensions](./k3s_gitops06.png)

  - You can verify below GitOps configurations applied on the _ArcBox-K3s_ cluster.
  
    - config-nginx to deploy NGINX-ingress controller
    - config-helloarc to deploy the "Hello Arc" web application
  
    ![Screenshot showing Azure Arc GitOps configurations](./k3s_gitops07.png)

  - Click on the _K3s Hello-Arc_ icon on the desktop to open Hello-Arc application and validate the Ingress certificate _arcbox.k3sdevops.com_ used from Key Vault.
  
    ![Screenshot showing Hello-Arc App Icon](./k3s_gitops08.png)

    ![Screenshot showing Hello-Arc App](./k3s_gitops09.png)
  
  - To show the GitOps flow for the Hello-Arc application open two side-by-side windows.

    - A browser window with the open Hello-Arc application _`https://k3sdevops.devops.com/`_ URL.
    - PowerShell running the command _`kubectl get pods -n hello-arc -w`_ command.
  
        ```shell
        kubectx arcbox-k3s
        kubectl get pods -n hello-arc -w
        ```

      The result should look like this:
  
      ![Screenshot showing Hello-Arc app and shell](./k3s_gitops10.png)
  
    - In your fork of the “Azure Arc Jumpstart Apps” GitHub repository, open the _`hello_arc.yaml`_ file (_`/hello-arc/yaml/hello_arc.yaml`_). Change the replica to 2 and text under the “MESSAGE” section and commit the change.

      ![Screenshot showing hello-arc repo](./k3s_gitops11.png)

    - Upon committing the changes, notice how the Kubernetes pods rolling upgrade will begin. Once the pods are up and running, refresh the browser, the new “Hello Arc” application version window will show the new message, showing the rolling upgrade is completed and the GitOps flow is successful.

      ![Screenshot showing Hello-Arc app and shell GitOps](./k3s_gitops12.png)

- Deploy Kubernetes RBAC configuration on the Hello-Arc application to limit access to deployed Kubernetes resources.

  - Browse to the _K3sRBAC.ps1_ script placed under _C:\ArcBox\GitOps_. The script will:
    - Log in to your Azure subscription using your previously created service principal credentials
    - Connect to _ArcBox-K3s_ cluster
    - Create the GitOps configurations to deploy the RBAC configurations for _hello-arc_ namespace and cluster scope

  - Right click _K3sGitOps.ps1_ script and select Run with PowerShell to execute the script.
  
    ![Screenshot showing Hello-Arc App](./k3s_rbac01.png)

  - You can can verify below GitOps configurations applied on the _ArcBox-K3s_ cluster.
  
    - _config-helloarc-rbac_ to deploy the _hello-arc_ namespace RBAC.
  
      ![Screenshot showing Azure Arc GitOps RBAC](./k3s_rbac02.png)

  - Show the _hello-arc_ namespace Role and Role Binding.
  
    ```shell
    kubectx arcbox-k3s
    kubectl --namespace hello-arc get role
    kubectl --namespace hello-arc get rolebindings.rbac.authorization.k8s.io
    ```

    ![Screenshot showing hello-arc RBAC get pods](./k3s_rbac03.png)

  - Validate the namespace RBAC role to get the pods as user Jane.

    ```shell
    kubectl --namespace hello-arc get pods --as=jane
    ```

    ![Screenshot showing hello-arc RBAC get pods](./k3s_rbac04.png)

  - To test the RBAC role assignment, as user "Jane", try to delete the pods. As you can see, the operation fails since Jane is assigned with the role of "pod-reader".

    The "pod-reader" role only allows _get_, _watch_ and _list_ Kubernetes operations permissions in the _hello-arc_ namespace but does not allow for _delete_ operations permissions.

    ```powershell
    $pod=kubectl --namespace hello-arc get pods --selector=app=hello-arc --output="jsonpath={.items..metadata.name}"
    kubectl --namespace hello-arc delete pods $pod --as=jane
    ```

    ![Screenshot showing hello-arc RBAC delete pods](./k3s_rbac05.png)

  - Show the Cluster Role and Role Binding.
  
    ```shell
    kubectl get clusterrole | Select-String secret-reader
    kubectl get clusterrolebinding | Select-String read-secrets-global
    ```

    ![Screenshot showing hello-arc RBAC get pods](./k3s_rbac06.png)

  - Validate the cluster role to get the secrets as user Dave.

    ```shell
    kubectl get secrets --as=dave
    ```

    ![Screenshot showing hello-arc RBAC get pods](./k3s_rbac07.png)

  - Test the RBAC role assignment to check if Dave can create the secrets. The operation should fail, as the user Dave is assigned to the role of secret-reader. The secret-reader role only allows get, watch and list permissions.

    ```shell
    kubectl create secret generic arcbox-secret --from-literal=username=arcdemo --as=dave
    ```

    ![Screenshot showing hello-arc RBAC delete pods](./k3s_rbac08.png)

### ArcBox Azure Monitor workbook

Open the [ArcBox Azure Monitor workbook documentation](https://azurearcjumpstart.io/azure_jumpstart_arcbox/workbook/flavors/DevOps) and explore the visualizations and reports of hybrid cloud resources.

  ![Screenshot showing Azure Monitor workbook usage](./workbook.png)

### Included tools

The following tools are including on the _ArcBox-Client_ VM.

- kubectl, kubectx, helm
- Chocolatey
- Visual Studio Code
- Putty
- 7zip
- Terraform
- Git
- ZoomIt

### Next steps
  
ArcBox is a sandbox that can be used for a large variety of use cases, such as an environment for testing and training or a kickstarter for proof of concept projects. Ultimately, you are free to do whatever you wish with ArcBox. Some suggested next steps for you to try in your ArcBox are:

- Use the included kubectx to switch contexts between the two Kubernetes clusters
- Deploy new GitOps configurations with Azure Arc-enabled Kubernetes
- Build policy initiatives that apply to your Azure Arc-enabled resources
- Write and test custom policies that apply to your Azure Arc-enabled resources
- Incorporate your own tooling and automation into the existing automation framework
- Build a certificate/secret/key management strategy with your Azure Arc resources

## Clean up the deployment

To clean up your deployment, simply delete the resource group using Azure CLI or Azure portal.

```shell
az group delete -n <name of your resource group>
```

![Screenshot showing az group delete](./az_delete.png)

![Screenshot showing group delete from Azure portal](./portal_delete.png)

## Basic Troubleshooting

Occasionally deployments of ArcBox may fail at various stages. Common reasons for failed deployments include:

- Invalid service principal id, service principal secret or service principal Azure tenant ID provided in _azuredeploy.parameters.json_ file.
- Invalid SSH public key provided in _azuredeploy.parameters.json_ file.
  - An example SSH public key is shown here. Note that the public key includes "ssh-rsa" at the beginning. The entire value should be included in your _azuredeploy.parameters.json_ file.

      ![Screenshot showing SSH public key example](./ssh_example.png)

- Not enough vCPU quota available in your target Azure region - check vCPU quota and ensure you have at least 52 available. See the [prerequisites](#prerequisites) section for more details.
- Target Azure region does not support all required Azure services - ensure you are running ArcBox in one of the supported regions listed in the above section "ArcBox Azure Region Compatibility".

### Exploring logs from the _ArcBox-Client_ virtual machine

Occasionally, you may need to review log output from scripts that run on the _ArcBox-Client_, _ArcBox-CAPI-MGMT_ or _ArcBox-K3s_ virtual machines in case of deployment failures. To make troubleshooting easier, the ArcBox deployment scripts collect all relevant logs in the _C:\ArcBox\Logs_ folder on _ArcBox-Client_. A short description of the logs and their purpose can be seen in the list below:

| Log file | Description |
| ------- | ----------- |
| _C:\ArcBox\Logs\Bootstrap.log_ | Output from the initial bootstrapping script that runs on _ArcBox-Client_. |
| _C:\ArcBox\Logs\DevOpsLogonScript.log_ | Output of _DevOpsLogonScript.ps1_ which configures the Hyper-V host and guests and onboards the guests as Azure Arc-enabled servers. |
| _C:\ArcBox\Logs\installCAPI.log_ | Output from the custom script extension which runs on _ArcBox-CAPI-MGMT_ and configures the Cluster API for Azure cluster and onboards it as an Azure Arc-enabled Kubernetes cluster. If you encounter ARM deployment issues with _ubuntuCapi.json_ then review this log. |
| _C:\ArcBox\Logs\installK3s.log_ | Output from the custom script extension which runs on _ArcBox-K3s_ and configures the Rancher cluster and onboards it as an Azure Arc-enabled Kubernetes cluster. If you encounter ARM deployment issues with _ubuntuRancher.json_ then review this log. |
| _C:\ArcBox\Logs\MonitorWorkbookLogonScript.log_ | Output from _MonitorWorkbookLogonScript.ps1_ which deploys the Azure Monitor workbook. |
| _C:\ArcBox\Logs\K3sGitOps.log_ | Output from K3sGitOps.ps1 which deploys GitOps configurations on _ArcBox-K3s_. This script must be manually run by the user. Therefore the log is only present if the user has run the script. |
| _C:\ArcBox\Logs\K3sRBAC.log_ | Output from K3sRBAC.ps1 which deploys GitOps RBAC configurations on _ArcBox-K3s_. This script must be manually run by the user. Therefore the log is only present if the user has run the script. |

  ![Screenshot showing ArcBox logs folder on ArcBox-Client](./troubleshoot_logs.png)

### Exploring installation logs from the Linux virtual machines

In the case of a failed deployment, pointing to a failure in either the _ubuntuRancherDeployment_ or the _ubuntuCAPIDeployment_ Azure deployments, an easy way to explore the deployment logs is available directly from the associated virtual machines.

- Depending on which deployment failed, connect using SSH to the associated virtual machine public IP:
  - _ubuntuCAPIDeployment_ - _ArcBox-CAPI-MGMT_ virtual machine.
  - _ubuntuRancherDeployment_ - _ArcBox-K3s_ virtual machine.

    ![Screenshot showing ArcBox-CAPI-MGMT virtual machine public IP](./arcbox_capi_mgmt_vm_ip.png)

    ![Screenshot showing ArcBox-K3s virtual machine public IP](./arcbox_k3s_vm_ip.png)

    > **NOTE: Port 22 is not open by default in ArcBox deployments. You will need to [create an NSG rule](https://azurearcjumpstart.io/azure_jumpstart_arcbox/DevOps/#connecting-directly-with-rdp) to allow network access to port 22, or use Azure Bastion or JIT to connect to the VM.**

- As described in the message of the day (motd), depending on which virtual machine you logged into, the installation log can be found in the _jumpstart_logs_ folder. This installation logs can help determine the root cause for the failed deployment.
  - _ArcBox-CAPI-MGMT_ log path: _jumpstart_logs/installCAPI.log_
  - _ArcBox-K3s_ log path: _jumpstart_logs/installK3s.log_

      ![Screenshot showing login and the message of the day](./login_motd.png)

- From the screenshot below, looking at _ArcBox-CAPI-MGMT_ virtual machine CAPI installation log using the `cat jumpstart_logs/installCAPI.log` command, we can see the _az login_ command failed due to bad service principal credentials.

  ![Screenshot showing cat command for showing installation log](./cat_command.png)

  ![Screenshot showing az login error](./az_login_error.png)

- You might randomly get a similar error in the _InstallCAPI.log_ to `Error from server (InternalError): error when creating "template.yaml": Internal error occurred: failed calling webhook "default.azuremachinetemplate.infrastructure.cluster.x-k8s.io": failed to call webhook: Post "https://capz-webhook-service.capz-system.svc:443/mutate-infrastructure-cluster-x-k8s-io-v1beta1-azuremachinetemplate?timeout=10s": EOF`. This is an issue we are currently investigating. To resolve please redeploy ArcBox.

If you are still having issues deploying ArcBox, please [submit an issue](https://github.com/microsoft/azure_arc/issues/new/choose) on GitHub and include a detailed description of your issue, the Azure region you are deploying to, the flavor of ArcBox you are trying to deploy. Inside the _C:\ArcBox\Logs_ folder you can also find instructions for uploading your logs to an Azure storage account for review by the Jumpstart team.

### Known issues

- Microsoft Defender is not enabled for _ArcBox-CAPI-Data_ connected cluster.
