$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set groupObjectID to the object ID of the Microsoft Entra ID group that will be granted access to the AKS workload cluster. 
#$groupObjectID="aaaaaaa-bbbb-cccc-db62-fffssfff" # Uncomment this line and change the value to your Microsoft Entra ID group id 

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-AKSWorkloadCluster.log"

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Generate credential objects
Write-Host 'Creating credentials and connecting to Azure'
$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = "eastus"
$lnetName = "hcibox-aks-lnet-vlan110"
$customLocName = $HCIBoxConfig.rbCustomLocationName
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"
Invoke-Command -ComputerName "$($HCIBoxConfig.NodeHostConfig[0].Hostname).$($HCIBoxConfig.SDNDomainFQDN)" -Credential $domainCred -Authentication CredSSP -ArgumentList $HCIBoxConfig -ScriptBlock {
    $HCIBoxConfig = $args[0]
    az login --service-principal --username $using:spnClientID --password=$using:spnSecret --tenant $using:spnTenantId
    az config set extension.use_dynamic_install=yes_without_prompt | Out-Null
    az extension add --name customlocation
    az extension add --name stack-hci-vm
    $customLocationID=(az customlocation show --resource-group $using:rg --name $using:customLocName --query id -o tsv)
    $switchName='"ConvergedSwitch(hci)"'
    
    $addressPrefixes = $HCIBoxConfig.AKSIPPrefix
    $gateway = $HCIBoxConfig.AKSGWIP
    $dnsServers = $HCIBoxConfig.AKSDNSIP
    $vlanid = $HCIBoxConfig.AKSVLAN

    az stack-hci-vm network lnet create --subscription $using:subId --resource-group $using:rg --custom-location $customLocationID --location $using:location --name $using:lnetName --vm-switch-name $switchName --ip-allocation-method "static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid
}
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"

az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
az extension add --name customlocation
az extension add -n aksarc --upgrade
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name $HCIBoxConfig.rbCustomLocationName --query id -o tsv)
$lnetId="/subscriptions/$subId/resourceGroups/$env:resourceGroup/providers/Microsoft.AzureStackHCI/logicalnetworks/$lnetName"
az aksarc create -n $HCIBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --custom-location $customlocationID --vnet-ids $lnetId --aad-admin-group-object-ids $groupObjectID --generate-ssh-keys --control-plane-ip $HCIBoxConfig.AKSControlPlaneIP az aksarc create -n $HCIBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --custom-location $customlocationID --vnet-ids $lnetId --aad-admin-group-object-ids $groupObjectID --generate-ssh-keys --control-plane-ip $HCIBoxConfig.AKSControlPlaneIP

Stop-Transcript
