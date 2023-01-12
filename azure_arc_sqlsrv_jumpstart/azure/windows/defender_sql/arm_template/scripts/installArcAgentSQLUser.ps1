﻿param ($servicePrincipalAppId, $servicePrincipalTenantId, $servicePrincipalSecret)

# These settings will be replaced by the portal when the script is generated
$subId = "<subscriptionId>"
$resourceGroup = "<resourceGroup>"
$location = "<location>"
$proxy=""
$resourceTags= @{}
$arcMachineName = [Environment]::MachineName

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
# For security purposes, passwords should be stored in encrypted files as secure strings
#
#$servicePrincipalAppId = ''
#$servicePrincipalTenantId = ''
#$servicePrincipalSecret = ''

$unattended = $servicePrincipalAppId -And $servicePrincipalTenantId -And $servicePrincipalSecret
$ErrorActionPreference = 'Stop'

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
if (-Not (Get-InstalledModule -Name Az -MinimumVersion 8.0.0 -ErrorAction SilentlyContinue)) {
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

if (-Not (Get-InstalledModule -Name Az.ConnectedMachine -MinimumVersion 0.4.0 -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Az.connectedMachine module."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-Module -Name Az.ConnectedMachine | Install-Module -Force
}
else
{
    Write-Verbose "Az.ConnectedMachine already installed. Skipping installation."
}

if (-Not (Get-InstalledModule -Name Az.Resources -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Az.Resources module."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-Module -Name Az.Resources | Install-Module -Force
}
else
{
    Write-Verbose "Az.Resources already installed. Skipping installation."
}

# For manual Azure Arc registration, an access token prevents a duplicate Azure login
# Getting an access token is only supported in Az.Accounts 2.2 or up
#
if (-Not (Get-InstalledModule -Name Az.Accounts -MinimumVersion 2.2 -ErrorAction SilentlyContinue) -and -Not $unattended) {
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

$roleWritePermissions = Get-AzRoleAssignment -Scope "/subscriptions/$subId/resourcegroups/$resourceGroup/providers/Microsoft.Authorization/roleAssignments/write"

if(!$roleWritePermissions)
{
    Write-Warning "User does not have permissions to assign roles. This is pre-requisite to on board SQL Server - Azure Arc resources."
    return
}


# Check if the machine is registered with Azure Arc-enabled servers
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
    Write-Warning -Message "Failed to register the machine with Azure Arc-enabled servers. Exiting."
    return
}

Write-Verbose "Getting managed Identity ID of $arcMachineName."

$spID = $arcResource.IdentityPrincipalId


if($null -eq $spID) {
    Write-Warning -Message "Failed to get $arcMacineName Identity Id. Please check if Arc machine exist and rerun this step."
    return
}

$currentRoleAssignment = Get-AzRoleAssignment -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ObjectId $spID -ResourceGroupName $resourceGroup

$retryCount = 6
$count = 0
$waitTimeInSeconds = 10

while(!$currentRoleAssignment -and $count -le $retryCount)
{
    Write-Host "Arc machine managed Identity does not have Azure Connected SQL Server Onboarding role. Assigning it now."
    $currentRoleAssignment = New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Azure Connected SQL Server Onboarding" -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
    sleep $waitTimeInSeconds
    $count++
}

if(!$currentRoleAssignment)
{
    Write-Verbose "Unable to assign Azure Connected SQL Server Onboarding role to Arc managed Identity. Skipping role assignment."
    return
}


Write-Host "Installing SQL Server - Azure Arc extension. This may take 5+ minutes."

$settings = @{ SqlManagement = @{ IsEnabled = $true }}

$result = New-AzConnectedMachineExtension -Name "WindowsAgent.SqlServer" -ResourceGroupName $resourceGroup -MachineName $arcMachineName -Location $location -Publisher "Microsoft.AzureData" -Settings $settings -ExtensionType "WindowsAgent.SqlServer" -Tag $resourceTags

if($result.ProvisioningState -eq "Failed")
{
    Write-Warning "Extension Installation Failed. Arc enabled SQL server instances will not be created. Please find more information below."
    $result
}

Write-Host "SQL Server - Azure Arc resources should show up in resource group in less than 1 minute."
