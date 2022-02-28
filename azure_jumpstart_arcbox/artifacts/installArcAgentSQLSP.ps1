param (
    [string]$servicePrincipalAppId,
    [string]$servicePrincipalSecret,        
    [string]$servicePrincipalTenantId
)

$ArcBoxLogsDir = "C:\ArcBox\Logs"

Start-Transcript -Path $ArcBoxLogsDir\installArcAgentSQL.log

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

function Get-AzSPNRoleAssignment {
    param(
        [Parameter(Mandatory=$false)]
        [string]$RoleDefinitionName,

        [Parameter(Mandatory=$false)]
        [string]$ObjectId,

        [Parameter(Mandatory=$false)]
        [string]$SubscriptionName,

        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName
    )

    if(-not $SubscriptionName) {
        $SubscriptionName = (Get-AzContext).Subscription.Id
    }

    if($ResourceGroupName) {
        try {
            Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null
        } catch {
            throw [System.Exception]::new("Invalid ResourceGroupName", $PSItem.Exception)
        }

        $scope = "/subscriptions/$SubscriptionName/resourceGroups/$ResourceGroupName"
    } else {
        $scope = "/subscriptions/$SubscriptionName"
    }

    $restResponse = Invoke-AzRestMethod -Path "$scope/providers/Microsoft.Authorization/roleAssignments?api-version=2015-07-01" -Method GET

    if($restResponse.StatusCode -eq 200) {
        $roleAssignments = ($restResponse.Content | ConvertFrom-Json).value
    } else {
        $errorDetails = ($restResponse.Content | ConvertFrom-Json).error
        throw [System.Exception]::new($errorDetails.code, $errorDetails.message)
    }

    if($RoleDefinitionName -and $ObjectId) {
        if($RoleDefinitionName -ne "write") {
            $roleDefId = @((Get-AzRoleDefinition -Name $RoleDefinitionName).Id)
        } else {
            $actionList = @('*', 'Microsoft.Authorization/roleAssignments/write', 'Microsoft.Authorization/*', 'Microsoft.Authorization/*/write')
            $roleDefId = @(Get-AzRoleDefinition | Where-Object { (Compare-Object $actionList $_.Actions -IncludeEqual -ExcludeDifferent) -and -not (Compare-Object $actionList $_.NotActions -IncludeEqual -ExcludeDifferent) } | Select-Object -ExpandProperty Id)
        }

        $spnRoleAssignments = @($roleAssignments | Where-Object { $_.properties.principalId -eq $ObjectId } | Select-Object -ExpandProperty properties | Where-Object { $roleDefId -contains ($_.roleDefinitionId -replace ".+(?=/)/") })
    } elseif ($ObjectId) {
        $spnRoleAssignments = @($roleAssignments | Where-Object { $_.properties.principalId -eq $ObjectId } | Select-Object -ExpandProperty properties)
    } else {
        $spnRoleAssignments = @($roleAssignments | Select-Object -ExpandProperty properties)
    }

    return $spnRoleAssignments
}

function New-AzSPNRoleAssignment {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RoleDefinitionName,

        [Parameter(Mandatory=$true)]
        [string]$ObjectId,

        [Parameter(Mandatory=$false)]
        [string]$SubscriptionName,

        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName
    )
    
    if(-not $SubscriptionName) {
        $SubscriptionName = (Get-AzContext).Subscription.Id
    }

    if($ResourceGroupName) {
        try {
            Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null
        } catch {
            throw [System.Exception]::new("Invalid ResourceGroupName", $PSItem.Exception)
        }

        $scope = "/subscriptions/$SubscriptionName/resourceGroups/$ResourceGroupName"
    } else {
        $scope = "/subscriptions/$SubscriptionName"
    }

    $roleDefId = (Get-AzRoleDefinition -Name $RoleDefinitionName).Id

    if(-not $roleDefId) {
        throw [System.Exception]::new("Invalid RoleDefinitionName", "No role definitions were found with those conditions")
    }

    $payload = @{
        properties = @{
            roleDefinitionId = "$scope/providers/Microsoft.Authorization/roleDefinitions/$roleDefId"
            principalId      = $ObjectId
            scope            = $scope
        }
    }

    $patchParams = @{
        ResourceProviderName = 'Microsoft.Authorization'
        ResourceType = 'roleAssignments'
        ApiVersion = '2015-07-01'
        Payload = $payload | ConvertTo-Json
        Method = 'PUT'
        Name = $(New-Guid).guid
    }

    if($ResourceGroupName) {
        $patchParams.Add("ResourceGroupName", $ResourceGroupName)
    }

    $restResponse = Invoke-AzRestMethod @patchParams

    if($restResponse.StatusCode -eq 201) {
        return ($result.Content | ConvertFrom-Json | Select-Object -ExpandProperty properties)
    } elseif ($restResponse.StatusCode -eq 409) {
        return Get-AzSPNRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleDefinitionName -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName
    } else {
        $errorDetails = ($restResponse.Content | ConvertFrom-Json).error
        throw [System.Exception]::new($errorDetails.code, $errorDetails.message)
    }
}

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

