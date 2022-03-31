# Creating Log File
Start-Transcript -Path C:\tmp\ArcInstallScript.log

# Azure Login 

az login --service-principal -u $Env:appId -p $Env:password --tenant $Env:tenantId
az account set -s $Env:SubscriptionId

#Configure hosts file for Private link endpoints resolution

$file = "C:\Windows\System32\drivers\etc\hosts"

$gisfqdn = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query '[0].privateDnsZoneConfigs[0].recordSets[0].fqdn' -o json).replace('.privatelink','').replace("`"","")
$gisIP = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[0].recordSets[0].ipAddresses[0] -o json).replace("`"","")
$hisfqdn = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[0].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$hisIP = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[0].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$agentfqdn = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[1].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$agentIp = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[1].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$gasfqdn = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[1].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$gasIp = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[1].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$dpfqdn = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[2].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$dpIp = (az network private-endpoint dns-zone-group list --endpoint-name $Env:PEname --resource-group $Env:resourceGroup -o json --query [0].privateDnsZoneConfigs[2].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
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
--resource-group $Env:resourceGroup `
--tenant-id $Env:tenantId `
--location $Env:Location `
--subscription-id $Env:SubscriptionId `
--cloud "AzureCloud" `
--private-link-scope $Env:PLscope `
--service-principal-id $Env:appId `
--service-principal-secret $Env:password `
--correlation-id "e5089a61-0238-48fd-91ef-f67846168001" `
--tags "Project=jumpstart_azure_arc_servers" 

# Remove schedule task
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
Stop-Process -Name powershell -Force