#####################################################################
# Get Environment Variables and User Inputs
#####################################################################
$AgConfig           = Import-PowerShellDataFile -Path $Env:AgConfigPath
$Env:spnClientID 
$Env:spnClientSecret
$Env:spnTenantId 
# Variable block
let "randomIdentifier=$RANDOM*$RANDOM"
location="East US"
failoverLocation="South Central US"
resourceGroup="msdocs-cosmosdb-rg-$randomIdentifier"
tag="create-sql-cosmosdb"
account="msdocs-account-cosmos-$randomIdentifier" #needs to be lower case
database="msdocs-db-sql-cosmos"
container="container1"
partitionKey="/zipcode"

#####################################################################
# Install Azure CLI 
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/17)" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}
$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")

# Making extension install dynamic
if ($AgConfig.AzCLIExtensions.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing Azure CLI extensions: " ($AgConfig.AzCLIExtensions -join ', ') -ForegroundColor Gray
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    # Installing Azure CLI extensions
    foreach ($extension in $AgConfig.AzCLIExtensions) {
        az extension add --name $extension --system --only-show-errors
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Az CLI configuration complete!" -ForegroundColor Green
Write-Host


#####################################################################
# Setup Azure PowerShell and register providers
#####################################################################

Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell (Step 2/17)" -ForegroundColor DarkGreen
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
$subscriptionId = (Get-AzSubscription).Id

# Install PowerShell modules
if ($AgConfig.PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($AgConfig.PowerShellModules -join ', ') -ForegroundColor Gray
    foreach ($module in $AgConfig.PowerShellModules) {
        Install-Module -Name $module -Force | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}

# Register Azure providers
if ($AgConfig.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($AgConfig.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AgConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host


#####################################################################
# Install AKSEE on Host and Configure Single Cluster with Internal vSwitch
#####################################################################

$url = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStart.ps1"
Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStart.ps1
Unblock-File .\AksEdgeQuickStart.ps1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

.\AksEdgeQuickStart.ps1 -SubscriptionId "<subscription-id>" -TenantId "<tenant-id>" -Location "<location>"

#####################################################################
# Configure Azure Resources
#####################################################################

# Resource Group
az group create --name myResourceGroup --location eastus

# Azure Container Registry
az acr create --resource-group myResourceGroup --name mycontainerregistry --sku Basic

# CosmosDB
az cosmosdb create --name $account --resource-group $resourceGroup --default-consistency-level Eventual --locations regionName="$location" failoverPriority=0 isZoneRedundant=False --locations regionName="$failoverLocation" failoverPriority=1 isZoneRedundant=False
az cosmosdb sql database create --account-name $account --resource-group $resourceGroup --name $database
az cosmosdb sql container create --account-name $account --resource-group $resourceGroup --database-name $database --name $container --partition-key-path $partitionKey --throughput 400 --idx @idxpolicy-$randomIdentifier.json

#####################################################################
# Configure GitHub repository
#####################################################################

# Clone Repo to Users repo
# Build Initial Images
# Configure Workflow for updates

#####################################################################
# Connect Cluster and Host to Arc
#####################################################################


#####################################################################
# Configure GitOps in Cluster
#####################################################################
