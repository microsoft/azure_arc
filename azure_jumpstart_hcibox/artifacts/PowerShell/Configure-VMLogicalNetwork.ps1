$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-VMLogicalNetwork.log"

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = "eastus"
$customLocName = $HCIBoxConfig.rbCustomLocationName

# Create logical networks
Invoke-Command -ComputerName "$($HCIBoxConfig.NodeHostConfig[0].Hostname).$($HCIBoxConfig.SDNDomainFQDN)" -Credential $domainCred -Authentication CredSSP -ArgumentList $HCIBoxConfig -ScriptBlock {
    $HCIBoxConfig = $args[0]
    az login --service-principal --username $using:spnClientID --password=$using:spnSecret --tenant $using:spnTenantId
    az config set extension.use_dynamic_install=yes_without_prompt
    $customLocationID=(az customlocation show --resource-group $using:rg --name $using:customLocName --query id -o tsv)

    $switchName='"ConvergedSwitch(hci)"'
    $lnetName = "hcibox-vm-lnet-vlan200"
    $addressPrefixes = $HCIBoxConfig.vmIpPrefix
    $gateway = $HCIBoxConfig.vmGateway
    $dnsServers = $HCIBoxConfig.vmDNS
    $vlanid = $HCIBoxConfig.vmVLAN

    az stack-hci-vm network lnet create --subscription $using:subId --resource-group $using:rg --custom-location $customLocationID --location $using:location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid
}