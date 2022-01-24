$ArcBoxDir = "C:\ArcBox"
$ArcBoxLogsDir = "$ArcBoxDir\Logs"

Start-Transcript -Path $ArcBoxLogsDir\MonitorWorkbookLogonScript.log

# Required for CLI commands
az login --service-principal --username $env:spnClientID --password $env:spnClientSecret --tenant $env:spnTenantId

# Configure mgmtMonitorWorkbook.json template with subscription ID and resource group values
Write-Host "Configuring Azure Monitor Workbook ARM template."
Write-Host "`n"
$monitorWorkbook = "$ArcBoxDir\mgmtMonitorWorkbook.json"
(Get-Content -Path $monitorWorkbook) -replace '<subscriptionId>',$env:subscriptionId | Set-Content -Path $monitorWorkbook
(Get-Content -Path $monitorWorkbook) -replace '<resourceGroup>',$env:resourceGroup | Set-Content -Path $monitorWorkbook
(Get-Content -Path $monitorWorkbook) -replace '<workspaceName>',$env:workspaceName | Set-Content -Path $monitorWorkbook

# Configure mgmtMonitorWorkbook.parameters.json template with workspace resource id
$monitorWorkbookParameters = "$ArcBoxDir\mgmtMonitorWorkbook.parameters.json"
$workspaceResourceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query id -o tsv)
(Get-Content -Path $monitorWorkbookParameters) -replace 'workbookResourceId-stage',$workspaceResourceId | Set-Content -Path $monitorWorkbookParameters

Write-Host "Deploying Azure Monitor Workbook ARM template."
Write-Host "`n"
az deployment group create --resource-group $env:resourceGroup --template-file "$ArcBoxDir\mgmtMonitorWorkbook.json" --parameters "$ArcBoxDir\mgmtMonitorWorkbook.parameters.json"
Write-Host "`n"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Confirm:$false
Start-Sleep -Seconds 5