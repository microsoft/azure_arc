$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Uninstall-ArcResourceBridge.log"

# Generate credential objects
$user = "$($HCIBoxConfig.SDNDomainFQDN)\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

$csv_path = $HCIBoxConfig.ClusterSharedVolumePath

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$resource_name = "HCIBox-ResourceBridge"
$custom_location_name = "hcibox-rb-cl"

Invoke-Command -VMName $HCIBoxConfig.NodeHostConfig[0].Hostname -Credential $adcred -ScriptBlock {
    Write-Host "Removing Arc Resource Bridge."
    $WarningPreference = "SilentlyContinue"
    az login --service-principal --username $using:spnClientID --password=$using:spnSecret --tenant $using:spnTenantId

    az azurestackhci virtualnetwork delete --subscription $using:subId --resource-group $using:rg --name "vlan200" --yes
    az azurestackhci galleryimage delete --subscription $using:subId --resource-group $using:rg --name "ubuntu20"
    az azurestackhci galleryimage delete --subscription $using:subId --resource-group $using:rg --name "win2k22"
    az customlocation delete --resource-group $using:rg --name $using:custom_location_name --yes
    az k8s-extension delete --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name vmss-hci --yes
    az arcappliance delete hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --yes
    Remove-ArcHciConfigFiles
}