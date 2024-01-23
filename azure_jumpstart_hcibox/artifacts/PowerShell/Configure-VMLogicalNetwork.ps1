$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-VMManagement.log"

# Install AZ Resource Bridge and prerequisites
Write-Host "Now Preparing to configure guest VM management"

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = "eastus"
$customLocName = $HCIBoxConfig.rbCustomLocationName

# Create logical networks
az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name $customLocName --query id -o tsv)

$switchName='"ConvergedSwitch(hci)"'
$lnetName = "hcibox-vm-lnet-static"
$addressPrefixes = $HCIBoxConfig.vmIpPrefix
$gateway = $HCIBoxConfig.vmGateway
$dnsServers = $HCIBoxConfig.vmDNS
$vlanid = $HCIBoxConfig.vmVLAN

az stack-hci-vm network lnet create --subscription $env:subscriptionId --resource-group $env:resourceGroup --custom-location $customLocationID --location $location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid