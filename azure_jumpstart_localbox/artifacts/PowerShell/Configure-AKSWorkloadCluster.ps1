#requires -Version 7.0

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

az login --identity
az config set extension.use_dynamic_install=yes_without_prompt | Out-Null
az extension add --name customlocation
az extension add --name stack-hci-vm
az extension add --name aksarc

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$tenantId = $env:tenantId
$location = $env:azureLocation
$lnetName = "localbox-aks-lnet-vlan110"
$customLocName = $LocalBoxConfig.rbCustomLocationName
$customLocationID = (az customlocation show --resource-group $rg --name $customLocName --query id -o tsv)
$switchName = '"ConvergedSwitch(compute_management)"'
$addressPrefixes = $LocalBoxConfig.AKSIPPrefix
$gateway = $LocalBoxConfig.AKSGWIP
$dnsServers = $LocalBoxConfig.AKSDNSIP
$vlanid = $LocalBoxConfig.AKSVLAN

az stack-hci-vm network lnet create --subscription $subId --resource-group $rg --custom-location $customLocationID --location $location --name $lnetName --vm-switch-name $switchName --ip-allocation-method "static" --ip-pool-start $LocalBoxConfig.AKSNodeStartIP --ip-pool-end $LocalBoxConfig.AKSNodeEndIP --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --vlan $vlanid

$lnetId = "/subscriptions/$subId/resourceGroups/$env:resourceGroup/providers/Microsoft.AzureStackHCI/logicalnetworks/$lnetName"
az aksarc create -n $LocalBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --location $location --custom-location $customlocationID --vnet-ids $lnetId --aad-admin-group-object-ids $groupObjectID --generate-ssh-keys --control-plane-ip $LocalBoxConfig.AKSControlPlaneIP

Stop-Transcript