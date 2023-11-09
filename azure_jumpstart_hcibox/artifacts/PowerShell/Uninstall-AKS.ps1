$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Uninstall-AKS.log"

# Generate credential objects
$user = "$($HCIBoxConfig.SDNDomainFQDN)\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred

# Uninstall AksHci - only need to perform the following on one of the nodes
$clusterName = $env:AKSClusterName
Write-Host "Removing AKS-HCI workload cluster"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Disable-AksHciArcConnection -name $using:clusterName
    Remove-AksHciCluster -name $using:clusterName -Confirm:$false
}

Write-Host "Uninstalling AKS-HCI management plane"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Uninstall-AksHci -Confirm:$false
}
# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', 'false',[System.EnvironmentVariableTarget]::Machine)

Stop-Transcript