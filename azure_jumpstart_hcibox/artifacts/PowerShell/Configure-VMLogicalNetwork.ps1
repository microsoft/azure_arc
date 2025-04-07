$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:LocalBoxDir = "C:\LocalBox"

# Import Configuration Module
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile
Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\Configure-VMLogicalNetwork.log"

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($LocalBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = $env:azureLocation
$customLocName = $LocalBoxConfig.rbCustomLocationName

# Create logical networks
Invoke-Command -VMName "$($LocalBoxConfig.NodeHostConfig[0].Hostname)" -Credential $domainCred -ArgumentList $LocalBoxConfig -ScriptBlock {
    $LocalBoxConfig = $args[0]
    az login --service-principal --username $using:spnClientID --password=$using:spnSecret --tenant $using:spnTenantId
    az config set extension.use_dynamic_install=yes_without_prompt
    $customLocationID=(az customlocation show --resource-group $using:rg --name $using:customLocName --query id -o tsv)

    $switchName='"ConvergedSwitch(hci)"'
    $lnetName = "localbox-vm-lnet-vlan200"
    $addressPrefixes = $LocalBoxConfig.vmIpPrefix
    $gateway = $LocalBoxConfig.vmGateway
    $dnsServers = $LocalBoxConfig.vmDNS
    $vlanid = $LocalBoxConfig.vmVLAN

    az stack-hci-vm network lnet create --subscription $using:subId --resource-group $using:rg --custom-location $customLocationID --location $using:location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid
}