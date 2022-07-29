Write-Output "Full profile script"

Write-Output "Fetching Workbook Template Artifact for Full"
Get-File-Renaming ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookFull.json") $Env:ArcBoxDir\mgmtMonitorWorkbook.json

Write-Output "Fetching Artifacts for Full Flavor"
Get-File-Renaming ("https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable") $Env:ArcBoxDir\azuredatastudio.zip
Get-File-Renaming ("https://aka.ms/azdata-msi") $Env:ArcBoxDir\AZDataCLI.msi
Get-File ($templateBaseUrl + "artifacts")  @("settingsTemplate.json", "DataServicesLogonScript.ps1", "DeployPostgreSQL.ps1", "DeploySQLMI.ps1", "dataController.json", "dataController.parameters.json", "postgreSQL.json", "postgreSQL.parameters.json", "sqlmi.json", "sqlmi.parameters.json", "SQLMIEndpoints.ps1") $Env:ArcBoxDir
Get-File-Renaming ("https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip") $Env:ArcBoxDir\SqlQueryStress.zip

Write-Output "Installing Azure Data Studio"
Expand-Archive $Env:ArcBoxDir\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
Start-Process msiexec.exe -Wait -ArgumentList "/I $Env:ArcBoxDir\AZDataCLI.msi /quiet"

Write-Output "Creating scheduled task for DataServicesLogonScript.ps1"
Add-Logon-Script $adminUsername "DataServicesLogonScript" ("$Env:ArcBoxDir\DataServicesLogonScript.ps1")

. $Env:ArcBoxDir\ArcboxProfileFullItPro-v1.ps1