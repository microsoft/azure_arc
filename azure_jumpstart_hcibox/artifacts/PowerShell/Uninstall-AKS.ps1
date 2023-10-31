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

Start-Transcript -Path $Env:HCIBoxLogsDir\Uninstall-AKS.log

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\$env:adminUsername"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred

# Uninstall AksHci - only need to perform the following on one of the nodes
$clusterName = $env:AKSClusterName
Write-Header "Removing AKS-HCI workload cluster"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Disable-AksHciArcConnection -name $using:clusterName
    Remove-AksHciCluster -name $using:clusterName -Confirm:$false
}

Write-Header "Uninstalling AKS-HCI management plane"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Uninstall-AksHci -Confirm:$false
}
# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', 'false',[System.EnvironmentVariableTarget]::Machine)

Stop-Transcript