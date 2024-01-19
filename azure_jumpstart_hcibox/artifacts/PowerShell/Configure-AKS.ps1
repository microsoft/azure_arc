$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Configure-AKS.log"

# Generate credential objects
Write-Host 'Creating credentials and connecting to Azure'
$clientId = $env:spnClientId
$tenantId = $env:spnTenantId
$subId = $env:subscriptionId
$clustervnetname = "aksvnet1"
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Invoke-Command -ComputerName $HCIBoxConfig.NodeHostConfig[0].HostName -ArgumentList $HCIBoxConfig, $azureAppCred, $tenantId, $subId, $clustervnetname -Credential $domainCred -ScriptBlock {
    $HCIBoxConfig = $args[0]
    $azureAppCred = $args[1]
    $tenantId = $args[2]
    $subId = $args[3]
    $clustervnetname = $args[4]
    Connect-AzAccount -ServicePrincipal -Subscription $subId -Tenant $tenantId -Credential $azureAppCred
    New-ArcHciVirtualNetwork -name $clustervnetname -vswitchname "ConvergedSwitch(hci)" -ipaddressprefix "192.168.30.0/24" -gateway $HCIBoxConfig.SDNLABRoute -dnsservers $HCIBoxConfig.SDNLABDNS -vippoolstart "192.168.30.100" -vippoolend "192.168.30.200" -k8snodeippoolstart "192.168.30.201" -k8snodeippoolend "192.168.30.249" -vlanID $vlanid
}

az login --service-principal --username $env:spnClientID --password=$env:spnClientSecret --tenant $env:spnTenantId
$customLocationID=(az customlocation show --resource-group $env:resourceGroup --name "Jumpstart" --query id -o tsv)
az akshybrid vnet create -n $HCIBoxConfig.AKSvnetname -g $env:resourceGroup --custom-location $customlocationID --moc-vnet-name $clustervnetname
$vnetId=az hybridaks vnet show --name $HCIBoxConfig.AKSvnetname -g $env:resourceGroup --query id -o tsv
$aadgroupID="97d70ef2-db1e-413c-84f5-3159fbf34693"
az akshybrid create -n $HCIBoxConfig.AKSworkloadClusterName -g $env:resourceGroup --custom-location $customlocationID --vnet-ids $vnetId --aad-admin-group-object-ids $aadgroupID --generate-ssh-keys --load-balancer-count 1
Stop-Transcript