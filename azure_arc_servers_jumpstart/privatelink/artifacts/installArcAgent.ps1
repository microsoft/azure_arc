param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$subscriptionId,
    [string]$Location,
    [string]$PEname 

)
[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('Location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('PEname', $PEname,[System.EnvironmentVariableTarget]::Machine)


$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log


#Configure hosts file for PL 
$file = "C:\Windows\System32\drivers\etc\hosts"
$gisfqdn=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[0].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$gisIP= (az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[0].recordSets[0].ipAddresses[0] -o json).replace("`"","")
$hisfqdn=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[0].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$hisIP=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[0].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$agentfqdn=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[1].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$agentIp=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[1].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$gasfqdn=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[1].recordSets[1].fqdn -o json).replace('.privatelink','').replace("`"","")
$gasIp=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[1].recordSets[1].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
$dpfqdn=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[2].recordSets[0].fqdn -o json).replace('.privatelink','').replace("`"","")
$dpIp=(az network private-endpoint dns-zone-group list --endpoint-name $PEname --resource-group $resourceGroup --query [0].privateDnsZoneConfigs[2].recordSets[0].ipAddresses[0] -o json).replace('.privatelink','').replace("`"","")
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
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
--service-principal-id $env:appId `
--service-principal-secret $env:password `
--location $env:Location `
--tenant-id $env:tenantId `
--subscription-id $env:SubscriptionId `
--resource-group $env:resourceGroup `
--cloud "AzureCloud" `
--private-link-scope $env:PLscope `
--tags "Project=jumpstart_azure_arc_servers" `
--correlation-id "86501baa-0b82-478c-b3cf-620533617001"

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "${adminUsername}" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask