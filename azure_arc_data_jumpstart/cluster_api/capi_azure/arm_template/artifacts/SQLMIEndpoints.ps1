Start-Transcript -Path C:\Temp\SQLMIEndpoints.log

# Creating SQLMI Endpoints file 
New-Item -Path "C:\Temp\" -Name "SQLMIEndpoints.txt" -ItemType "file" 
$Endpoints = "C:\Temp\SQLMIEndpoints.txt"

# Retrieving SQL MI connection endpoints
Add-Content $Endpoints "Primary SQL Managed Instance external endpoint:"
$primaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.primaryEndpoint}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) | Add-Content $Endpoints
Add-Content $Endpoints ""

if ( $env:SQLMIHA -eq $true )
{
    Add-Content $Endpoints "Secondary SQL Managed Instance external endpoint:"
    $secondaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.secondaryEndpoint}'
    $secondaryEndpoint = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(',')) | Add-Content $Endpoints
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