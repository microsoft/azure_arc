$ArcBoxDir = 'C:\ArcBox'
$ArcBoxLogsDir = "$ArcBoxDir\Logs"

Start-Transcript -Path $ArcBoxLogsDir\MonitorWorkbookLogonScript.log

# Required for CLI commands
Write-Header 'Az CLI Login'
az login --identity
az account set -s $env:subscriptionId

Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure Monitor Workbook ARM template for $($env:flavor)"

Write-Host "`n"

if ($env:flavor -eq 'ITPro') {

  Deploy-Workbook -MonitoringDir C:\ArcBox -workbookFileName arc-inventory-workbook.json
  Deploy-Workbook -MonitoringDir C:\ArcBox -workbookFileName arc-osperformance-workbook.json


} else {


  Write-Host "`n"

  # Configure mgmtMonitorWorkbook.json template with subscription ID and resource group values

  $monitorWorkbook = "$ArcBoxDir\mgmtMonitorWorkbook.json"
(Get-Content -Path $monitorWorkbook) -replace '<subscriptionId>', $Env:subscriptionId | Set-Content -Path $monitorWorkbook
(Get-Content -Path $monitorWorkbook) -replace '<resourceGroup>', $Env:resourceGroup | Set-Content -Path $monitorWorkbook
(Get-Content -Path $monitorWorkbook) -replace '<workspaceName>', $Env:workspaceName | Set-Content -Path $monitorWorkbook

  # Configure mgmtMonitorWorkbook.parameters.json template with workspace resource id
  $monitorWorkbookParameters = "$ArcBoxDir\mgmtMonitorWorkbook.parameters.json"
  $workspaceResourceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type 'Microsoft.OperationalInsights/workspaces' --query id -o tsv)
(Get-Content -Path $monitorWorkbookParameters) -replace 'workbookResourceId-stage', $workspaceResourceId | Set-Content -Path $monitorWorkbookParameters

  Write-Host 'Deploying Azure Monitor Workbook ARM template.'
  Write-Host "`n"
  az deployment group create --resource-group $Env:resourceGroup --template-file "$ArcBoxDir\mgmtMonitorWorkbook.json" --parameters "$ArcBoxDir\mgmtMonitorWorkbook.parameters.json"
  Write-Host "`n"

}

# Removing the LogonScript Scheduled Task so it won't run on next reboot
if ($null -ne (Get-ScheduledTask -TaskName 'MonitorWorkbookLogonScript' -ErrorAction SilentlyContinue)) {
  Unregister-ScheduledTask -TaskName 'MonitorWorkbookLogonScript' -Confirm:$false
}

Start-Sleep -Seconds 5