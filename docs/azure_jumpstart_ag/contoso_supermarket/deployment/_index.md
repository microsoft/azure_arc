---
type: docs
weight: 100
toc_hide: true
---

# Jumpstart Agora - Contoso Supermarket deployment guide

## Overview

Jumpstart Agora provides a simple deployment process using Azure Bicep and PowerShell that minimizes user interaction. This automation automatically configures the Contoso Supermarket scenario environment, including the infrastructure, the Contoso-Supermarket applications, CI/CD artifacts, and observability components. The diagram below details the high-level architecture that is deployed and configured as part of the automation.

![Architecture diagram](./img/architecture_diagram.png)

Deploying the "Contoso Supermarket" scenario consists of the following steps (once prerequisites are met).
  
  1. Deploy infrastructure - User deploys a Bicep file that creates the infrastructure in an Azure resource group.
  2. Bicep template deploys multiple Azure resources including the Client virtual machine.
  3. Client VM uses custom script extension to run the Bootstrap PowerShell script which initializes the environment.
  4. Bootstrap script injects the Logon script to Client VM.
  5. User logs in to the Agora-VM-Client Azure virtual machine.
  6. After login the Agora-VM-Client PowerShell scripts automatically run that configure the applications and CI/CD. These scripts will take some time to run.

Once automation is complete, users can immediately start enjoying the Contoso Supermarket experience.

![Deployment flow architecture diagram](./img/deployment_flow.png)

## Prerequisites

- Fork the [_jumpstart-agora-apps_ repo](https://github.com/microsoft/jumpstart-agora-apps) into your own GitHub account. If you do not have a GitHub account, visit [this link](https://github.com/join) to create one.

  - Open the [_jumpstart-Agora-apps_ repo](https://github.com/microsoft/jumpstart-agora-apps) while signed into your GitHub account and click the "Fork" button in the upper-right corner.

    ![Screenshot showing how to fork the Jumpstart Agora Apps repo](./img/fork_repo1.png)
  
  - Use the default settings to create your fork. Ensure that your user is selected in the dropdown and then click the "Create Fork" button.

    ![Screenshot showing how to fork the Jumpstart Agora Apps repo](./img/fork_repo2.png)

- Configure a GitHub fine-grained personal access token (PAT) with permissions to modify __only__ the Jumpstart Agora Apps repo that you forked.

  > __NOTE: The PAT token only needs to be created once as part of the prerequisites. Your token can be reused on subsequent deployments for as long as the token is valid. Therefore you should only need to complete these steps before your first deployment. If your token expires, simply follow the steps to create another.__

  - In the top right of the GitHub website, click on your user icon and then click "Settings".

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT0.png)

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT1.png)

  - In the left menu navigation click on "Developer settings".

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT2.png)

  - Under "Personal access tokens" select "Fine-grained tokens".

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT3.png)

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT4.png)

  - Give your token a name and select an expiry period.

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT5.png)

  - Under "Repository access" select "Only select repositories" and then choose the _jumpstart-agora-apps_ repo that you forked in the previous steps.

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT6.png)

  - Assign the "Read and write" permissions for your fork of the _jumpstart-agora-apps_ repo. The PAT should have read and write permissions for the following operations: Actions, Administration, Contents, Pull Requests, Secrets, and Workflows.

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT7.png)

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT8.png)

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT9.png)

  - Once the correct permissions are assigned click the "Generate token" button.

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT10.png)

  - Copy the token value to a temporary location such as in Notepad. You will need this value in a later step.

    ![Screenshot showing how to create the GitHub PAT](./img/github_PAT11.png)

    > __NOTE: GitHub fine-grained access tokens are a beta feature of GitHub and may be subject to change in user experience or functionality.__
    > __NOTE: The token shown in the above screenshot is a placeholder value for example purposes only and not a working token.__

