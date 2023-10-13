# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxGitOpsDir = "C:\HCIBox\GitOps"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

# Import Configuration Module
$ConfigurationDataFile = "$Env:HCIBoxDir\HCIBox-Config.psd1"
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Set AD Domain cred
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

$csv_path = "C:\ClusterStorage\S2D_vDISK1"
$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$resource_name = "HCIBox-ResourceBridge"
$custom_location_name = "hcibox-rb-cl"

Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Write-Host "Removing Arc Resource Bridge."
    $WarningPreference = "SilentlyContinue"
    az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId

    az azurestackhci virtualnetwork delete --subscription $using:subId --resource-group $using:rg --name "vlan200" --yes
    az azurestackhci galleryimage delete --subscription $using:subId --resource-group $using:rg --name "ubuntu20"
    az azurestackhci galleryimage delete --subscription $using:subId --resource-group $using:rg --name "win2k22"
    az customlocation delete --resource-group $using:rg --name $using:custom_location_name --yes
    az k8s-extension delete --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name vmss-hci --yes
    az arcappliance delete hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --yes
    Remove-ArcHciConfigFiles
}