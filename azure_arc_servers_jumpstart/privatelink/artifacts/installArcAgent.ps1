New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript_Install.log

#Configure hosts file for PL 
$file = "C:\Windows\System32\drivers\etc\hosts"
$command = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup --query)
$gisfqdn=($command [0].privateDnsZoneConfigs[0].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$gisIP= ($command [0].privateDnsZoneConfigs[0].recordSets[0].ipAddresses[0] -o json).replace("`"","")
$hisfqdn=($command [0].privateDnsZoneConfigs[0].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$hisIP=($command [0].privateDnsZoneConfigs[0].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$agentfqdn=($command [0].privateDnsZoneConfigs[1].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$agentIp=($command [0].privateDnsZoneConfigs[1].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$gasfqdn=($command [0].privateDnsZoneConfigs[1].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$gasIp=($command [0].privateDnsZoneConfigs[1].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$dpfqdn=($command [0].privateDnsZoneConfigs[2].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$dpIp=($command [0].privateDnsZoneConfigs[2].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$hostfile = Get-Content $file
$hostfile += "$gisIP $gisfqdn"
$hostfile += "$hisIP $hisfqdn"
$hostfile += "$agentIP $agentfqdn"
$hostfile += "$gasIP $gasfqdn"
$hostfile += "$dpIP $dpfqdn"
Set-Content -Path $file -Value $hostfile -Force


## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254 

## Azure Arc agent Installation

Write-Host "Onboarding to Azure Arc"
# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download


# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# Run connect command
& "$Env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
--service-principal-id $Env:appId `
--service-principal-secret $Env:password `
--location $Env:Location `
--tenant-id $Env:tenantId `
--subscription-id $Env:SubscriptionId `
--resource-group $Env:resourceGroup `
--cloud "AzureCloud" `
--private-link-scope $Env:PLscope `
--tags "Project=jumpstart_azure_arc_servers" `
--correlation-id "86501baa-0b82-478c-b3cf-620533617001"

'@ > C:\tmp\LogonScript_Install.log
