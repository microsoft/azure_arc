# Azure Arc-enabled servers LevelUp Training

## Goals

The purpose of this workshop is to train Microsoft employees who are working in the field with the Azure Arc-enabled server concepts, features, value proposition, and do hands on training to help customers deploy Azure Arc-enabled servers.

After completion of this workshop, you will be able to:

- Understand pre-requisites to onboard Windows and Linux servers to Azure Arc
- Onboard Windows and Linux servers running using different onboarding methods
- Secure your Azure Arc-enabled servers using Microsoft Defender for servers
- Monitor your Azure Arc-enabled servers using Azure Monitor
- Configure your Azure Arc-enabled servers using Azure Automanage machine configuration
- Monitor changes to your Azure Arc-enabled servers using Change tracking and inventory
- Keep your Azure Arc-enabled servers patched using Azure Update Manager
- Gain security insights from your Arc-enabled servers using Microsoft Sentinel
- Run automation runbooks on your Azure Arc-enabled servers using Hybrid runbook workers
- SSH into your Azure Arc-enabled servers using SSH access
- Manage your Azure Arc-enabled servers using Admin Center (Preview)
- Query and inventory your Azure Arc-enabled servers using Azure resource graph
- Enforce governance across your Azure Arc-enabled servers using Azure Policy

| LevelUp Module | Duration | Facilitator |
|---------------|---------------|---------------|
|**1. Onboard Windows and Linux servers running using different onboarding methods** | x minutes | Owner |
|**2. Monitor your Azure Arc-enabled servers using Azure Monitor** | x minutes | Owner |
|**3. Secure your Azure Arc-enabled servers using Microsoft Defender for servers** | x minutes | Owner |
|**4. Configure your Azure Arc-enabled servers using Azure Automanage machine configuration** | x minutes | Owner |
|**5. Monitor changes to your Azure Arc-enabled servers using Change tracking and inventory** | x minutes | Owner |
|**6. Keep your Azure Arc-enabled servers patched using Azure Update Manager** | x minutes | Owner |
|**7. Run automation runbooks on your Azure Arc-enabled servers using Hybrid runbook workers** | x minutes | Owner |
|**8. SSH into your Azure Arc-enabled servers using SSH access** | x minutes | Owner |
|**9. Manage your Azure Arc-enabled servers using Admin Center (Preview)** | x minutes | Owner |
|**10. Query and inventory your Azure Arc-enabled servers using Azure resource graph** | x minutes | Owner |
|**11. Enforce governance across your Azure Arc-enabled servers using Azure Policy** | x minutes | Owner |
|**12. Gain security insights from your Arc-enabled servers using Microsoft Sentinel** | x minutes | Owner |
|**13. Extended Security Updates for your Windows Server 2012 workloads enabled by Azure Arc (TBD)** | x minutes | Owner |
|**14. Run command** | x minutes | Jan Egil Ring |

## LevelUp Lab Environment

ArcBox LevelUp edition is a special “flavor” of ArcBox that is intended for users who want to experience Azure Arc-enabled servers' capabilities in a sandbox environment. Screenshot below shows layout of the lab environment.

  ![Screenshot showing ArcBox architecture](ArcBox-architecture.png)

### Prerequisites

