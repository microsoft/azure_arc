# Azure Arc-enabled SQL Servers LevelUp Training

![LevelUp Deployment Diagram](levelup-diagram.png)

The following README will guide you on how to automatically deploy an ArcBox for use with the Azure Arc-enabled SQL Servers LevelUp training.

ArcBox LevelUp edition is a special “flavor” of ArcBox that is intended for users who want to experience Azure Arc-enabled SQL servers’ capabilities in a sandbox environment. The screenshot below shows the layout of the lab environment.

Following guest VMs will be deployed in this lab environment to use in different modules.

|VM Name |Windows version|SQL Server version|Purpose|Initial State|
|-------|-------|-------|-------|-------|
|JSLU-Win-SQL-01|Windows 2016| SQL Server 2016 |Used in lab module 1|Not on-boarded to Azure Arc|
|JSLU-Win-SQL-02|Windows 2019| SQL Server 2019 |Used in lab module 3|On-boarded to Azure Arc as connected machine|
|JSLU-Win-SQL-03|Windows 2022| SQL Server 2022 |Used in lab module 3|On-boarded to Azure Arc as connected machine|

> **Note: It is not expected for an Azure VM to be projected as an Azure Arc-enabled server. Instead Hyper-V server on Azure VM is deployed and setup SQL Server guest VMs on Hyper-V for these labs. The below scenario is unsupported and should ONLY be used for demo and testing purposes.**

## Task 1: Setup prerequisites

Please also refer to the prerequisites section of the Azure Arc Jumpstart scenario upon which this LevelUp session is based here.

1. **Supported Regions:** Arc-enabled SQL Server is supported in the following Azure regions. Deploy this lab environment only in one of these supported regions.

    - East US
    - East US 2
    - West US
    - West US 2
    - West US 3
    - Central US
    - North Central US
    - South Central US
    - Canada Central
    - UK South
    - France Central
    - West Europe
    - North Europe
    - Japan East
    - Korea Central
    - East Asia
    - Southeast Asia
    - Australia East

2. **vCPU Cores:** ArcBox requires 16 DSv5-series vCPUs when deploying with default parameters such as VM series/size. Ensure you have sufficient vCPU quota available in your Azure subscription and the region where you plan to deploy ArcBox. You can use the Azure CLI command below to check your vCPU utilization.

  ```shell
  az vm list-usage –location <Your preferred Azure region>

  Example: 
  az vm list-usage --location eastus --output table
  ```

  ![Azure VM Usage](list-azure-usage.png)

2. **AZ CLI Version:** Install or update Azure CLI to version 2.42.0 and above. Verify with `az --version`

  ```shell
  az --version
  ```

  ![AZ CLI Version](az-cli-version-check.png)

4. **Azure Arc Git Repository (Optional):** You can deploy LevelUp this lab environment through Azure Portal using the the instructions in this module. Alternatively you can clone the Azure Arc Git repository using `git clone https://github.com/microsoft/azure_arc.git`. For CLI deployment follow instructions in deployment Option 2 under Task 2 in this lab guide.

  ```shell
  git clone -b lu_arc_sql https://github.com/microsoft/azure_arc.git
  ```

  ![Git clone Azure Arc repository](git-clone-lu-arc-sql.png)

5. **Azure AD Service Principal and Secret:** A service principal with **Owner** role on your subscription, which can be created using commands below using PowerShell or CloudShell:

  ```shell
  $subscriptionId = "<Your subscription id>"
  $servicePrincipalName = "<Unique SP Name>"
  az login
  az account set -s $subscriptionId

  az ad sp create-for-rbac -n $servicePrincipalName --role "Owner" --scopes /subscriptions/$subscriptionId
  ```

  > **Note**: If you can’t use Owner role please make sure to assign **Contributor** and User **Access Administrator** roles to the service principal using below commands.

  ```shell
  az ad sp create-for-rbac -n $servicePrincipalName --role "Contributor" --scopes /subscriptions/$subscriptionId
  az ad sp create-for-rbac -n $servicePrincipalName --role "User Access Administrator" --scopes /subscriptions/$subscriptionId
  ```

  Once you run above commands output should look like below.

  ![Create SPN with RBAC](create-spn-with-rbac.png)

7. **Client ID and Secret:** From the output of the last command, make note of the **appId, password, and tenant** values as shown in the screenshot to use in the LevelUp deployment.

