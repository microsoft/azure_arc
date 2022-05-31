Start-Transcript -Path C:\Temp\SQLMIEndpointsLog.log

# Creating SQLMI Endpoints file
New-Item -Path "C:\Temp\" -Name "SQLMIEndpoints.txt" -ItemType "file" 
$Endpoints = "C:\Temp\SQLMIEndpoints.txt"

$primarySqlMIInstance = "js-sql-pr"
$secondarySqlMIInstance = "js-sql-dr"

# Retrieving SQL MI connection endpoints for the primary cluster
kubectx primary
Add-Content $Endpoints "Primary SQL Managed Instance external endpoint for the primary cluster:"
$primaryEndpoint = kubectl get sqlmanagedinstances $primarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.primary}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints
Add-Content $Endpoints ""

if ( $env:SQLMIHA -eq $true )
{
    Add-Content $Endpoints "Secondary SQL Managed Instance external endpoint for the primary cluster:"
    $secondaryEndpoint = kubectl get sqlmanagedinstances $primarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.secondary}'
    $secondaryEndpoint = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints
}

# Retrieving SQL MI connection endpoints for the secondary cluster
kubectx secondary
Add-Content $Endpoints "Primary SQL Managed Instance external endpoint for the secondary cluster:"
$primaryEndpoint = kubectl get sqlmanagedinstances $secondarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.primary}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints
Add-Content $Endpoints ""

if ( $env:SQLMIHA -eq $true )
{
    Add-Content $Endpoints "Secondary SQL Managed Instance external endpoint for the secondary cluster:"
    $secondaryEndpoint = kubectl get sqlmanagedinstances $secondarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.secondary}'
    $secondaryEndpoint = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints
}

# Retrieving SQL MI connection username and password
Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance username:"
$env:AZDATA_USERNAME | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance password:"
$env:AZDATA_PASSWORD | Add-Content $Endpoints

Write-Host "`n"
Write-Host "Creating SQLMI Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\SQLMI Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()