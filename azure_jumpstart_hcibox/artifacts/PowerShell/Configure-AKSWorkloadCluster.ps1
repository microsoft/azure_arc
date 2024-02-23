$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set aadgroupID to the object ID of the Microsoft Entra group that will be granted access to the AKS workload cluster.
#$aadgroupID="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-AKSWorkloadCluster.log"

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Generate credential objects
Write-Host 'Creating credentials and connecting to Azure'
$clientId = $env:spnClientId
$tenantId = $env:spnTenantId
$subId = $env:subscriptionId
$clustervnetname = "aksvnet1"
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Invoke-Command -ComputerName "$($HCIBoxConfig.NodeHostConfig[0].Hostname).$($HCIBoxConfig.SDNDomainFQDN)" -Authentication CredSSP -ArgumentList $HCIBoxConfig, $azureAppCred, $tenantId, $subId, $clustervnetname -Credential $domainCred -ScriptBlock {
    $HCIBoxConfig = $args[0]
    $azureAppCred = $args[1]
    $tenantId = $args[2]
    $subId = $args[3]
    $clustervnetname = $args[4]
    Connect-AzAccount -ServicePrincipal -Subscription $subId -Tenant $tenantId -Credential $azureAppCred
    New-ArcHciVirtualNetwork -name $clustervnetname -vswitchname "ConvergedSwitch(hci)" -ipaddressprefix $HCIBoxConfig.AKSIPPrefix -gateway $HCIBoxConfig.AKSGWIP -dnsservers $HCIBoxConfig.AKSDNSIP -vippoolstart $HCIBoxConfig.AKSVIPStartIP -vippoolend $HCIBoxConfig.AKSVIPEndIP -k8snodeippoolstart $HCIBoxConfig.AKSNodeStartIP -k8snodeippoolend $HCIBoxConfig.AKSNodeEndIP -vlanID $HCIBoxConfig.AKSVLAN
}

az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
az extension add --name customlocation
az extension add --name akshybrid
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name $HCIBoxConfig.rbCustomLocationName --query id -o tsv)
az akshybrid vnet create -n $HCIBoxConfig.AKSvnetname -g $env:resourceGroup --custom-location $customlocationID --moc-vnet-name $clustervnetname
$vnetId="/subscriptions/$subId/resourceGroups/$env:resourceGroup/providers/Microsoft.HybridContainerService/virtualNetworks/$($HCIBoxConfig.AKSvnetname)"
az akshybrid create -n $HCIBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --custom-location $customlocationID --vnet-ids $vnetId --aad-admin-group-object-ids $aadgroupID --generate-ssh-keys --load-balancer-count 1
Stop-Transcript