## Task 2: Deploy LevelUp lab environment

### (Option 1): Deploy using Azure Portal

1. Click on the link below to log in to the Azure portal and launch the ARM template to deploy the Level-Up lab environment.

  [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fazure_arc%2Flu_arc_sql%2Fazure_jumpstart_arcbox_levelup%2FARM%2Fazuredeploy.json)

2. Fill in the parameter values as shown below and leave other values default, click on Review + create to continue deployment.

  ![Fill in parameters](azure-portal-deployment-params.png)

3. Review all the values and click on Create to deploy level up lab environment.

  ![Create deployment](azure-portal-deployment-create.png)

4. This deployment takes around 15 minutes. Monitor deployment progress and make sure deployment is successful. 

  ![Review deployment progress](azure-portal-deployment-progress.png)

5. When deployment is successful click on Go to resource group to add NSG rules to allow RDP access.

  ![Deployment complete](azure-portal-deployment-complete.png)

6. This deployment contains 9 resources including _ArcBox-Client_ VM that will be used as part of the lab modules.

  ![Deployed resources](azure-portal-deployment-resources.png)

### (Option 2): Deploy using Azure CLI

1. Open PowerShell window and change directory to **C:\\** and create **ArcSqlLevelup** sub folder and change directory to **C:\ArcSqlLevelup** folder.

2. Clone the Azure Arc Jumpstart repository using command below using PowerShell window on your computer or Azure Cloud Shell.

  ```shell
  git clone -b lu_arc_sql https://github.com/microsoft/azure_arc.git
  ```

  ![Git clone Azure Arc repository](git-clone-lu-arc-sql.png)

3. Open **azuredeploy.parameters.json** file located under **C:\ArcSqlLevelup\azure_arc\azure_jumpstart_arcbox_levelup\ARM** folder in a notepad or choice of your editor.

  ![Parameters file location](azure-arm-parameters.png)

4. Update **azuredeploy.parameters.json** parameter file by providing values for the highlighted parameters below.

  ```shell
  {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "spnClientId": {
        "value": "<your service principal client id>"
      },
      "spnClientSecret": {
        "value": "<your service principal secret>"
      },
      "spnTenantId": {
        "value": "<your spn tenant id>"
      },
      "windowsAdminUsername": {
        "value": "arcdemo"
      },
      "windowsAdminPassword": {
        "value": "ArcPassword123!!"
      },
      "logAnalyticsWorkspaceName": {
        "value": "<your unique Log Analytics workspace name>"
      },
      "deployBastion": {
        "value": false
      }
    }
  }
  ```

5. Create resource group using command below.

  ```shell
  az group create -n ArcSql-Levelup -l eastus
  ```

  ![Create resource group](azure-arm-group-create.png)

6. Deploy ARM template using command below. Please make sure you change the file path in case if you chose different folder for git clone.

  ```shell
  az deployment group create --resource-group ArcSql-Levelup --template-file "C:\ArcSqlLevelup\azure_arc\azure_jumpstart_arcbox_levelup\ARM\azuredeploy.json" --parameters "C:\ArcSqlLevelup\azure_arc\azure_jumpstart_arcbox_levelup\ARM\azuredeploy.parameters.json"
  ```

  ![Deploy ARM template](azure-arm-group-deploy.png)

7. Monitor deployment progress and to go Task 3 once deployment is complete. This deployment takes around 15 minutes to complete.

  ![Monitor ARM deployment progress](azure-arm-group-deployment-complete.png)

  ![Monitor ARM deployment progress](azure-arm-group-deployment-complete-2.png)

## Task 3: Setup RDP Access

> **Note**: Following steps are not required when using Azure Bastion. Go to Task 4, to continue with the lab instructions.

## (Option 1) Allow access to Client VM using your own IP address

Use the following steps if you are not using Just-in-time access. Skip to section “Allow access to Client VM using Just-in-time access:”

1. Click on **ArcBox-Client** VM and select **Networking** to add NSG rule to allow RDP access to ArcBox-Client VM.

  ![Client VM Networking](arcbox-client-networking.png)

2. By default, access to this VM from the Internet is denied to secure access. Click on Add inbound port rule to allow access from your public IP address.

  ![Client VM Networking default NSG rules](arcbox-client-networking-nsg-rules.png)

3. Select values as shown in the screenshot below to allow access to your IP address and click Add.

  ![Client VM Networking add NSG rule](arcbox-client-networking-add-nsg-rule.png)

