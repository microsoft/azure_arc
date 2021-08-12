# Retrieving SQL MI connection endpoint
New-Item -Path "C:\Temp\" -Name "Endpoints.txt" -ItemType "file" 
$Endpoints = "C:\Temp\Endpoints.txt"
Add-Content $Endpoints "Primary SQL Managed Instance external endpoint:"
$primaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.primaryEndpoint}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) | Add-Content $Endpoints
Add-Content $Endpoints ""

Add-Content $Endpoints "Secondary SQL Managed Instance external endpoint:"
$secondaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.secondaryEndpoint}'
$secondaryEndpoint = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(',')) | Add-Content $Endpoints

# Downloading demo database and restoring onto SQL MI
$podname = "jumpstart-sql" + "-0"
Write-Host "Copying AdventureWorks database to MS SQL... (1/2)"
kubectl cp /Temp/AdventureWorks2019.bak $podname":/var/opt/mssql/data" -c arc-sqlmi -n arc
Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
Invoke-Sqlcmd -ServerInstance $primaryEndpoint -Username $env:AZDATA_USERNAME -Password $env:AZDATA_PASSWORD -InputFile C:\Temp\RestoreDB.sql

Write-Host "Creating Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Arc Data Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()