########################################################################
# Connect to Azure
########################################################################

Write-Host "Connecting to Azure..."

# Install Azure module if not already installed
if (-not (Get-Command -Name Get-AzContext)) {
    Write-Host "Installing Azure module..."
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -ErrorAction Stop
}

# If not signed in, run the Connect-AzAccount cmdlet
if (-not (Get-AzContext)) {
    Write-Host "Logging in to Azure with subscription id $env:AZURE_SUBSCRIPTION_ID"
    If (-not (Connect-AzAccount -SubscriptionId $env:AZURE_SUBSCRIPTION_ID -ErrorAction Stop)){
        Throw "Unable to login to Azure. Please check your credentials and try again."
    }
}
$tenantId = (Get-AzContext).tenant.id
Write-Host "Setting Azure context with subscription id $env:AZURE_SUBSCRIPTION_ID and tenant id $tenantId..."
$context = Set-AzContext -SubscriptionId $env:AZURE_SUBSCRIPTION_ID -ErrorAction Stop

# Write-Host "Setting az subscription..."
az account set --subscription $env:AZURE_SUBSCRIPTION_ID

# Register providers
Write-Host "Registering Azure providers..."
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait
az provider register --namespace Microsoft.OperationsManagement --wait
az provider register --namespace Microsoft.AzureStackHCI --wait
az provider register --namespace Microsoft.ResourceConnector --wait
az provider register --namespace Microsoft.OperationalInsights --wait


########################################################################
# Check for available capacity in region
########################################################################
#region Functions
Function Get-AzAvailableCores ($location, $skuFriendlyNames, $minCores = 0) {
    # using az command because there is currently a bug in various versions of PowerShell that affects Get-AzVMUsage
    $usage = (az vm list-usage --location $location --output json --only-show-errors) | ConvertFrom-Json

    $usage = $usage | 
        Where-Object {$_.localname -match $skuFriendlyNames} 

    $enhanced = $usage |
        ForEach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name available -Value 0 -Force -PassThru
            $_.available = $_.limit - $_.currentValue
        }

    $enhanced = $enhanced |
        ForEach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name usableLocation -Value $false -Force -PassThru
            If ($_.available -ge $minCores) {
                $_.usableLocation = $true
            } 
            else {
                $_.usableLocation = $false
            }
        }

    $enhanced

}

Function Get-AzAvailableLocations ($location, $skuFriendlyNames, $minCores = 0) {
    $allLocations = get-AzLocation
    $geographyGroup = ($allLocations | Where-Object {$_.location -eq $location}).GeographyGroup
    $locations = $allLocations | Where-Object { `
            $_.GeographyGroup -eq $geographyGroup `
            -and $_.Location -ne $location `
            -and $_.RegionCategory -eq "Recommended" `
            -and $_.PhysicalLocation -ne ""
        }

    $usableLocations = $locations | 
        ForEach-Object {
            $available = Get-AzAvailableCores -location $_.location -skuFriendlyNames $skuFriendlyNames -minCores $minCores |
                Where-Object {$_.localName -ne "Total Regional vCPUs"}
            If ($available.usableLocation) {
                $_ | Add-Member -MemberType NoteProperty -Name TotalCores     -Value $available.limit -Force 
                $_ | Add-Member -MemberType NoteProperty -Name AvailableCores -Value $available.available -Force 
                $_ | Add-Member -MemberType NoteProperty -Name usableLocation -Value $available.usableLocation -Force -PassThru
            }
        }

    $usableLocations
}
#endregion Functions

$location = $env:AZURE_LOCATION
$minCores = 32 # 32 vCPUs required for standard deployment with E32s v5
$skuFriendlyNames = "Standard ESv5 Family vCPUs|Total Regional vCPUs"

Write-Host "`nChecking for available capacity in $location region..."

$available = Get-AzAvailableCores -location $location -skuFriendlyNames $skuFriendlyNames -minCores $minCores

If ($available.usableLocation -contains $false) {
    Write-Host "`n`u{274C} There is not enough VM capacity in the $location region to deploy the Jumpstart environment." -ForegroundColor Red
    
    Write-Host "`nChecking other regions in the same geography with enough capacity ($minCores cores)...`n"

    $locations = Get-AzAvailableLocations -location $location -skuFriendlyNames $skuFriendlyNames -minCores $minCores | 
        Format-Table Location, DisplayName, TotalCores, AvailableCores, UsableLocation -AutoSize | Out-String
    
    Write-Host $locations

    Write-Host "Please run ``azd env --new`` to create a new environment and select the new location.`n"

    $message = "Not enough capacity in $location region."
    Throw $message

} else {
    Write-Host "`n`u{2705} There is enough VM capacity in the $location region to deploy the Jumpstart environment.`n"
}