4. Please make sure this rule is added and looks as shown in screenshot below to avoid any connectivity issues. 

  ![Client VM Networking](arcbox-client-networking-nsg-rdp-rule.png)

## (Option 2) Allow access to Client VM using Just-in-time access

1. From the ArcBox-Client VM Overview tab, expand connect and click on RDP.

  ![Client VM Connectivity using JIT](arcbox-client-connect-rdp.png)

2. Click on "To improve security, enabled just-in-time access to this VM" as shown in the screenshot below.

  ![Client VM Connectivity enable JIT](arcbox-client-connect-rdp-jit.png)

3. Click on Enabled just-in-time as shown in the screenshot below.

  ![Client VM Connectivity enable JIT](arcbox-client-connect-rdp-enable-jit.png)

4. Once JIT is enabled, go back to the Client VM Overview page, click on RDP under connect to request RDP access. 

5. Select My IP and click Request access as shown in the screenshot below.

  ![Client VM Connectivity request access](arcbox-client-connect-rdp-request-access.png)

6. Once access request to approved and completed, click on Download RDP File to connect to the ArcBox-Client VM using RDP.

  ![Client VM Connectivity download RDP file](arcbox-client-connect-download-rdp-file.png)

7. Now, go to Task 4 to login to Client VM to complete the logon script setup remaining lab setup.

## Task 4: Login to ArcBox-Client

### (Option 1) Using Remote Desktop Client

1. Double click on the download ArcBox-Client.rdp file in your download folder

  ![Open RDP file](rdp-file.png)

2. Access warning and click on Connect.

  ![Accept access warning](arcbox-client-rdp-file-connect.png)

3. Enter username and password specified in your template parameter or use following default credentials filled in by the template.

  ```shell
  Username: arcdemo
  Password: ArcPassword123!!
  ```

![Enter credentials](rdp-credentials.png)

4. Click Yes to accept the warning and continue login.

  ![Accept access warning](arcbox-client-connect-rdp-accept-warning.png)

5. During the first time logon lab environment setup script will be executed to setup nested Hyper-V guest VMs with different SQL server editions. This process will take around 20 minutes to complete.

  ![ArcBox client logon script launch](arcbox-client-logn-script-launch.png)

  ![ArcBox client logon script progress](azure-portal-deployment-progress.png)

  ![ArcBox client logon script Arc server onboarding](arcbox-client-logn-script-progress-arc-server.png)

  ![ArcBox client desktop](arcbox-client-desktop.png)

6. Once the logon script execution is complete, click on **Hyper-V Manager** icon on the desktop to see nested SQL Server VMs setup for the labs.

  ![ArcBox client logon script complete](arcbox-client-logn-script-complete.png)


### (Option 2) Using Azure Bastion

1. In Azure portal, go to ArcSql-Levelup resource group and open ArcBox-Client VM.

  ![ArcBox client VM from bastion deployment](arcbox-client-bastion-vm-resource.png)

2. Click on Connect and select Bastion from the drop-down menu.

  ![ArcBox client VM connect using bastion](arcbox-client-select-bastion.png)

3. Enter Username and Password and click on Connect.

  ![ArcBox client VM connect using bastion](arcbox-client-bastion-connect.png)

4. This will open new tab, please make sure to accept pop up window warning to successfully log into the VM.

  ![ArcBox client VM bastion allow popup](arcbox-client-bastion-connect-allow-popup.png)

5. Monitor progress and wait for the script execution to finish lab setup.

  ![ArcBox client VM bastion launch logon script](arcbox-client-bastion-logon-script-launch.png)

  ![ArcBox client VM bastion launch logon script](arcbox-client-bastion-logon-script-progress-arc-servers.png)

  ![ArcBox client VM bastion launch logon script](arcbox-client-bastion-desktop.png)

6. Once the logon script execution is complete, click on **Hyper-V Manager** icon on the desktop to see nested SQL Server VMs setup for the labs.

  ![ArcBox client VM bastion launch logon script](arcbox-client-bastion-logon-script-complete.png)

## Required Credentials

Use the below credentials for logging into the nested Hyper-V virtual machines:

- Windows Server (2019/2022)

  *Username*: `Administrator`

  *Password*: `ArcDemo123!!`

- Linux (Ubuntu/CentOS)

  *Username*: `arcdemo`

  *Password*: `ArcDemo123!!`
