param (
    [string]$servicePrincipalAppId,
    [string]$servicePrincipalSecret,        
    [string]$servicePrincipalTenantId
)

Start-Transcript -Path C:\ArcBox\installArcAgentSQL.log
$ErrorActionPreference = 'SilentlyContinue'

# These settings will be replaced by the portal when the script is generated
$subId = $subscriptionId
$resourceGroup = $myResourceGroup
$location = $azureLocation
$proxy=""
$resourceTags= @{"Project"="jumpstart_arcbox"}
$arcMachineName = "ArcBox-SQL"
$workspaceName = $logAnalyticsWorkspaceName

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
# For security purposes, passwords should be stored in encrypted files as secure strings
#
$servicePrincipalAppId = $spnClientId
$servicePrincipalTenantId = $spnTenantId
$servicePrincipalSecret = $spnClientSecret

$unattended = $servicePrincipalAppId -And $servicePrincipalTenantId -And $servicePrincipalSecret

$azurePassword = ConvertTo-SecureString $servicePrincipalSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($servicePrincipalAppId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $servicePrincipalTenantId -ServicePrincipal

function Install-PowershellModule() {
    # Ask for user confirmation if running manually
    #
    if ( ! $unattended) {
        $title = 'Confirm Dependency Installation'
        $question = 'The Azure PowerShell Module is required in order to register SQL Server - Azure Arc resources. Would you like to install it now?'
        $choices = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 1) {
            Write-Warning "Azure module install declined."
            return
        }
    }
    # Check if requirements are met for Powershell module install
    #
    $version = $PSVersionTable.PSVersion
    if ([version]$version -lt [version]"5.1") {
        Write-Warning -Category NotInstalled -Message "Could not install Az module: Az module requires Powershell version 5.1.* or above."
        return
    }
    if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
        if ([version]$version -lt [version]"6.2.4") {
            Write-Warning -Category NotInstalled -Message ("Could not install Az module: Powershell $version does not support having both the AzureRM and Az modules installed. " +
                "If you need to keep AzureRM available on your system, install the Az module for PowerShell 6.2.4 or later. " +
                "For more information, see: https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az")
            return
        }

        Write-Warning -Message "The Az module will be installed alongside the existing AzureRM module."
    }

    Write-Verbose "Installing Az module for PowerShell"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
}

function registerArcForServers() {
    # Download the package
    #
    $ProgressPreference = "SilentlyContinue"; 
    Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi
    
    # Install the package
    #
    Write-Host "Installing the Azure Arc for Servers package"
    $params = @("/i", "AzureConnectedMachineAgent.msi", "/l*v", "installationlog.txt", "/qn")
    
    $install_success = (Start-Process -FilePath msiexec.exe -ArgumentList $params -Wait -Passthru).ExitCode
    if ($install_success -ne 0) {
        Write-Error -Message "Azure Arc for Servers package installation failed."
        return
    }

    if ($proxy) {
        # Set the proxy environment variable. Note that authenticated proxies are not supported for Public Preview.
        [System.Environment]::SetEnvironmentVariable("https_proxy", $proxy, "Machine")
        $env:https_proxy = [System.Environment]::GetEnvironmentVariable("https_proxy", "Machine")
        
        # The agent service needs to be restarted after the proxy environment variable is set in order for the changes to take effect.
        Restart-Service -Name himds
    }

    Write-Host "Connecting Azure Connected Machine Agent"
    $context = Get-AzContext
    $params = @("connect", "--resource-group", $resourceGroup, "--location", $location, "--subscription-id", $subId, "--tenant-id", $context.Tenant, "--tags", $resourceTags, "--correlation-id", "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a")

    if ($unattended) {
        $password = $servicePrincipalSecret
        if ($servicePrincipalSecret -is [SecureString]) {
            $cred = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipalAppId, $servicePrincipalSecret)
            $password = $cred.GetNetworkCredential().Password
        } 
        $params += "--service-principal-id"
        $params += $servicePrincipalAppId
        $params += "--service-principal-secret"
        $params += $password
    }
    elseif (Get-InstalledModule -Name Az.Accounts -MinimumVersion 2.2) {
        # New versions of Az.Account support getting access tokens
        #
        $token = Get-AzAccessToken
        $params += "--access-token"
        $params += $token.Token
    }

    & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" $params

    if ($LastExitCode -ne 0) {
        Write-Error -Message "Failure when connecting Azure Connected Machine Agent."
        return
    }
}