- [Install or update Azure CLI to version 2.51.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

    ![Screenshot showing azure cli version](./azcli_version.png)

- Login to AZ CLI using the ```az login``` command.

```shell
az login
```

- Ensure that you have selected the correct subscription you want to deploy ArcBox to by using the ```az account list --query "[?isDefault]"``` command. If you need to adjust the active subscription used by Az CLI, follow [this guidance](https://docs.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription).

- ArcBox must be deployed to one of the following regions. **Deploying ArcBox outside of these regions may result in unexpected results or deployment errors.**

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

- **ArcBox requires 16 DSv4-series vCPUs** when deploying with default parameters such as VM series/size. Ensure you have sufficient vCPU quota available in your Azure subscription and the region where you plan to deploy ArcBox. You can use the below Az CLI command to check your vCPU utilization.

  ```shell
  az vm list-usage --location <your location> --output table
  ```

  ![Screenshot showing az vm list-usage](./azvmlistusage.png)

- Register necessary Azure resource providers by running the following commands.

  ```shell
  az provider register --namespace Microsoft.HybridCompute --wait
  az provider register --namespace Microsoft.GuestConfiguration --wait
  az provider register --namespace Microsoft.AzureArcData --wait
  az provider register --namespace Microsoft.OperationsManagement --wait
  az provider register --namespace Microsoft.SecurityInsights --wait
  ```

- Create Azure service principal (SP). To deploy ArcBox, an Azure service principal assigned with the _Owner_ Role-based access control (RBAC) role is required. You can use Azure Cloud Shell (or other Bash shell), or PowerShell to create the service principal.

  - (Option 1) Create service principal using [Azure Cloud Shell](https://shell.azure.com/) or Bash shell with Azure CLI:

    ```shell
    subscriptionId="<Your Subscription Id>"
    servicePrincipalName="<Unique Service principal name>"

    az account set -s $subscriptionId
    az ad sp create-for-rbac -n $servicePrincipalName --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    subscriptionId="98471a83-9151-489e-uub1-463447bed604"
    servicePrincipalName="JumpstartArcBoxSPN"

    az account set -s $subscriptionId
    az ad sp create-for-rbac -n $servicePrincipalName --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    Output should look similar to this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArcBoxSPN",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

  - (Option 2) Create service principal using PowerShell. If necessary, follow [this documentation](https://learn.microsoft.com/powershell/azure/install-az-ps?view=azps-8.3.0) to install Azure PowerShell modules.

    ```PowerShell
    $account = Connect-AzAccount
    $subscriptionId = "<Your Subscription Id>"
    $servicePrincipalName = "<Unique Service principal name>"

    Set-AzContext -SubscriptionId $subscriptionId
    $spn = New-AzADServicePrincipal -DisplayName $servicePrincipalName -Role "Owner" -Scope "/subscriptions/$subscriptionId"
    echo "SPN App id: $($spn.AppId)"
    echo "SPN secret: $($spn.PasswordCredentials.SecretText)"
    ```

    For example:

    ```PowerShell
    $account = Connect-AzAccount
    $subscriptionId = "98471a83-9151-489e-uub1-463447bed604"
    $servicePrincipalName = "JumpstartArcBoxSPN"

    Set-AzContext -SubscriptionId $subscriptionId
    $spn = New-AzADServicePrincipal -DisplayName $servicePrincipalName -Role "Owner" -Scope "/subscriptions/$subscriptionId"
    echo "SPN App id: $($spn.AppId)"
    echo "SPN secret: $($spn.PasswordCredentials.SecretText)"
    ```

    Output should look similar to this:

    ![Screenshot showing creating an SPN with PowerShell](./create_spn_powershell.png)

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password.**

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

### Deployment

#### Deployment Option 1: Azure portal

- Click the <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsebassem%2Fazure_arc%2Farc_servers_level_up%2Fazure_jumpstart_arcbox_servers_levelup%2FARM%2Fazuredeploy.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a> button and enter values for the the ARM template parameters.

  ![Screenshot showing Azure portal deployment of ArcBox](./portaldeploy.png)

  ![Screenshot showing Azure portal deployment of ArcBox](./portaldeployinprogress.png)

  ![Screenshot showing Azure portal deployment of ArcBox](./portaldeploymentcomplete.png)

    > **NOTE: The deployment takes around 20 minutes to complete.**

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/itpro/#basic-troubleshooting).**

### Deployment Option 2: Bicep deployment via Azure CLI

- Clone the Azure Arc Jumpstart repository

  ```shell
  $folderPath = <Specify a folder path to clone the repo>

  Set-Location -Path $folderPath
  git clone -b arc_servers_level_up https://github.com/microsoft/azure_arc.git
  Set-Location -Path "azure_arc\azure_jumpstart_arcbox_servers_levelup\bicep"
  ```

- Upgrade to latest Bicep version

  ```shell
  az bicep upgrade
  ```

- Edit the [main.parameters.json](https://github.com/sebassem/azure_arc/blob/arc_servers_level_up/azure_jumpstart_arcbox_servers_levelup/bicep/main.parameters.json) template parameters file and supply some values for your environment.
  - _`spnClientId`_ - Your Azure service principal id
  - _`spnClientSecret`_ - Your Azure service principal secret
  - _`spnTenantId`_ - Your Azure tenant id
  - _`windowsAdminUsername`_ - Client Windows VM Administrator name
  - _`windowsAdminPassword`_ - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - _`logAnalyticsWorkspaceName`_ - Unique name for the ArcBox Log Analytics workspace
  - _`emailAddress`_ - Your email address, to configure alerts for the monitoring action group

  ![Screenshot showing example parameters](./parameters_bicep.png)

- Now you will deploy the Bicep file. Navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_arcbox/bicep) and run the below command:

  ```shell
  az group create --name "<resource-group-name>" --location "<preferred-location>"
  az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
  ```

    > **NOTE: If you see any failure in the deployment, please check the [troubleshooting guide](https://azurearcjumpstart.io/azure_jumpstart_arcbox/itpro/#basic-troubleshooting).**

    > **NOTE: The deployment takes around 20 minutes to complete.**

### Connecting to the ArcBox Client virtual machine

Various options are available to connect to _ArcBox-Client_ VM, depending on the parameters you supplied during deployment.

- [RDP](https://azurearcjumpstart.io/azure_jumpstart_arcbox/ITPro/#connecting-directly-with-rdp) - available after configuring access to port 3389 on the _ArcBox-NSG_, or by enabling [Just-in-Time access (JIT)](https://azurearcjumpstart.io/azure_jumpstart_arcbox/ITPro/#connect-using-just-in-time-accessjit).
- [Azure Bastion](https://azurearcjumpstart.io/azure_jumpstart_arcbox/ITPro/#connect-using-azure-bastion) - available if ```true``` was the value of your _`deployBastion`_ parameter during deployment.

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

  ![Screenshot showing the Microsoft Defender for cloud portal, allowing RDP on the client VM](./jit_configure.png)

  ![Screenshot showing connecting to the VM using RDP](./rdp_connect.png)

  ![Screenshot showing connecting to the VM using JIT](./jit_connect_rdp.png)

#### The Logon scripts

- Once you log into the _ArcBox-Client_ VM, multiple automated scripts will open and start running. These scripts usually take 10-20 minutes to finish, and once completed, the script windows will close automatically. At this point, the deployment is complete.

  ![Screenshot showing ArcBox-Client](./automation.png)

- Deployment is complete! Let's begin exploring the features of Azure Arc-enabled servers with the Level-up modules.

  ![Screenshot showing complete deployment](./arcbox_complete.png)

  ![Screenshot showing ArcBox resources in Azure portal](./rg_arc.png)

## Modules

### Module 1: On-boarding to Azure Arc-enabled servers

#### Module overview

#### Task 1

#### Task 2

### Module 2: Monitor your Azure Arc-enabled servers using Azure Monitor

#### Module overview

In this module, you will learn how to deploy the Azure Monitor agent to your Arc-enabled Windows and Linux machines, the dependency agent to your Arc-enabled Windows machines and enable the _VM Insights_ solution to start monitoring your machines using Azure Monitor, run queries on the Log analytics workspace and configure alerts.

#### Task 1: Deploy Azure Monitor agents and VM Insights using Azure Policy

Azure Policy lets you set and enforce requirements for all new resources you create and resources you modify. VM insights policy initiatives, which are predefined sets of policies created for VM insights, install the agents required for VM insights and enable monitoring on all new virtual machines in your Azure environment.

- In the Azure portal, search for _Policy_.

    ![Screenshot showing searching for Policy in the azure portal](./portal_policy_search.png)

- Click on "Definitions" and search for the _(ArcBox) Deploy Azure Monitor on Arc-enabled Windows machines_ policy.

    ![Screenshot showing searching for the arcbox policies](./policy_arcbox.png)

- Click "Assign Initiative".

    ![Screenshot showing assigning the policy](./policy_monitor_windows_assign.png)

- Select the right scope (management group, subscription and resource group) for the resource group where you deployed _ArcBox_.

    ![Screenshot showing assigning the policy to the right scope](./policy_monitor_windows_scope.png)

- After validating the scope, click "Next" twice to navigate to the parameters tab.

    ![Screenshot showing assigning the policy initiative to the right scope](./policy_monitor_windows_dcr_blank.png)

- To get the "Data Collection Rule" resource Id,  run the following CLI command

```shell
az resource show --name "MSVMI-PerfandDa-ama-vmi-default-perfAndda-dcr" `
                 --resource-group "<resource group name>" `
                 --resource-type Microsoft.Insights/dataCollectionRules `
                 --query id `
                 --output tsv
```

- You can also find the "Data Collection Rule" resource Id from the Azure portal. Search for the _arcbox-ama-vmi-perfAndda-dcr_ data collection rule.

    ![Screenshot showing searching for data collection rules](./dcr_search_portal.png)

    ![Screenshot showing getting the data collection rules resource Id](./dcr_vm_insights.png)

    ![Screenshot showing getting the data collection rules resource Id](./dcr_json_view.png)

    ![Screenshot showing getting the data collection rules resource Id](./dcr_resource_id.png)

    ![Screenshot showing adding the data collection rules resource Id](./policy_monitor_windows_create.png)

    > **NOTE:The policy will take 5-15 minutes to assess the current resources.**

- After the policy has reported compliance, create a remediation task to remediate existing machines.

    ![Screenshot showing the ama policy not compliant](./policy_monitor_windows_non_compliant.png)

    ![Screenshot showing creating the remediation task](./policy_monitor_windows_create_remediation.png)

    ![Screenshot showing creating the remediation task](./policy_monitor_windows_remediate.png)

- Create one remediation task per policy definition in the initiative.

    ![Screenshot showing creating the remediation task](./policy_monitor_windows_create_remediation_multiple.png)

- After all remediation tasks have completed. You should see the Azure Monitor agent extension and the dependency agent extension deployed to the Arc-enabled machines.

    ![Screenshot showing the remediation tasks successful](./policy_monitor_windows_remediate_tasks.png)

    ![Screenshot showing the monitoring agents installed](./machine_windows_ama_agents.png)

- Repeat the same steps in _Task 2_ to assign the Linux policy for data collection _(ArcBox) Deploy Azure Monitor on Arc-enabled Linux machines._

- After configuring the agents and VM insights using Azure Policy, it will take 10-25 minutes for the insights data to start showing up.

   ![Screenshot showing VM insights on the Windows Arc-enabled machine](./machine_vm_insights.png)

   ![Screenshot showing VM insights on the Linux Arc-enabled machine](./machine_vm_insights_linux.png)

#### Task 2: Configure data collection for logs and metrics

As part of the ArcBox automation, some alerts and workbooks have been created to demonstrate the different monitoring operations you can perform after onboarding the Arc-enabled machines. You will now configure some data collection rules to start sending the needed metrics and logs to the Log Analytics workspace.

- In the Azure portal, search for _Data Collection rules_.

    ![Screenshot showing searching for data collection rules](./dcr_search_portal.png)

- Create a new data collection rule.

    ![Screenshot showing creating a new data collection rule](./alerts_dcr_create.png)

- Provide a name and select the same resource group where ArcBox is deployed. Make sure to select Windows as the operating system.

    ![Screenshot showing creating a new data collection rule](./alerts_dcr_basics.png)

- In the "Resources" tab, select the right resource group and the Arc-enabled servers onboarded.

    ![Screenshot showing adding resources to the data collection rule](./alerts_dcr_resources.png)

- Add a new "Performance Counters" data source, and make sure to select all the custom counters.

    ![Screenshot showing adding performance counters to the data collection rule](./alerts_dcr_counters.png)

- Add a new "Azure Monitor Logs" destination and select the log analytics workspace deployed in the ArcBox resource group and save.

    ![Screenshot showing adding performance counters to the data collection rule](./alerts_dcr_counters_destination.png)

- Add a new "Windows Event logs" data source.

    ![Screenshot showing adding log data source to the data collection rule](./alerts_dcr_windows_logs_source.png)

- Select _Critial_, _Error_, _Warning_ events in the Application and System logs and add the data source.

    ![Screenshot showing adding log data source to the data collection rule](./alerts_dcr_windows_logs_types.png)

- Save and create the data collection rule.

- Repeat the previous steps to create another Linux data collection rule.

    ![Screenshot showing creating a new linux data collection rule](./alerts_dcr_linux_basics.png)

    ![Screenshot showing adding resources to the data collection rule](./alerts_dcr_resources_linux.png)

    ![Screenshot showing adding logs to the data collection rule](./alerts_dcr_logs_linux.png)

- After waiting for 5-10 minutes for the data collection rule to start collecting data, restart the servers in the Hyper-V manager on the _ArcBox-Client_ VM to trigger some new events.

    ![Screenshot showing restarting the vms in the hyper-v manager](./alerts_hyperv_restart.png)

#### Task 3: View alerts and visualizations

> **NOTE: It might take some time for all visualizations to load properly**

- In Azure Monitor, click on _Alerts_. and select _Alert rules_

    ![Screenshot showing opening the alerts page](./alerts_rules_open.png)

- Explore the alert rules crated for you.

    ![Screenshot showing opening one alert around processor time](./alerts_rules_rules.png)

- Go back to Azure Monitor and click on _Workbooks_. There are three workbooks deployed for you.

    ![Screenshot showing deployed workbooks](./alerts_workbooks_list.png)

    ![Screenshot showing alerts workbook](./alerts_workbooks_alerts.png)

    ![Screenshot showing performance workbook](./alerts_workbooks_perf.png.png)

    ![Screenshot showing events workbook](./alerts_workbooks_events.png)

### Module 3: Secure your Azure Arc-enabled servers using Microsoft Defender for servers

#### Module overview

In this module, you will learn how to enable and leverage Microsoft Defender for Servers to secure your Azure Arc-enabled servers using capabilities like Defender for Endpoint, vulnerability assessment and threat detection via alerts.

#### Task 1: Pre-requisites

> **NOTE: In the previous module, you should have already deployed the Azure Monitor agent (AMA) to you Arc-enabled servers. If you have not deployed it, follow the following steps in module 2 to deploy it otherwise skip to task 2**

#### Task 2: Enable the Defender for Servers plan

- From the Azure home page, search for defender and select Microsoft Defender for Cloud.

    ![Screenshot showing searching for Defender for Cloud in the Azure Portal](./defenderForCloud_portal_search.png)

- If you already have Defender plans setup at your subscription level, you may find that Defender is already turned on for your Arc-enabled servers. However, if Defender is not enabled, select _Environment settings_ from the Management section on the left blade.

    ![Screenshot showing selecting the right subscription to enableDefender for Cloud in the Azure Portal](./defenderForCloud_portal_env_settings.png)

- Expand the Tenant Root Group, and then select your subscription.

- Enable the plan for servers, you can select either _Plan 1_ or _Plan 2_ for this exercise

    ![Screenshot showing enabling Defender for servers plan in the Azure Portal](./defenderForCloud_portal_servers_enable.png)

- Click on the settings option in the _Monitoring coverage_ and enable the following capabilities:
  - Vulnerability assessment for machines
  - Endpoint protection

    ![Screenshot showing configuring Defender for servers plan 1 in the Azure Portal](./defenderForCloud_portal_servers_settings.png)

- Click Save.

    ![Screenshot showing configuring Defender for servers plan 1 in the Azure Portal](./defenderForCloud_portal_save.png)

#### Task 3: Detect threats on your servers using alerts

- To simulate a malicious activity on the _Win2k22_ servers, rdp into the _ArcBox-Client_ VM
- Go to Start and type _PowerShell ISE_.
- Right-select and select Run as administrator.

    ![Screenshot showing opening cmd as administator](./powershellISE_runas.png)

- Run the following command:

```shell
$remoteScriptFile = "$agentScript\testDefenderForServers.ps1"
$Win2k22vmName = "ArcBox-Win2K22"
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)
$cmdExePath = "C:\Windows\System32\cmd.exe"
$cmdArguments = "/C `"$remoteScriptFile`""

Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Start-Process -FilePath $Using:cmdExePath -ArgumentList $Using:cmdArguments } -Credential $winCreds
```

  ![Screenshot showing running the Defender alert trigger script in ISE](./run_defender_alert_trigger.png)

- Navigate to the Security tab of the _Win2k22_ Arc-enabled server in the portal

    ![Screenshot showing the generated alert](./defenderForCloud_portal_alert.png)

  > **NOTE: You should already see an alert for the Win2k19 Arc-enabled server**

- You can also see the alerts from the _Defender for Cloud_ portal, in the _Security alerts_ pane.

    ![Screenshot showing the generated alert](./defenderForCloud_portal_alert_mdfc.png)

  > **NOTE: If you don't see the alerts, make sure to select the Information severity in the filters**

    ![Screenshot showing the generated alert filters](./defenderForCloud_portal_alert_filter.png)

#### Task 4: Enable vulnerability assessment

- After waiting for 30-45 minutes, you should start seeing recommendations for the Arc-enabled machines in the "Security" blade.

> **NOTE: It might take several hours before this recommendation start to appear**

- You should find the recommendation _Machines should have vulnerability findings resolved_ if the vulnerability assessment has been enabled automatically on the subscription.

    ![Screenshot showing defender recommendations](./defenderForCloud_portal_recommendation_vulnerabilities.png)

    ![Screenshot showing defender recommendations](./defenderForCloud_portal_vulnerabilities_list.png)

- If you do not see this recommendation, click on the _Machines should have a vulnerability assessment solution installed_

    ![Screenshot showing defender recommendations](./defenderForCloud_portal_recommendations.png)

- Click on the "Machines should have a vulnerability assessment solution" recommendation and click "fix"

    ![Screenshot showing fixing the recommendation](./defenderForCloud_portal_recommendation_fix.png)

    ![Screenshot showing fixing the recommendation](./defenderForCloud_portal_enable_vulnrability.png)

    ![Screenshot showing fixing the recommendation](./defenderForCloud_portal_recommendation_fix_resource.png)

    ![Screenshot showing fixing the recommendation](./defenderForCloud_portal_recommendation_fix_success.png)

> **NOTE: The same steps can be applied to the Linux Arc-enabled machines**

### Module 4: Configure your Azure Arc-enabled servers using Azure Automanage machine configuration

#### Module overview

In this module, you will learn to create and assign a custom Automanage Machine Configuration to an Azure Arc-enabled Windows and Linux servers to create a local user and control installed roles and features.

#### Task 1 : Create Automanage Machine Configuration custom configurations for Windows

We will be using the ArcBox Client virtual machine for the configuration authoring.

- RDP into the _ArcBox-Client_ VM

- Open Visual Studio Code from the desktop shortcut.

- Create C:\ArcBox\MachineConfiguration.ps1, then paste and run the following commands to complete the steps for this task:

> **NOTE: To run each additional code snippet you paste in VSCode, highlight the code you need to run and press F8**

  ![Screenshot showing VSCode code execution](./vscode_code_execution.png)

##### Custom configuration for Windows

- Initialize variables.

```PowerShell
$resourceGroupName = $env:resourceGroup
$location = $env:azureLocation
$spnClientId = $env:spnClientID
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$Win2k19vmName = "ArcBox-Win2K19"
$Win2k22vmName = "ArcBox-Win2K22"

$SecurePassword = ConvertTo-SecureString -String $spnClientSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spnClientId, $SecurePassword
Connect-AzAccount -ServicePrincipal -TenantId $spnTenantId -Credential $Credential
```

- Install the needed PowerShell modules.

```PowerShell
Install-Module -Name Az.Accounts -Force -RequiredVersion 2.12.1
Install-Module -Name Az.PolicyInsights -Force -RequiredVersion 1.5.1
Install-Module -Name Az.Resources -Force -RequiredVersion 6.5.2
Install-Module -Name Az.Storage -Force -RequiredVersion 5.4.0
Install-Module -Name GuestConfiguration -Force -RequiredVersion 4.4.0
Install-Module -Name PSDesiredStateConfiguration -Force -RequiredVersion 2.0.5
Install-Module -Name PSDscResources -Force -RequiredVersion 2.12.0.0
```

- Run _Get-InstalledModule_ to validate that the modules have installed successfully.

The Azure PowerShell modules are used for:

- Publishing the package to Azure storage
- Creating a policy definition
- Publishing the policy
- Connecting to the Azure Arc-enabled servers

The GuestConfiguration module automates the process of creating custom content including:

- Creating a machine configuration content artifact (.zip)
- Validating the package meets requirements
- Installing the machine configuration agent locally for testing
- Validating the package can be used to audit settings in a machine
- Validating the package can be used to configure settings in a machine

Desired State Configuration version 3 is removing the dependency on MOF.
Initially, there are only support for DSC Resources written as PowerShell classes.
Due to using MOF-based DSC resources for the Windows demo-configuration, we are using version 2.0.5.

- Create a storage account to store the machine configurations

```PowerShell
$storageaccountsuffix = -join ((97..122) | Get-Random -Count 5 | % {[char]$_})
New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name "machineconfigstg$storageaccountsuffix" -SkuName 'Standard_LRS' -Location $Location -OutVariable storageaccount | New-AzStorageContainer -Name machineconfiguration -Permission Blob
```

- Create the custom configuration

```PowerShell
Import-Module PSDesiredStateConfiguration -RequiredVersion 2.0.5

Configuration AzureArcLevelUp_Windows
{
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $PasswordCredential
    )

    Import-DscResource -ModuleName 'PSDscResources' -ModuleVersion 2.12.0.0

    Node localhost
    {
        MsiPackage PS7
        {
            ProductId = '{323AD147-6FC4-40CB-A810-2AADF26D868A}'
            Path = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi'
            Ensure = 'Present'
        }
        User ArcBoxUser
        {
            UserName = 'arcboxuser1'
            FullName = 'ArcBox User 1'
            Password = $PasswordCredential
            Ensure = 'Present'
        }
        WindowsFeature SMB1 {
            Name = 'FS-SMB1'
            Ensure = 'Absent'
        }
    }
}

Write-Host "Creating credentials for arcbox user 1"
$nestedWindowsUsername = "arcboxuser1"
$nestedWindowsPassword = "ArcDemo123!!"  # In real-world scenarios this could be retrieved from an Azure Key Vault

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
}

$OutputPath = "$HOME/arc_automanage_machine_configuration_custom_windows"
New-Item $OutputPath -Force -ItemType Directory
```

- Execute the newly created configuration.

```PowerShell
AzureArcLevelUp_Windows -PasswordCredential $winCreds -ConfigurationData $ConfigurationData -OutputPath $OutputPath
```

- Create a package that will audit and apply the configuration (Set)

```PowerShell
New-GuestConfigurationPackage `
-Name 'AzureArcLevelUp_Windows' `
-Configuration "$OutputPath/localhost.mof" `
-Type AuditAndSet `
-Path $OutputPath `
-Force
```

- Test applying the configuration to the local machine

```PowerShell
Start-GuestConfigurationPackageRemediation -Path "$OutputPath/AzureArcLevelUp_Windows.zip"
```

- Upload the configuration package to the Azure Storage Account.

```PowerShell
$StorageAccount = Get-AzStorageAccount -Name "machineconfigstg$storageaccountsuffix" -ResourceGroupName $ResourceGroupName

$StorageAccountKey = Get-AzStorageAccountKey -Name $storageaccount.StorageAccountName -ResourceGroupName $storageaccount.ResourceGroupName
$Context = New-AzStorageContext -StorageAccountName $storageaccount.StorageAccountName -StorageAccountKey $StorageAccountKey[0].Value

Set-AzStorageBlobContent -Container "machineconfiguration" -File  "$OutputPath/AzureArcLevelUp_Windows.zip" -Blob "AzureArcLevelUp_Windows.zip" -Context $Context -Force

$contenturi = New-AzStorageBlobSASToken -Context $Context -FullUri -Container machineconfiguration -Blob "AzureArcLevelUp_Windows.zip" -Permission r
```

- Create an Azure Policy definition.

```PowerShell
$PolicyId = (New-Guid).Guid

New-GuestConfigurationPolicy `
  -PolicyId $PolicyId `
  -ContentUri $ContentUri `
  -DisplayName '(AzureArcJumpstart) [Windows] Custom configuration' `
  -Description 'Azure Arc Jumpstart Windows demo configuration' `
  -Path  $OutputPath `
  -Platform 'Windows' `
  -PolicyVersion 1.0.0 `
  -Mode ApplyAndAutoCorrect `
  -Verbose -OutVariable Policy

  $PolicyParameterObject = @{'IncludeArcMachines'='true'}

  New-AzPolicyDefinition -Name '(AzureArcJumpstart) [Windows] Custom configuration' -Policy $Policy.Path -OutVariable PolicyDefinition
```

- Assign the Azure Policy definition to the target resource group.

```PowerShell
$ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName

New-AzPolicyAssignment -Name '(AzureArcJumpstart) [Windows] Custom configuration' -PolicyDefinition $PolicyDefinition[0] -Scope $ResourceGroup.ResourceId -PolicyParameterObject $PolicyParameterObject -IdentityType SystemAssigned -Location $Location -DisplayName '(AzureArcJumpstart) [Windows] Custom configuration' -OutVariable PolicyAssignment
```

- In order for the newly assigned policy to remediate existing resources, the policy must be assigned a managed identity and a policy remediation must be performed.

```PowerShell
$PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId | Where-Object Name -eq '(AzureArcJumpstart) [Windows] Custom configuration'

$roleDefinitionIds =  $PolicyDefinition.Properties.policyRule.then.details.roleDefinitionIds

# Wait for eventual consistency
Start-Sleep 20

if ($roleDefinitionIds.Count -gt 0)
 {
     $roleDefinitionIds | ForEach-Object {
         $roleDefId = $_.Split("/") | Select-Object -Last 1
         New-AzRoleAssignment -Scope $resourceGroup.ResourceId -ObjectId $PolicyAssignment.Identity.PrincipalId -RoleDefinitionId $roleDefId
     }
 }

 $job = Start-AzPolicyRemediation -AsJob -Name ($PolicyAssignment.PolicyAssignmentId -split '/')[-1] -PolicyAssignmentId $PolicyAssignment.PolicyAssignmentId -ResourceGroupName $ResourceGroup.ResourceGroupName -ResourceDiscoveryMode ReEvaluateCompliance
```

- To check policy compliance, in the Azure Portal, navigate to *Policy* -> *Compliance*

- Set the scope to the resource group your instance of ArcBox is deployed to

- Filter for *(AzureArcJumpstart) [Windows] Custom configuration*

    ![Screenshot of Azure Portal showing Azure Policy compliance](./portal_policy_compliance.png)

> **NOTE: It may take 15-20 minutes for the policy remediation to be completed.**

- To get a Machine Configuration status for a specific machine, navigate to *Azure Arc* -> *Machines*

- Click on ArcBox-Win2K22 -> Machine Configuration

- If the status for *ArcBox-Win2K22/AzureArcLevelUp_Windows* is not *Compliant*, wait a few more minutes and click *Refresh*

    ![Screenshot of Azure Portal showing Azure Machine Configuration compliance](./portal_machine_config_compliance.png)

- Click on *ArcBox-Win2K22/AzureArcLevelUp_Windows* to get a per-resource view of the compliance state in the assigned configuration

    ![Screenshot of Azure Portal showing Azure Machine Configuration compliance detailed view](./portal_machine_config_configs.png)

##### Verify that the operating system level settings are in place

- To verify that the operating system level settings are in place, run the following commands:

```powershell
 Invoke-Command -VMName $Win2k19vmName -ScriptBlock { Get-LocalUser -Name arcboxuser1 } -Credential $winCreds

 Invoke-Command -VMName $Win2k19vmName -ScriptBlock {  Get-WindowsFeature -Name FS-SMB1 | select  DisplayName,Installed,InstallState} -Credential $winCreds
```

  ![Screenshot of VScode showing Azure Machine Configuration validation on Windows](./vscode_win_machine_config_validation.png)

#### Task 2

### Module 5: Monitor changes to your Azure Arc-enabled servers using Change Tracking and Inventory

#### Module overview

Change Tracking and Inventory is an inbuilt Azure service, provided by Azure Automation. The old version uses the Log Analytics agent, while the new (preview) version uses the Azure Monitor Agent (AMA). The training here is taken from https://learn.microsoft.com/en-us/azure/automation/change-tracking/overview-monitoring-agent?tabs=win-az-vm

#### Prerequisites

The following are required for this module to function:
1. Ensure that the servers are already provisioned in Arc.
2. Ensure that the AMA is already provisioned on every server.
3. Ensure that the servers are already enrolled in Defender for Servers (this is required for File Integrity Monitoring)

Currently, the policies to enable Change tracking and inventory with AMA are in preview. For a seamless policy experience, we recommend that you begin by enabling the Microsoft.Compute/AutomaticExtensionUpgradePreview feature flag for your specific subscription. To register for this feature flag, go to Azure portal > Subscriptions > Select specific subscription name. In the Preview features, select Automatic Extension Upgrade Preview and then select Register.

![Screenshot showing how to enable preview change tracking](./changetracking-enable.png)

The Automation Account must also enable Change Tracking and Inventory
![Screenshot showing how to enable inventory in Automation Account](./changetracking-enable-inv.png)

Depending on the state of the automation account, you may be asked to enable the preview feature.
For this levelup - it should not happen since we are using new automation account.
![Screenshot showing how to enable preview change tracking in Automation Account](./changetracking-enablepreview.png)

#### Current Limitations

The following table lists the current limitations for Change Tracking And Inventory
https://learn.microsoft.com/en-us/azure/automation/change-tracking/overview-monitoring-agent?tabs=win-az-vm#current-limitations

Ensure that you have the correct region mappings for Azure Automation account and Log Analytics workspace as not all regions support both:
https://learn.microsoft.com/en-us/azure/automation/how-to/region-mappings

#### Enabling Change Tracking and Inventory

After the automation account has the correct Change Tracking enabled, it will then request how to onboard current and new machines for change tracking
![Screenshot showing how to onboard CT for each VM in Automation Account](./changetracking-ct-enabled.png)
![Screenshot showing how to onboard CT for the current and future in Automation Account](./changetracking-enable-allmachines.png)

For Azure Arc - you must then create a Data Collection Rule (DCR) to specify the data collection characteristics.
Here is an example DCR for setting up Change Tracking: 
https://learn.microsoft.com/en-us/azure/automation/change-tracking/change-tracking-data-collection-rule-creation
Note - this DCR will have already been deployed as part of the setup for this levelup, but you will need to know where to do this for your own environments in future.

Now we need to onboard an Azure policy to ensure that the machines are reporting correctly to the Log Anaytics workspace.

Please be patient as onboarding machines will take a while for the inventory to populate.

#### Using Change Tracking

Try stopping and starting services on the Arc machine ArcBox-Win2k19.

```PowerShell
Stop-Service spooler
Start-service spooler
```

#### Managing Change Tracking using Data Collection Rules
To manage Change Tracking, you can change the types of data collected and how often (for example, 60s for specific CPU and RAM counters, or 1 hour for file changes.)

![Screenshot showing Edit Settings](./changetracking-editsettings.png)

First, make sure that a storage account is already configured for file uploads.

![Screenshot showing Storage Account Settings](./changetracking-storageaccount.png)

Then add files that you want to monitor, for example, the hosts file.

![Screenshot showing add file monitoring](./changetracking-addfilemonitoring.png)

Eventually, the file changes will show up in the main console.

#### Alert Configuration

On the Change tracking page from your Virtual Machine, select Log Analytics.

In the Logs search, look for content changes to the hosts file with the query 
```cmd
ConfigurationChange | where FieldsChanged contains "FileContentChecksum" and FileSystemPath == "c:\windows\system32\drivers\etc\hosts"
```

After the query returns its results, select New alert rule in the log search to open the Alert creation page. You can also navigate to this page through Azure Monitor in the Azure portal.

Check your query again and modify the alert logic. In this case, you want the alert to be triggered if there's even one change detected across all the machines in the environment.

After the alert logic is set, assign action groups to perform actions in response to triggering of the alert. In this case, we're setting up emails to be sent and an IT Service Management (ITSM) ticket to be created.

To setup an action group that determines what action the alert will trigger:

Select the alert created earlier and then select Create New under Action Groups.

Enter a full name and a short name for the action group. The short name will be used when sending notifications using the specified group.

Under Actions, enter a name that specifies the action, for example, Email Notification.

For Action Type, select the appropriate type, for example, Email/SMS message/Push/Voice.

Select the pencil icon to edit the action details.

Fill in the pane for your action type. For example, if using Email/SMS message/Push/Voice to send an email, enter an action name, select the Email checkbox, enter a valid email address, and then select OK.

In the Add action group pane, select OK.

For an alert email, you can customize the email subject. Select Customize actions under Create rule, then select Email subject.

When you're finished, select Create alert rule.

### Module 6: Keep your Azure Arc-enabled servers patched using Azure Update Manager

#### Module overview

Azure Update Manager is the new service that unifies all VMs running in Azure together with Azure Arc, putting all update tasks in 1 common area for all supported Linux and Windows versions.
This service is NOT dependent on Log analytics agent. (The older Azure Automation Update service relies on Log Analytics agent)

Extended Security Updates (ESU) for older Windows like Windows 2012 and 2012R2 are also available through this service (Free for Azure VMs, and an opt-in paid service for Arc).
These modules will take a while to run, up to 15 minutes for each VM, due to processing required at the various VMs, although it is all running simultaneously.

This new service is currently in preview and has no powershell scripting option (as of Aug 2023)

#### Onboarding the Arc-enabled servers

Note that all Azure VMs and Arc Server VMs are already visible in this Azure Update Manager service.

   ![Screenshot showing initial view of all VMs](./updatemgmt-allvms.png)

#### Refresh the VMs

- Once the VMs have been onboarded, clicking on the refresh button will refresh the current status of selected VMs.
This can also be set as an automatic recurring task for at scale refresh - once every 24 hours. This automatic refresh interval cannot be changed.

   ![Screenshot showing automatic refresh configuration](./updatemgmt-updatesettings.png)

#### Setup Maintenance Configuration

- Setup a list of maintenance configurations for each specific group of VMs in your environment. For countries in Asia and Europe, it is a good idea to use second Tuesday + 1 day to coincode with Patch Tuesday. Do not use "Second Wednesday of the month".

   ![Screenshot showing how to add a maintenance config](./updatemgmt-maintenanceconfig.png)

- Then choose how machines are added to this maintenance configuration (by OS, location, resource group)

   ![Screenshot showing the dynamic scopes for update groups](./updatemgmt-dynamicscopes.png)

- Or choose machines specifically instead of dynamically

   ![Screenshot showing which machines to be selected for config](./updatemgmt-specificmachineselection.png)

- Then choose what type of updates will be installed by this config

   ![Screenshot showing which updates are going to be installed](./updatemgmt-specificupdates.png)

#### Forcing one-time updates

- Instead of using maintenance configs with specific recurring cycles, you can also setup one-time updates (immediately!). Start by forcing an immediate refresh.

   ![Screenshot showing onetime refresh](./updatemgmt-onetimerefresh.png)

- Then specify which machines

   ![Screenshot showing what updates for each machines](./updatemgmt-installonetimeupdates.png)

- Choose which types of updates

   ![Screenshot showing which types of updates to install](./updatemgmt-showwhichupdates.png)

- Look at the update options

   ![Screenshot showing changes to be made in the onboard script](./updatemgmt-installoptions.png)

- Then wait for a few hours and a few reboots - this can take repeated forcing for machines that have not been updated for a long time

   ![Screenshot showing final state](./updatemgmgt-allupdatescompleted.png)

#### Reporting

Under the Monitoring part of the Update Manager, there is a default workbook, which is an overview of the Azure Update Manager. There are a few views in there that show the total number of machines connected, history of runs, and the status.

- View of currently connected machines, split by Azure and Azure Arc VMs, and Windows and Linux numbers.

   ![Screenshot showing overall machine Status](./updatemgmt-reporting1.png)

- View of manual vs periodic assessments and manual vs automatically updated.

   ![Screenshot showing overall machine Status](./updatemgmt-repoting2.png)

- View of updates by classification

   ![Screenshot showing overall machine Status](./updatemgmt-reporting3.png)

#### Module recap

In this session, you have setup Update Management and learnt how to enable it to efficiently manage all updates for your machines, regardless of where they are.
You have also seen some of the default reports, and since they use workbooks, you can easily create your own customized reports.

### Module 7: Run automation runbooks on your Azure Arc-enabled servers using Hybrid runbook workers

#### Module overview

In this module we will onboard two Azure Arc-enabled servers as Hybrid runbook workers in Azure Automation. We will then create and start runbooks on the hybrid runbook workers to see how this feature can be leveraged.

#### Task 1

#### Task 2

### Module 8: SSH into your Azure Arc-enabled servers using SSH access

#### Module overview

SSH for Arc-enabled servers enables SSH based connections to Arc-enabled servers without requiring a public IP address or additional open ports.
In this module, you will learn how to enable and configure this functionality. At the end, you will interactively explore how to access to Arc-enabled Windows and Linux machines.

#### Task 1 - Install prerequisites on client machine

It is possible to leverage both Azure CLI and Azure PowerShell to connect to Arc-enabled servers, you may choose which one to use based on your own preferences.

- RDP into the _ArcBox-Client_ VM
- Open PowerShell and install either the Azure CLI extension or the Azure PowerShell modules based on your preference of tooling

#### Azure CLI

```cmd
az extension add --name ssh
```

or

#### Azure PowerShell

```powershell
Install-Module -Name Az.Ssh -Scope CurrentUser -Repository PSGallery
Install-Module -Name Az.Ssh.ArcProxy -Scope CurrentUser -Repository PSGallery
```

  > NOTE: We recommend that you install the tools on the ArcBox Client virtual machine, but you may also choose to use your local machine if you want to verify that the Arc-enabled servers is reachable from any internet-connected machine after performing the tasks in this module.

#### Task 2 - Enable SSH service on Arc-enabled servers

We will use two Arc-enabled servers running in ArcBox for this module:

- _ArcBox-Win2K22_
- _ArcBox-Ubuntu-01_

Perform the following steps in order to enable and verify SSH configuration on both machines:

- RDP into the _ArcBox-Client_ VM
- Open Hyper-V Manager
- Right click _ArcBox-Win2K22_ and select Connect twice
- Login to the operating system using username Administrator and the password you used when deploying ArcBox, by default this is **ArcPassword123!!**
- Open Windows PowerShell and install OpenSSH for Windows by running the following:
```powershell
# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`

# Start the sshd service
Start-Service sshd

# Configure the service to start automatically
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Windows Firewall is configured to allow SSH. The rule should be created automatically by setup. Run the following to verify:
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}
```
- Close the connection to _ArcBox-Win2K22_
- Right click _ArcBox-Ubuntu-01_ in Hyper-V Manager and select Connect
- Login to the operating system using username arcbox and the password you used when deploying ArcBox, by default this is **ArcPassword123!!**
- Run the command `systemctl status sshd` to verify that the SSH service is active and running
- Close the connection to _ArcBox-Ubuntu-01_


#### Task 3 - Connect to Arc-enabled servers

From the _ArcBox-Client_ VM, open a PowerShell session and use the below commands to connect to **ArcBox-Ubuntu-01** using SSH:

#### Azure CLI
```powershell
$serverName = "ArcBox-Ubuntu-01"
$localUser = "arcdemo"

az ssh arc --resource-group $Env:resourceGroup --name $serverName --local-user $localUser
```

or

#### Azure PowerShell
```powershell

$serverName = "ArcBox-Ubuntu-01"
$localUser = "Administrator"

Enter-AzVM -ResourceGroupName $Env:resourceGroup -Name $serverName -LocalUser $localUser
```

The first time you connect to an Arc-enabled server using SSH, you will retrieve the following question:
> Port 22 is not allowed for SSH connections in this resource. Would you like to update the current Service Configuration in the endpoint to allow connections to port 22? If you would like to update the Service Configuration to allow connections to a different port, please provide the -Port parameter or manually set up the Service Configuration. (y/n)

It is possible to pre-configure this setting on the Arc-enabled servers by following the steps in the section *Enable functionality on your Arc-enabled server* in the [documentation](https://learn.microsoft.com/en-us/azure/azure-arc/servers/ssh-arc-overview?tabs=azure-powershell#getting-started).

For this exercise, select `y` and press Enter to proceed.

 ![Screenshot showing usage of SSH via Azure CLI](./ssh_via_az_cli_01.png)

 ![Screenshot showing usage of SSH via Azure CLI](./ssh_via_az_cli_02.png)

Following the previous method, connect to _ArcBox-Win2K22_ via SSH.

#### Azure CLI
```powershell
$serverName = "ArcBox-Win2K22"
$localUser = "Administrator"

az ssh arc --resource-group $Env:resourceGroup --name $serverName --local-user $localUser
```

or
#### Azure PowerShell
```powershell

$serverName = "ArcBox-Win2K22"
$localUser = "Administrator"

Enter-AzVM -ResourceGroupName $Env:resourceGroup -Name $serverName -LocalUser $localUser
```

![Screenshot showing usage of SSH via Azure CLI](./ssh_via_az_cli_03.png)

![Screenshot showing usage of SSH via Azure CLI](./ssh_via_az_cli_04.png)

In addition to SSH, you can also connect to the Azure Arc-enabled servers, Windows Server virtual machines using **Remote Desktop** tunneled via SSH.

#### Azure CLI
  ```powershell
  $serverName = "ArcBox-Win2K22"
  $localUser = "Administrator"

  az ssh arc --resource-group $Env:resourceGroup --name $serverName --local-user $localUser --rdp
  ```

or
#### Azure PowerShell
```powershell

$serverName = "ArcBox-Win2K22"
$localUser = "Administrator"

Enter-AzVM -ResourceGroupName $Env:resourceGroup -Name $serverName -LocalUser $localUser -Rdp
```

  ![Screenshot showing usage of Remote Desktop tunnelled via SSH](./rdp_via_az_cli.png)

#### Task 4 - Optional: Azure AD/Entra ID based SSH Login


The `Azure AD based SSH Login – Azure Arc` VM extension can be added from the extensions menu of the Arc server in the Azure portal. The Azure AD login extension can also be installed locally via a package manager via: `apt-get install aadsshlogin` or the following command:

```
$serverName = "ArcBox-Ubuntu-01"

az connectedmachine extension create --machine-name $serverName --resource-group $Env:resourceGroup --publisher Microsoft.Azure.ActiveDirectory --name AADSSHLogin --type AADSSHLoginForLinux --location $env:azureLocation
```

- Configure role assignments for the Arc-enabled server _ArcBox-Ubuntu-01_ using the Azure portal.  Two Azure roles are used to authorize VM login:
   - **Virtual Machine Administrator Login**: Users who have this role assigned can log in to an Azure virtual machine with administrator privileges.
   - **Virtual Machine User Login**: Users who have this role assigned can log in to an Azure virtual machine with regular user privileges.

After assigning one of the two roles for your personal Azure AD/Entra ID user account, run the following command to connect to _ArcBox-Ubuntu-01_ using SSH and AAD/Entra ID-based authentication:

#### Azure CLI
```powershell
# Log out from the Service Principcal context
az logout

# Log in using your personal account
az login

$serverName = "ArcBox-Ubuntu-01"
$localUser = "arcdemo"

az ssh arc --resource-group $Env:resourceGroup --name $serverName
```

or

#### Azure PowerShell
```powershell
# Log out from the Service Principcal context
Disconnect-AzAccount

# Log in using your personal account
Connect-AzAccount

$serverName = "ArcBox-Ubuntu-01"
$localUser = "Administrator"

Enter-AzVM -ResourceGroupName $Env:resourceGroup -Name $serverName
```

You should now be connected and authenticated using your Azure AD/Entra ID account.


### Module 9: Manage your Azure Arc-enabled servers using Admin Center (Preview)

#### Module overview


In this module you will learn how to use the Windows Admin Center in the Azure portal to manage the Windows operating system of your Arc-enabled servers, known as hybrid machines. You can securely manage hybrid machines from anywhere without needing a VPN, public IP address, or other inbound connectivity to your machine.

#### Task 1: Pre-requisites

Pre-requisite: Azure permissions

- To install the Windows Admin Center extension for an Arc-enabled server resource, your account must be granted the Owner, Contributor, or Windows Admin Center Administrator Login role in Azure. **You should have this already on your internal subscription.**

- Connecting to Windows Admin Center requires you to have Reader and Windows Admin Center Administrator Login permissions at the Arc-enabled server resource.

    - Enter "Machines - Azure Arc" in the top search bar in the Azure portal and select it from the displayed services.

        ![Screenshot showing how to display Arc connected servers in portal](./Arc_servers_search.png)

    - Click on your Azure Arc-enabled **Windows** servers.

        ![Screenshot showing existing Arc connected servers](./click_on_any_arc_enabled_server.png)

    - From the selected Windows machine click "Access control (IAM)" then add the role "Admin Center Administrator Login" to your access.

        ![Screenshot of required role for Admin Center](./Admin_centre_Add_Role_1.png)

    - Follow similar steps to assign yourself Reader permissions at the Arc-enabled server resource.

#### Task 2: Deploy the Windows Admin Center VM extension

- Open the Azure portal and navigate to your Arc-enabled server.
- Under the Settings group, select Windows Admin Center, then click "Set up".
- Specify the port on which you wish to install Windows Admin Center, and then select Install.

    ![Screenshot deploy Admin Centre Extension](./Admin_center_install.png)

- If you get the following message after the installation is complete then you need to go back to the previous step and set up the permissions as explained in Pre-requisite.

    ![Screenshot permissions missing for Admin Centre](./Admin_Centre_install_message_1.png)

#### Task 3: Connect and explore Windows Admin Center (preview)

- Once the installation is complete then you can connect to the Windows Admin Center.

    ![Screenshot connecting to Admin Center](./Admin_Center_Connect.png)

- Start exploring the capabilities offered by the Windows Admin Center to manage your Arc-enabled Windows machine.

    ![Screenshot Admin Center overview](./Admin_Centre_Overview.png)

- Let us use the Windows Admin Center to add a local user, a new group and assign the new user to the new group.
    - From the left menu select "Local users & groups". Then from the "Users" tab click "New user". Enter the user details and click on "Submit". Verify that the user has been added.

        ![Screenshot adding local user](./Admin_center_local_users_1.png)

    - Now select the "Groups" tab and click on "New Group". Enter the group details and click on "Submit". Verify that the group has been added.

        ![Screenshot adding local group](./Admin_center_local_groups_1.png)

    - Back to the "Users" tab, select the new user you have added, then click "Manage membership". Add the selected user to the new group and save.

        ![Screenshot Group membership](./Admin_centre_group_membership_1.png)

### Module 10: Query and inventory your Azure Arc-enabled servers using Azure resource graph

#### Module overview

In this module, you will learn how to use the Azure Resource queries both in the Azure Graph Explorer and Powershell to demonstrate inventory management of your Azure Arc connected servers. Note that the results you get by running the graph queries in this module might be different from the sample screenshots as your environment might be different e.g. as a result of working with the other modules.

#### Task 1: Apply resource tags to Azure Arc-enabled servers

In this first step, you will assign Azure resource tags to some of your Azure Arc-enabled servers. This gives you the ability to easily organize and manage server inventory.

- Enter "Machines - Azure Arc" in the top search bar in the Azure portal and select it from the displayed services.

    ![Screenshot showing how to display Arc connected servers in portal](./Arc_servers_search.png)

- Click on any of your Azure Arc-enabled servers.

    ![Screenshot showing existing Arc connected servers](./click_on_any_arc_enabled_server.png)

- Click on "Tags". Add a new tag with Name="Scenario” and Value="azure_arc_servers_inventory”. Click Apply when ready.

    ![Screenshot showing adding tag to a server](./tagging_servers.png)

- Repeat the same process in other Azure Arc-enabled servers if you wish. This new tag will be used later when working with Resource Graph Explorer queries.

#### Task 2: The Azure Resource Graph Explorer

- Now we will explore our hybrid server inventory using a number of Azure Graph Queries. Enter "Resource Graph Explorer" in the top search bar in the Azure portal and select it.

    ![Screenshot of Graph Explorer in portal](./search_graph_explorer.png)

- The scope of the Resource Graph Explorer can be set as seen below

    ![Screenshot of Graph Explorer Scope](./Scope_of_Graph_Query.png)

#### Task 3: Run a query to show all Azure Arc-enabled servers in your subscription

- In the query window, enter and run the following query and examine the results which should show your Arc-enabled servers. Note the use of the KQL equals operator (=~) which is case insensitive [KQL =~ (equals) operator](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/equals-operator).

```shell
Resources \
| where type =~ 'Microsoft.HybridCompute/machines'
```

  ![Screenshot of query to list arc servers](./query_arc_machines.png)

- Scroll to the right on the results pane and click "See Details" to see all the Azure Arc-enabled server metadata. Note for example the list of detected properties, we will be using these in the next task.

- You can also run the same query using PowerShell (e.g. using Azure Cloud Shell) providing that you have added the required module "Az.ResourceGraph" as explained in [Run your first Resource Graph query using Azure PowerShell](https://learn.microsoft.com/azure/governance/resource-graph/first-query-powershell#add-the-resource-graph-module).

To install the PowerShell module, run the following command

```powershell
Install-Module -Name Az.ResourceGraph
```

Then run the query in PowerShell

```powershell
 Search-AzGraph -Query "Resources | where type =~ 'Microsoft.HybridCompute/machines'"
```

#### Task 4: Query your server inventory using the available metadata

- Use PowerShell and the Resource Graph Explorer to summarize the server count by "logical cores" which is one of the detected properties referred to in the previous task. Remember to only use the query string, which is enclosed in double quotes, in the portal.

```powershell
Search-AzGraph -Query  “Resources
| where type =~ 'Microsoft.HybridCompute/machines'
| extend logicalCores = tostring(properties.detectedProperties.logicalCoreCount)
| summarize serversCount = count() by logicalCores”
```

- The Graph Explorer allows you to get a graphical view of your results by selecting the "charts" option.

    ![Screenshot of the logicalCores server summary](./chart_for_vcpu_summay.png)

#### Task 5: Use the resource tags in your Graph Query.

- Let’s now build a query that uses the tag we assigned earlier to some of our Azure Arc-enabled servers. Use the following query that includes a check for resources that have a value for the Scenario tag. Feel free to use the portal of PowerShell. Check that the results match the servers that you set tags for earlier.

```powershell
Search-AzGraph -Query  “Resources
| where type =~ 'Microsoft.HybridCompute/machines' and isnotempty(tags['Scenario'])
| extend Scenario = tags['Scenario']
| project name, tags"
```

#### Task 6: List the extensions installed on the Azure Arc-enabled servers.

- Run the following advanced query which allows you to see what extensions are installed on the Arc-enabled servers. Notice that running the query in PowerShell requires us to escape the $ character as explained in [Escape Characters](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language#escape-characters)

```powershell
Search-AzGraph -Query “Resources
| where type == 'microsoft.hybridcompute/machines'
| project id, JoinID = toupper(id), ComputerName = tostring(properties.osProfile.computerName), OSName = tostring(properties.osName)
| join kind=leftouter(
    Resources
    | where type == 'microsoft.hybridcompute/machines/extensions'
    | project MachineId = toupper(substring(id, 0, indexof(id, '/extensions'))), ExtensionName = name
) on `$left.JoinID == `$right.MachineId
| summarize Extensions = make_list(ExtensionName) by id, ComputerName, OSName
| order by tolower(OSName) desc”
```

- If you have used the portal to run the query then you should see something like the following

    ![Screenshot of extensions query](./Extensions_query.png)

#### Task 7: Query other properties

- Azure Arc provides additional properties on the Azure Arc-enabled server resource that we can query with Resource Graph Explorer. In the following example, we list some of these key properties, like the Azure Arc Agent version installed on your Azure Arc-enabled servers

```powershell
Search-AzGraph -Query  “Resources
| where type =~ 'Microsoft.HybridCompute/machines'
| extend arcAgentVersion = tostring(properties.['agentVersion']), osName = tostring(properties.['osName']), osVersion = tostring(properties.['osVersion']), osSku = tostring(properties.['osSku']),
lastStatusChange = tostring(properties.['lastStatusChange'])
| project name, arcAgentVersion, osName, osVersion, osSku, lastStatusChange"
```

- Running the same query in the portal should result in something like the following

    ![Screenshot of extra properties](./extra_properties.png)

### Module 11: Enforce governance across your Azure Arc-enabled servers using Azure Policy

#### Module overview

In this module you will use Azure Policy to Audit Arc-enabled Linux servers that have a certain application installed

#### Task 1: Assign a built in Azure Policy to the Arc resource group

- Azure policy can be assigned at Management Group, Subscription or Resource Group scope. In this scenario we will use the Resource Group scope.
- In the Azure Portal search for the "Policy" resource and navigate to it.
- Click on "Compliance" in the left mene then click "Assign policy".

    ![Screenshot Navigate to policy assignment](./navigate_to_Policy_initiatives.png)

- Set the scope of the policy assignment to the subscription and the resource group as shown below

    ![Screenshot set Scope of policy](./choose_sub_RG.png)

- Click on the ellipsis next to "Policy definition". This opens the "Available Definitions" panel, where you can start searching for "Audit Linux machines that have the specific applications installed" policy which belongs to the "Guest Configuration" category. Select this policy as shown below.

    ![Screen shot select audit policy](./find_Linux_policy.png)

- Modify the "Assignment name" so that it would be easy to identify our policy in the compliance list later as shown below, then click "Next" twice to reach the "Parameters" tab.

    ![Screenshot change assignment name](./change_assignment_name.png)

- On the "Parameters" Screen, set the "Include Arc connected servers" to "true" and then set the name/s of the applications you want to audit the Linux servers for. If you have more than one application then include them in a semicolon separated list enclosed in single quotes e.g. 'App1; App2; App3'.

    ![Screenshot Arc_Nano](./Arc_Nano.png)

- Move to the "Non-compliance message" tab to add a message of your choice.

    ![Screenshot non-compliance message](./Non_compliance_message.png)

- Next move to the "Review + create" tab and click "Create" to assign the policy.

#### Task 2: Examine the policy compliance

- The creation of the assignment and for it to take effect and get evaluated might take some time. You can keep refreshing the "Compliance" list to until you can see an indication that there is at least one resource which is non-compliant with the policy we created (this depends on how many Arc-connected Linux servers with the specified applications we have). **If this does not happen in a reasonable time then go to task 3 where there is another view that is faster to show the compliance indication**.

    ![Screenshot of policies and their compliances with the new policy](./Compliance_dashboard.png)

- Click on the policy from the name column and this will take you a more detailed view of the specific policy compliance as shown below. You can then click on "details" which will open another panel on the right hand side. **If the "details" link is not ready yet then you will need to wait for it, or try task 3 for another way of looking at the compliance of specific servers, which is faster to populate.**

    ![Screenshot detailed compliance](./detailed_compliance.png)

- Click on the link below "Last evaluated resource ...". This will open the "Guest Assignment" screen showing exactly why that specific server is not compliant with the policy.

    ![Screenshot Guest Assignment from details](./Guest_assignment_from_details.png)

- The steps above helps you identify non-compliant resources and then you can act on resolving the non-compliance reasons.

#### Task 3: Using the "Guest Assignments" views directly

- As mentioned in Task 2, the policy compliance dashboard can sometimes take a long time before it is updated with the accurate compliance details. We can use a direct route to view the "Guest Assignments" for each resource by searching for "Guest Assignments" from the Azure portal and selecting it.

    ![Screenshot search for guest assignments](./search_for_guest_assignments.png)

- You can now look at the compliance of the individual resources and identify the ones that are affected by our policy assignment.

    ![Screenshot Guest Assignment details](./Guest_Assignment_Details.png)

- Click on the identified policy/resource combination and this will take you to the screen that we saw earlier at the end of Task 2, showing the details of the compliance/non-compliance.

### Module 12 : Gain security insights from your Arc-enabled servers using Microsoft Sentinel

#### Module overview

In this module you will configure Windows security events collection using Sentinel to inspect failed logins on your Windows Arc-enabled machine

#### Task 1: Configure data collection on Sentinel

- In the Azure Portal, search for _Sentinel_

    ![Screenshot showing searching for Sentinel on the Azure Portal](./portal_search_sentinel.png)

- Click on "Content Hub" and search for "Windows Security Events" and install it.

    ![Screenshot showing searching for windows security events](./sentinel_content_hub.png)

- After installation, click on "Manage" to configure the collector.

    ![Screenshot managing the data collection](./sentinel_manage_data_collector.png)

- Select the data connector and make sure you've selected the _Windows Security Events via AMA_ and click "open connector page".

    ![Screenshot selecting the AMA data collection](./sentinel_data_collector_ama.png)

- Create a new data collection rule.

    ![Screenshot showing creating a new data collection rule](./sentinel_create_new_dcr.png)

- Provide a name for the data collection rule and select the same resource group where you've deployed this level-up lab.

    ![Screenshot selecting the data collection rule name](./sentinel_dcr_creation.png)

- Select one or multiple Windows Arc-enabled machines.

    ![Screenshot selecting the arc machines](./sentinel_dcr_select_server.png)

- Select the "Common" event type and create the data collection rule.

    ![Screenshot selecting the common event type](./sentinel_security_events_common.png)

    ![Screenshot selecting the AMA data collection created](./sentinel_security_events_created.png)


#### Task 2: Simulating and viewing security events

- After configuring Sentinel, now we need to simulate some failed login attempts on one or more Windows Arc-enabled machines.

- Connect to _ArcBox-Client_ VM, and open the _Hyper-v manager_.

- Right-click one of the Windows machines and connect to it.

    ![Screenshot showing connecting to the nested vm on hyper-v](./hyperv_connect_vm.png)

- Simulate some failed login attempts by trying to login multiple times using an incorrect password.

    ![Screenshot showing failed login attemps on the nested vm](./hyperv_failed_login.png)

- After waiting for about 10-15 minutes for data to start getting ingested into the log analytics workspace, navigate to "Workbooks" and select the "Identity & Access" workbook.

    ![Screenshot selecting the Identity and access workbook](./sentinel_open_workbook.png)

- Once data is being ingested, you will start seeing the failed login attempts in the workbook.

    ![Screenshot selecting the Identity and access workbook](./sentinel_failed_login.png)
