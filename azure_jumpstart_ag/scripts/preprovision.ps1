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
    Write-Host "Logging in to Azure..."
    If (-not (Connect-AzAccount -SubscriptionId $env:AZURE_SUBSCRIPTION_ID -ErrorAction Stop)){
        Throw "Unable to login to Azure. Please check your credentials and try again."
    }
}

# Write-Host "Getting Azure Tenant Id..."
$tenantId = (Get-AzSubscription -SubscriptionId $env:AZURE_SUBSCRIPTION_ID).TenantId

# Write-Host "Setting Azure context..."
$context = Set-AzContext -SubscriptionId $env:AZURE_SUBSCRIPTION_ID -Tenant $tenantId -ErrorAction Stop

# Write-Host "Setting az subscription..."
$azLogin = az account set --subscription $env:AZURE_SUBSCRIPTION_ID


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

Function Get-AzAvailablePublicIpAddress ($location, $subscriptionId, $minPublicIP = 0) {
    
    $accessToken = az account get-access-token --query accessToken -o tsv
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Network/locations/$location/usages?api-version=2023-02-01"

    $publicIpCount = (Get-AzPublicIpAddress | where-object {$_.location -eq $location} | measure-object).count
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

    $limit = ($response.value | where-object { $_.name.value -eq "PublicIPAddresses"}).limit

    $availableIP = $limit - $publicIpCount

    $availableIP

}

#endregion Functions

$location = $env:AZURE_LOCATION
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$minCores = 32
$minPublicIP = 3
$skuFriendlyNames = "Standard DSv5 Family vCPUs|Total Regional vCPUs"

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

Get-AzAvailablePublicIpAddress -location $location -subscriptionId $subscriptionId -minPublicIP $minPublicIP

Write-Host "PIP1 $minPublicIP"
Write-Host "PIP2 $availableIP"
If ($availableIP -le $minPublicIP) {
    $requiredIp = $minPublicIP - $availableIP
    Write-Host "`n`u{274C} There is not enough Public IP in the $location region to deploy the Jumpstart environment. Need addtional $requiredIp Public IP." -ForegroundColor Red
} else {
    Write-Host "`n`u{2705} There is enough Public IP in the $location region to deploy the Jumpstart environment.`n"
}

########################################################################
# Get Windows Admin Username and Password
########################################################################
$JS_WINDOWS_ADMIN_USERNAME = 'agora'
if ($promptOutput = Read-Host "Enter the Windows Admin Username [$JS_WINDOWS_ADMIN_USERNAME]") { $JS_WINDOWS_ADMIN_USERNAME = $promptOutput }

# set the env variable
azd env set JS_WINDOWS_ADMIN_USERNAME -- $JS_WINDOWS_ADMIN_USERNAME


########################################################################
# RDP Port
########################################################################
$JS_RDP_PORT = '3389'
If ($env:JS_RDP_PORT) {
    $JS_RDP_PORT = $env:JS_RDP_PORT
}
if ($promptOutput = Read-Host "Enter the RDP Port for remote desktop connection [$JS_RDP_PORT]") { $JS_RDP_PORT = $promptOutput }

# set the env variable
azd env set JS_RDP_PORT $JS_RDP_PORT


########################################################################
# GitHub User
########################################################################
$JS_GITHUB_USER = $env:JS_GITHUB_USER

$defaultGhUser = ""
If ($JS_GITHUB_USER) { $defaultGhUser = " [$JS_GITHUB_USER]"}

if ($promptOutput = Read-Host "Enter your GitHub user name$defaultGhUser") { $JS_GITHUB_USER = $promptOutput }

# set the env variable
azd env set JS_GITHUB_USER -- $JS_GITHUB_USER


########################################################################
# GitHub Personal Access Token
########################################################################
$JS_GITHUB_PAT = $env:JS_GITHUB_PAT

$defaultPAT = ""
If ($JS_GITHUB_PAT) { $defaultPAT = " [$JS_GITHUB_PAT]"}

if ($promptOutput = Read-Host "Enter your GitHub Personal Access Token (PAT)$defaultPAT") { $JS_GITHUB_PAT = $promptOutput }

# set the env variable
azd env set JS_GITHUB_PAT -- $JS_GITHUB_PAT


########################################################################
# Create SSH RSA Public Key
########################################################################
Write-Host "Creating SSH RSA Public Key..."
$file = "js_rsa"
remove-item $file, "$file.pub" -Force -ea 0 

# Generate the SSH key pair
ssh-keygen -q -t rsa -b 4096 -f $file -N '""' 

# Get the public key
$JS_SSH_RSA_PUBLIC_KEY = get-content "$file.pub"

# Escape the backslashes 
$JS_SSH_RSA_PUBLIC_KEY = $JS_SSH_RSA_PUBLIC_KEY.Replace("\", "\\")

# set the env variable
azd env set JS_SSH_RSA_PUBLIC_KEY -- $JS_SSH_RSA_PUBLIC_KEY


########################################################################
# Create Azure Service Principal
########################################################################
Write-Host "Creating Azure Service Principal..."

$user = $context.Account.Id.split("@")[0]
$uniqueSpnName = "$user-jumpstart-spn-$(Get-Random -Minimum 1000 -Maximum 9999)"
try {
    $spn = New-AzADServicePrincipal -DisplayName $uniqueSpnName -Role "Owner" -Scope "/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)" -ErrorAction Stop
}
catch {
    If ($error[0].ToString() -match "Forbidden"){
        Throw "You do not have permission to create a service principal. Please contact your Azure subscription administrator to grant you the Owner role on the subscription."
    }
    elseif ($error[0].ToString() -match "credentials") {
        Throw "Please run Connect-AzAccount to sign and run 'azd up' again."
    }
    else {
        Throw "An error occurred creating the service principal. Please try again."
    }
} 

$SPN_CLIENT_ID = $spn.AppId
$SPN_CLIENT_SECRET = $spn.PasswordCredentials.SecretText
$SPN_TENANT_ID = (Get-AzContext).Tenant.Id

# Set environment variables
azd env set SPN_CLIENT_ID -- $SPN_CLIENT_ID
azd env set SPN_CLIENT_SECRET -- $SPN_CLIENT_SECRET
azd env set SPN_TENANT_ID -- $SPN_TENANT_ID
