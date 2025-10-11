#requires -Version 7.0

$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:LocalBoxDir = "C:\LocalBox"

# Import Configuration Module
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile
Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\Configure-VMLogicalNetwork.log"

az login --identity
az config set extension.use_dynamic_install=yes_without_prompt | Out-Null
az extension add --name customlocation
az extension add --name stack-hci-vm

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$location = $env:azureLocation
$switchName = '"ConvergedSwitch(compute_management)"'
$lnetName = "localbox-vm-lnet-vlan200"
$addressPrefixes = $LocalBoxConfig.vmIpPrefix
$gateway = $LocalBoxConfig.vmGateway
$dnsServers = $LocalBoxConfig.vmDNS
$vlanid = $LocalBoxConfig.vmVLAN
$customLocName = $LocalBoxConfig.rbCustomLocationName
$customLocationID = (az customlocation show --resource-group $rg --name $customLocName --query id -o tsv)

az stack-hci-vm network lnet create --subscription $subId --resource-group $rg --custom-location $customLocationID --location $location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid

Stop-Transcript