########################################################################
# Get Windows Admin Username and Password
########################################################################
$JS_WINDOWS_ADMIN_USERNAME = 'arcdemo'
if ($promptOutput = Read-Host "Enter the Windows Admin Username [$JS_WINDOWS_ADMIN_USERNAME]") { $JS_WINDOWS_ADMIN_USERNAME = $promptOutput }

# set the env variable
azd env set JS_WINDOWS_ADMIN_USERNAME -- $JS_WINDOWS_ADMIN_USERNAME

########################################################################
# Use Azure Bastion?
########################################################################
$promptOutput = Read-Host "Configure Azure Bastion for accessing HCIBox host [Y/N]?"
$JS_DEPLOY_BASTION = $false
if ($promptOutput -like 'y')
{
    $JS_DEPLOY_BASTION = $true
}

# set the env variable
azd env set JS_DEPLOY_BASTION $JS_DEPLOY_BASTION

########################################################################
# RDP Port
########################################################################
$JS_RDP_PORT = '3389'
If ($env:JS_RDP_PORT) {
    $JS_RDP_PORT = $env:JS_RDP_PORT
}
if ($promptOutput -notlike 'y') {
    if ($promptOutput = Read-Host "Enter the RDP Port for remote desktop connection [$JS_RDP_PORT]") 
    { 
        $JS_RDP_PORT = $promptOutput 
    }
}


# set the env variable
azd env set JS_RDP_PORT $JS_RDP_PORT

# Attempt to retrieve provider id for Microsoft.AzureStackHCI
Write-Host "Attempting to retrieve Microsoft.AzureStackHCI provider id..."
$spnProviderId=$(az ad sp list --display-name "Microsoft.AzureStackHCI" --output json) | ConvertFrom-Json
 if ($null -ne $spnProviderId.id) {
    azd env set SPN_PROVIDER_ID -- $($spnProviderId.id)
 }
 else {
    Write-Warning "Microsoft.AzureStackHCI provider id not found, aborting..."
    
    Write-Host 'Consider the following options: 1) Request access from a tenant administrator to get read-permissions to service principals.
    2) Ask a tenant administrator to run the command $(az ad sp list --display-name "Microsoft.AzureStackHCI" --output json) | ConvertFrom-Json and send you the ID from the output. You can then manually add that value to the AZD .env file: SPN_PROVIDER_ID="xxx" or use the Bicep-based deployment specifying spnProviderId="xxx" in the deployment parameter-file.' -ForegroundColor Yellow
    throw "Microsoft.AzureStackHCI provider id not found"
}

########################################################################
# Create Azure Service Principal
########################################################################
Write-Host "Checking for existing stored Azure service principal..."
if ($null -ne $env:SPN_CLIENT_ID) {
    Write-Host "Re-using existing service principal..."
} else {
    Write-Host "Attempting to create new service principal with scope /subscriptions/$($env:AZURE_SUBSCRIPTION_ID)..."
    $user = (Get-AzContext).Account.Id.split("@")[0]
    $uniqueSpnName = "$user-jumpstart-spn-$(Get-Random -Minimum 1000 -Maximum 9999)"
    try {
        $spn = New-AzADServicePrincipal -DisplayName $uniqueSpnName -Role "Owner" -Scope "/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)" -ErrorAction Stop
        $SPN_CLIENT_ID = $spn.AppId
        $SPN_CLIENT_SECRET = $spn.PasswordCredentials.SecretText
        $SPN_TENANT_ID = (Get-AzContext).Tenant.Id
        # Set environment variables
        azd env set SPN_CLIENT_ID -- $SPN_CLIENT_ID
        azd env set SPN_CLIENT_SECRET -- $SPN_CLIENT_SECRET
        azd env set SPN_TENANT_ID -- $SPN_TENANT_ID
    }
    catch {
        
        If ($error[0].ToString() -match "Forbidden"){
            Throw "You do not have permission to create a service principal. Please contact your Azure subscription administrator to grant you the Owner role on the subscription."
        }
        else {
            Throw "An error occurred creating the service principal. Error:" + $error[0].ToString()
        }
    }
    
}
