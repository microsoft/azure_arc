$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Set groupObjectID to the object ID of the Microsoft Entra ID group that will be granted access to the AKS workload cluster.
#$groupObjectID="aaaaaaa-bbbb-cccc-db62-fffssfff" # Uncomment this line and change the value to your Microsoft Entra ID group id

# Set paths
$Env:LocalBoxDir = "C:\LocalBox"

# Import Configuration Module
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile
Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\Configure-AKSWorkloadCluster.log"

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($LocalBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Generate credential objects
Write-Host 'Creating credentials and connecting to Azure'
$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$location = $env:azureLocation
$lnetName = "localbox-aks-lnet-vlan110"
$customLocName = $LocalBoxConfig.rbCustomLocationName
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"
Invoke-Command -VMName "$($LocalBoxConfig.NodeHostConfig[0].Hostname)" -Credential $domainCred -ArgumentList $LocalBoxConfig -ScriptBlock {
    $LocalBoxConfig = $args[0]
    az login --service-principal --username $using:spnClientID --password=$using:spnSecret --tenant $using:spnTenantId
    az config set extension.use_dynamic_install=yes_without_prompt | Out-Null
    az extension add --name customlocation
    az extension add --name stack-hci-vm
    $customLocationID=(az customlocation show --resource-group $using:rg --name $using:customLocName --query id -o tsv)
    $switchName='"ConvergedSwitch(hci)"'

    $addressPrefixes = $LocalBoxConfig.AKSIPPrefix
    $gateway = $LocalBoxConfig.AKSGWIP
    $dnsServers = $LocalBoxConfig.AKSDNSIP
    $vlanid = $LocalBoxConfig.AKSVLAN

    az stack-hci-vm network lnet create --subscription $using:subId --resource-group $using:rg --custom-location $customLocationID --location $using:location --name $using:lnetName --vm-switch-name $switchName --ip-allocation-method "static" --ip-pool-start $LocalBoxConfig.AKSNodeStartIP --ip-pool-end $LocalBoxConfig.AKSNodeEndIP --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid
}
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"

az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
az extension add --name customlocation
az extension add -n aksarc --upgrade
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name $LocalBoxConfig.rbCustomLocationName --query id -o tsv)
$lnetId="/subscriptions/$subId/resourceGroups/$env:resourceGroup/providers/Microsoft.AzureStackHCI/logicalnetworks/$lnetName"
az aksarc create -n $LocalBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --custom-location $customlocationID --vnet-ids $lnetId --aad-admin-group-object-ids $groupObjectID --generate-ssh-keys --control-plane-ip $LocalBoxConfig.AKSControlPlaneIP

Stop-Transcript