function checkResourceCreation($newResource, $instProp, $name) {
    if ($null -eq $newResource) {
        Write-Host ("Failed to create resource: {0}" -f $name)
        return
    }
    else {
        Write-Host ("SQL Server - Azure Arc resource: {0} created" -f $resource_name)
    }
    $errors = New-Object System.Collections.ArrayList
    foreach ($key in $instProp.Keys) {
        # check that key exists in created resource
        if (Get-Member -inputobject $newResource.Properties -name $key -Membertype Properties) {
            $expectedvalue = $instProp[$key]
            $foundValue = ($newResource.Properties).$key
            if ($expectedvalue -ne $foundValue) {
                $errors.Add("Property {0} has value of {1}, but expected {2}" -f $key, $foundValue, $expectedvalue) > $null
            }
        }
        else {
            $errors.Add("Property {0} expected, but not present in Azure Resource" -f $key) > $null
        }
    }
    if ($errors.Count -ne 0) {
        Write-Host ("Errors found when creating resource: {0}" -f $newResource.Name)
        foreach ($e in $errors) {
            Write-Warning $e
        }
    }
    else {
        $newResource
    }
}

# Confirm that Azure powershell module is installed, and install if not present
#
if (-Not (Get-InstalledModule -Name Az -ErrorAction SilentlyContinue)) {
    Install-PowershellModule
    if (-Not (Get-InstalledModule -Name Az -ErrorAction SilentlyContinue)) {
        Write-Warning -Category NotInstalled -Message "Failed to install Azure Powershell Module. Please confirm that Az module is installed before continuing."
        return
    }
}
else
{
    Write-Verbose "Az already installed. Skipping installation."
}


