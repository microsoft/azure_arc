Write-Output "ITPro profile script"

Write-Output "Fetching Workbook Template Artifact for ITPro"
Get-File-Renaming ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookITPro.json") $Env:ArcBoxDir\mgmtMonitorWorkbook.json

. $Env:ArcBoxDir\ArcboxProfileFullItPro-v1.ps1