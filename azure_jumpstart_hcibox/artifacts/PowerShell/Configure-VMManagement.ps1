$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-VMManagement.log"

#$csv_path = $HCIBoxConfig.ClusterSharedVolumePath

# Generate credential objects
$user = "$($HCIBoxConfig.SDNDomainFQDN)\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

# Install AZ Resource Bridge and prerequisites
Write-Host "Now Preparing to configure guest VM management"

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = "eastus"
$customLocName = $HCIBoxConfig.rbCustomLocationName

# Copy gallery VHDs to hosts
# Invoke-Command -VMName $HCIBoxConfig.NodeHostConfig[0].Hostname -Credential $adcred -ScriptBlock {
#     New-Item -Name "VHD" -Path $using:csv_path -ItemType Directory -Force
#     Move-Item -Path "C:\VHD\GUI.vhdx" -Destination "$using:csv_path\VHD\GUI.vhdx" -Force
#     Move-Item -Path "C:\VHD\Ubuntu.vhdx" -Destination "$using:csv_path\VHD\Ubuntu.vhdx" -Force
# }

# Create VM images
az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name $customLocName --query id -o tsv)
az stack-hci-vm image create --subscription $env:subscriptionId --resource-group $env:resourceGroup --custom-location $customLocationID --location $location --name "WinServer2022" --os-type "windows" --offer "windowsserver" --publisher "microsoftwindowsserver" --sku "2022-datacenter-azure-edition" --version "20348.2227.240104" # --storage-path-id $storagepathid

# Create logical networks
$switchName='"ConvergedSwitch(hci)"'
$lnetName = "hcibox-vm-lnet-static"
$addressPrefixes = $HCIBoxConfig.vmIpPrefix
$gateway = $HCIBoxConfig.vmGateway
$dnsServers = $HCIBoxConfig.vmDNS
$vlanid = $HCIBoxConfig.vmVLAN


az stack-hci-vm network lnet create --subscription $env:subscriptionId --resource-group $env:resourceGroup --custom-location $customLocationID --location $location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "Static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers -vlanid $vlanid