$spnObjectId = $(Get-AzADServicePrincipal -ApplicationId $(Get-AzContext).Account.Id).Id
$roleWritePermissions = Get-AzSPNRoleAssignment -RoleDefinitionName "write" -ObjectId $spnObjectId -ResourceGroupName $resourceGroup

if(!$roleWritePermissions)
{
    Write-Warning "User does not have permissions to assign roles. This is pre-requisite to on board SQL Server - Azure Arc resources."
    return
}

# Check if machine is registered with Azure Arc for Servers
# Register machine if necessary
#
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

$currentRoleAssignment = Get-AzSPNRoleAssignment -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ObjectId $spID -ResourceGroupName $resourceGroup

$retryCount = 6
$count = 0
$waitTimeInSeconds = 10

while(!$currentRoleAssignment -and $count -le $retryCount)
{
    Write-Host "Arc machine managed Identity does not have Azure Connected SQL Server Onboarding role. Assigning it now."
    $currentRoleAssignment = New-AzSPNRoleAssignment -ObjectId $spID -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
    Start-Sleep $waitTimeInSeconds
    $count++
}

if(!$currentRoleAssignment)
{
    Write-Verbose "Unable to assign Azure Connected SQL Server Onboarding role to Arc managed Identity. Skipping role assignment."
    return
}

Write-Host "Installing SQL Server - Azure Arc extension. This may take 5+ minutes."

$settings = '{ "SqlManagement" : { "IsEnabled" : true }}'

$result = New-AzConnectedMachineExtension -Name "WindowsAgent.SqlServer" -ResourceGroupName $resourceGroup -MachineName $arcMachineName -Location $location -Publisher "Microsoft.AzureData" -Settings $settings -ExtensionType "WindowsAgent.SqlServer" -Tag $resourceTags

if($result.ProvisioningState -eq "Failed")
{
    Write-Warning "Extension Installation Failed. Arc enabled SQL server instances will not be created. Please find more information below."
    $result
}

Write-Host "SQL Server - Azure Arc resources should show up in resource group in less than 1 minute."

# Get the resource group
Get-AzResourceGroup -Name $resourceGroup -ErrorAction Stop -Verbose

Write-Host "Enabling Log Analytics Solutions"
$solutions = "Security", "Updates", "SQLAssessment"
foreach ($solution in $solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $resourceGroup -WorkspaceName $workspaceName -IntelligencePackName $solution -Enabled $true -Verbose
}

# Get the workspace ID and Key
$workspaceId = $(Get-AzOperationalInsightsWorkspace -Name $workspaceName -ResourceGroupName $resourceGroup).CustomerId.Guid
$workspaceKey = $(Get-AzOperationalInsightsWorkspaceSharedKey -Name $workspaceName -ResourceGroupName $resourceGroup).PrimarySharedKey

$Setting = @{ "workspaceId" = $workspaceId }
$protectedSetting = @{ "workspaceKey" = $workspaceKey }
New-AzConnectedMachineExtension -Name "MicrosoftMonitoringAgent" -ResourceGroupName $resourceGroup -MachineName $arcMachineName -Location $location -Publisher "Microsoft.EnterpriseCloud.Monitoring" -TypeHandlerVersion "1.0.18040.2" -Settings $Setting -ProtectedSetting $protectedSetting -ExtensionType "MicrosoftMonitoringAgent"

$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

Write-Host "Create SQL Azure Assessment"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/Microsoft.PowerShell.Oms.Assessments.zip" -OutFile "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip"
Expand-Archive "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip" -DestinationPath 'C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell'
$Env:PSModulePath = $Env:PSModulePath + ";C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\"
Import-Module "C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\Microsoft.PowerShell.Oms.Assessments.dll"
$SecureString = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
Add-SQLAssessmentTask -SQLServerName $Env:COMPUTERNAME -WorkingDirectory "C:\sql_assessment\work_dir" -RunWithManagedServiceAccount $False -ScheduledTaskUsername $Env:USERNAME -ScheduledTaskPassword $SecureString

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