- [Install or update Azure CLI to version 2.49.0 or above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the following command to check your current installed version.

    ```shell
    az --version
    ```

- Login to Azure CLI using the ```az login``` command.

- Ensure that you have selected the correct subscription you want to deploy Agora to by using the ```az account list --query "[?isDefault]"``` command. If you need to adjust the active subscription used by Az CLI, follow [this guidance](https://docs.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription).

- Agora must be deployed to one of the following regions. __Deploying Agora outside of these regions may result in unexpected results or deployment errors.__

  - East US
  - East US 2
  - West US 2
  - North Europe
  - West Europe

- __Agora requires 40 Ds-series vCPUs__. Ensure you have sufficient vCPU quota available in your Azure subscription and the region where you plan to deploy Agora. You can use the below Az CLI command to check your vCPU utilization.

  ```shell
  az vm list-usage --location <your location> --output table
  ```

  ![Screenshot showing az vm list-usage](./img/az_vm_list_usage.png)

- Create Azure service principal (SP). An Azure service principal assigned with the _Owner_ Role-based access control (RBAC) role is required. You can use Azure Cloud Shell (or other Bash shell), or PowerShell to create the service principal.

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
    az ad sp create-for-rbac -n "JumpstartAgoraSPN" --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    Output should look similar to this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartAgora",
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
    echo "SPN tenant: $($account.Context.Tenant.Id)"
    ```

    For example:

    ```PowerShell
    $account = Connect-AzAccount
    $spn = New-AzADServicePrincipal -DisplayName "JumpstartAgoraSPN" -Role "Owner" -Scope "/subscriptions/$($account.Context.Subscription.Id)"
    echo "SPN App id: $($spn.AppId)"
    echo "SPN secret: $($spn.PasswordCredentials.SecretText)"
    ```

    Output should look similar to this:

    ![Screenshot showing creating an SPN with PowerShell](./img/create_spn_powershell.png)

    > __NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct secret.__
    > __NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)__

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

- Clone the Azure Arc Jumpstart repository

  ```shell
  git clone https://github.com/microsoft/azure_arc.git
  ```

## Deployment: Bicep deployment via Azure CLI

- Upgrade to latest Bicep version

  ```shell
  az bicep upgrade
  ```

- Edit the [main.parameters.json](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_ag/bicep/main.parameters.json) template parameters file and supply some values for your environment.
  - _`sshRSAPublicKey`_ - Your SSH public key
  - _`spnClientId`_ - Your Azure service principal id
  - _`spnClientSecret`_ - Your Azure service principal secret
  - _`spnTenantId`_ - Your Azure tenant id
  - _`windowsAdminUsername`_ - Client Windows VM Administrator name
  - _`windowsAdminPassword`_ - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - _`deployBastion`_ - Option to deploy using Azure Bastion instead of traditional RDP. Set to true or false.
  - _`githubUser`_ - The name of the user account on GitHub where you have forked the [_jumpstart-agora-apps_ repo](https://github.com/microsoft/jumpstart-agora-apps)
  - _`githubPAT`_ - The GitHub PAT token that you created as part of the prerequisites.

  ![Screenshot showing example parameters](./img/parameters_bicep.png)

- Now you will deploy the Bicep file. Navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_ag/bicep) and run the below command:

  ```shell
  az login
  az group create --name "<resource-group-name>"  --location "<preferred-location>"
  az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
  ```

    > __NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/troubleshooting/).__

## Deployment via Azure Developer CLI

Jumpstart Agora provides a feature that allows users to deploy with the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview). Follow these steps to try this feature in your subscription.

- Follow to install guide for the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-linux) for your environment.

  > __NOTE: PowerShell is required for using azd with Jumpstart Agora. If you are running in a Linux environment be sure that you have [PowerShell for Linux](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3) installed.__

- Login with azd using ```azd auth login``` which will open a browser for interactive login.

  ![Screenshot showing azd auth login](./img/azd_auth_login.png)

- Run the ```azd init``` command from your cloned repo _*azure_jumpstart_ag*_ folder.
  
  ![Screenshot showing azd init](./img/azd_init.png)

- Run the ```azd up``` command to deploy the environment. Azd will prompt you to enter the target subscription, region and all required parameters.

  ![Screenshot showing azd up](./img/azd_up.png)

## Start post-deployment automation

Once your deployment is complete, you can open the Azure portal and see the Agora scenario resources inside your resource group. You will be using the _Agora-Client-VM_ Azure virtual machine to explore various capabilities of Agora. You will need to remotely access _Agora-Client-VM_.

  ![Screenshot showing all deployed resources in the resource group](./img/deployed_resources.png)

   > __NOTE: For enhanced Agora security posture, RDP (3389) and SSH (22) ports are not open by default in Agora deployments. You will need to create a network security group (NSG) rule to allow network access to port 3389, or use [Azure Bastion](https://docs.microsoft.com/azure/bastion/bastion-overview) or [Just-in-Time (JIT)](https://docs.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage?tabs=jit-config-asc%2Cjit-request-asc) access to connect to the VM.__

### Connecting to the Agora Client virtual machine

Various options are available to connect to _Agora-Client-VM_, depending on the parameters you supplied during deployment.

- [RDP](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/deployment/#connecting-directly-with-rdp) - available after configuring access to port 3389 on the _Agora-NSG-Prod_, or by enabling [Just-in-Time access (JIT)](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/deployment/#connect-using-just-in-time-accessjit).
- [Azure Bastion](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/deployment/#connect-using-azure-bastion) - available if ```true``` was the value of your _`deployBastion`_ parameter during deployment.

#### Connecting directly with RDP

By design, Agora does not open port 3389 on the network security group. Therefore, you must create an NSG rule to allow inbound 3389.

- Open the _Agora-NSG-Prod_ resource in Azure portal and click "Add" to add a new rule.

  ![Screenshot showing adding a new inbound security rule](./img/nsg_add_rule.png)

- Select My IP address from the dropdown.

  <img src="./img/nsg_add_rdp_rule.png" alt="Screenshot showing adding a new allow RDP inbound security rule" width="400">
  
  <br/>
  
  ![Screenshot showing all inbound security rule](./img/nsg_rdp_all_rules.png)

  ![Screenshot showing connecting to the VM using RDP](./img/rdp_connect.png)

#### Connect using Azure Bastion

- If you have chosen to deploy Azure Bastion in your deployment, use it to connect to the VM.

  ![Screenshot showing connecting to the VM using Bastion](./img/bastion_connect.png)

  > __NOTE: When using Azure Bastion, the desktop background image is not visible. Therefore some screenshots in this guide may not exactly match your experience if you are connecting to _Agora-Client-VM_ with Azure Bastion.__

#### Connect using just-in-time access (JIT)

If you already have [Microsoft Defender for Cloud](https://docs.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage?tabs=jit-config-asc%2Cjit-request-asc) enabled on your subscription and would like to use JIT to access the Client VM, use the following steps:

- In the Client VM configuration pane, enable just-in-time. This will enable the default settings.

  ![Screenshot showing how to enable JIT](./img/enable_jit.png)

  ![Screenshot showing how to enable JIT](./img/enable_jit2.png)

  ![Screenshot showing connecting to the VM using RDP](./img/connect_jit.png)

### The Logon scripts

- Once you log into the _Agora-Client-VM_, multiple automated scripts will open and start running. These scripts usually take around thirty minutes to finish, and once completed, the script windows will close automatically. At this point, the deployment is complete.

  ![Screenshot showing Agora-Client-VM](./img/automation.png)

- Deployment is complete! Let's begin exploring the features of Contoso Supermarket!

  ![Screenshot showing complete deployment](./img/contoso_supermarket_complete.png)

  ![Screenshot showing Agora resources in Azure portal](./img/rg_complete.png)

## Next steps

Once deployment is complete its time to start experimenting with the various scenarios under the “Contoso Supermarket” experience, starting with the [“Data pipeline and reporting across cloud and edge for store orders”](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/data_pos/).