if (-Not (Get-InstalledModule -Name Az.ConnectedMachine  -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Az.connectedMachine module."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-Module -Name Az.ConnectedMachine | Install-Module  -Force
}
else
{
    Write-Verbose "Az.ConnectedMachine already installed. Skipping installation."
}

if (-Not (Get-InstalledModule -Name Az.Resources  -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Az.Resources module."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-Module -Name Az.Resources | Install-Module  -Force
}
else
{
    Write-Verbose "Az.Resources already installed. Skipping installation."
}

# For manual Azure Arc registration, an access token prevents a duplicate Azure login
# Getting an access token is only supported in Az.Accounts 2.2 or up
#
if (-Not (Get-InstalledModule -Name Az.Accounts -MinimumVersion 2.2  -ErrorAction SilentlyContinue) -and -Not $unattended) {
    Write-Warning "For the best user experience, we recommend updating the Az.Accounts module. Please confirm installation."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name Az.Accounts -MinimumVersion 2.2 -Confirm -Force
}

# Confirm that user is signed in to Azure powershell module
#
$context = Get-AzContext
if (!$context) {
    if ($unattended) {
        $securePassword = $servicePrincipalSecret
        if ($servicePrincipalSecret -is [String]) {
            Write-Warning -Message "Saving a plaintext password presents a security risk. Consider storing your password in a secure file."
            $securePassword = ConvertTo-SecureString -String $servicePrincipalSecret -AsPlainText -Force
        }
        $pscredential = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipalAppId, $securePassword)
        Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $servicePrincipalTenantId
    }
    else {
        Write-Host "Please connect your Azure account."
        Connect-AzAccount -UseDeviceAuthentication
    }
    $context = Get-AzContext
    if (!$context) {
        Write-Warning -Category AuthenticationError -Message "Please connect your Azure account with `"Connect-AzAccount`" before continuing."
        return
    }
}

if (-Not (Set-AzContext -Subscription $subId -ErrorAction SilentlyContinue)) {
    Write-Warning "Unable to set context to $subId. It is possible that given subscription not found in logged in context."
    return
}

$arcResource = Get-AzConnectedMachine -ResourceGroupName $resourceGroup -Name $arcMachineName -ErrorAction SilentlyContinue

if ($null -eq $arcResource) {
    Write-Host "Arc for Servers resource not found. Registering the current machine now."
    $params = @{
        ResourceGroupName=$resourceGroup
        Name=$arcMachineName
        Location=$location
    }
    if ($proxy) {
        $params['Proxy'] = $proxy
    }

    Connect-AzConnectedMachine @params -ErrorAction SilentlyContinue
}

$arcResource = Get-AzConnectedMachine -ResourceGroupName $resourceGroup -Name $arcMachineName -ErrorAction SilentlyContinue

if (!$arcResource) {
    Write-Warning -Message "Failed to register machine with Azure Arc for Servers. Exiting."
    return
}

Start-Sleep -Seconds 60
Write-Verbose "Getting managed Identity ID of $arcMachineName."

$spID = $arcResource.IdentityPrincipalId


if($null -eq $spID) {
    Write-Warning -Message "Failed to get $arcMacineName Identity Id. Please check if Arc machine exist and rerun this step."
    return
}

$currentRoleAssignment = $null
$retryCount = 10
$count = 0
$waitTimeInSeconds = 10
# while(!$currentRoleAssignment -and $count -le $retryCount)
# {
#     Write-Host "Arc machine managed Identity does not have Azure Connected SQL Server Onboarding role. Assigning it now."
#     $currentRoleAssignment = New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
#     sleep $waitTimeInSeconds
#     $count++
# }
Write-Host "Arc machine managed Identity requires Azure Connected SQL Server Onboarding role. Assigning it now."
while($count -le $retryCount)
{
    $currentRoleAssignment = New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
    sleep $waitTimeInSeconds
    $count++
}

Write-Host "Installing SQL Server - Azure Arc extension. This may take 5+ minutes."

$Settings = '{ "SqlManagement" : { "IsEnabled" : true }}'

$result = New-AzConnectedMachineExtension -Name "WindowsAgent.SqlServer" -ResourceGroupName $resourceGroup -MachineName $arcMachineName -Location $location -Publisher "Microsoft.AzureData" -Settings $Settings -ExtensionType "WindowsAgent.SqlServer" -Tag $resourceTags

if($result.ProvisioningState -eq "Failed")
{
    Write-Warning "Extension Installation Failed. Arc enabled SQL server instances will not be created. Please find more information below."
    $result
}

Write-Host "SQL Server - Azure Arc resources should show up in resource group in less than 1 minute."

# Get the resource group
Get-AzResourceGroup -Name $resourceGroup -ErrorAction Stop -Verbose

Write-Host "Enabling Log Analytics Solutions"
$Solutions = "Security", "Updates", "SQLAssessment"
foreach ($solution in $Solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $resourceGroup -WorkspaceName $workspaceName -IntelligencePackName $solution -Enabled $true -Verbose
}

# Get the workspace ID and Key
az login --service-principal --username $servicePrincipalAppId --password $servicePrincipalSecret --tenant $servicePrincipalTenantId
$workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName --query primarySharedKey -o tsv)

$Setting = @{ "workspaceId" = $workspaceId }
$protectedSetting = @{ "workspaceKey" = $workspaceKey }
New-AzConnectedMachineExtension -Name "MicrosoftMonitoringAgent" -ResourceGroupName $resourceGroup -MachineName $env:computername -Location $location -Publisher "Microsoft.EnterpriseCloud.Monitoring" -TypeHandlerVersion "1.0.18040.2" -Settings $Setting -ProtectedSetting $protectedSetting -ExtensionType "MicrosoftMonitoringAgent"
Start-Sleep -Seconds 60

$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

Write-Host "Create SQL Azure Assessment"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/Microsoft.PowerShell.Oms.Assessments.zip" -OutFile "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip"
Expand-Archive "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip" -DestinationPath 'C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell'
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\"
Import-Module "C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\Microsoft.PowerShell.Oms.Assessments.dll"
$SecureString = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
Add-SQLAssessmentTask -SQLServerName $env:computername -WorkingDirectory "C:\sql_assessment\work_dir" -RunWithManagedServiceAccount $False -ScheduledTaskUsername $env:USERNAME -ScheduledTaskPassword $SecureString

$name = "Recurring HealthService Restart"
$repeat = (New-TimeSpan -Minutes 10)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Restart-Service -Name HealthService -Force"
$duration = (New-TimeSpan -Days 1)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval $repeat -RepetitionDuration $duration
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -RunLevel Highest -User $nestedWindowsUsername -Password $nestedWindowsPassword -Settings $settings
Start-Sleep -Seconds 3
Start-ScheduledTask -TaskName $name

Stop-Transcript