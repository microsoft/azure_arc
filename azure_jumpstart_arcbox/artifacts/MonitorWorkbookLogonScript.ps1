Start-Transcript -Path C:\ArcBox\MonitorWorkbookLogonScript.log

# Required for CLI commands
az login --service-principal --username $env:spnClientID --password $env:spnClientSecret --tenant $env:spnTenantId

# Configure mgmtMonitorWorkbook.json template with subscription ID and resource group values
Write-Host "Configuring Azure Monitor Workbook ARM template."
Write-Host "`n"
$monitorWorkbook = "C:\ArcBox\mgmtMonitorWorkbook.json"
(Get-Content -Path $monitorWorkbook) -replace '<subscriptionId>',$env:subscriptionId | Set-Content -Path $monitorWorkbook
(Get-Content -Path $monitorWorkbook) -replace '<resourceGroup>',$env:resourceGroup | Set-Content -Path $monitorWorkbook

# Configure mgmtMonitorWorkbook.parameters.json template with subscription ID and resource group values
$monitorWorkbookParameters = "C:\ArcBox\mgmtMonitorWorkbook.parameters.json"
(Get-Content -Path $monitorWorkbook) -replace 'workbookResourceId-stage',$env:resourceGroup | Set-Content -Path $monitorWorkbook

Write-Host "Deploying Azure Monitor Workbook ARM template."
Write-Host "`n"
az deployment group create --resource-group $env:resourceGroup --template-file "C:\ArcBox\mgmtMonitorWorkbook.json" --parameters "C:\ArcBox\mgmtMonitorWorkbook.parameters.json"
Write-Host "`n"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Confirm:$false
Start-Sleep -Seconds 5