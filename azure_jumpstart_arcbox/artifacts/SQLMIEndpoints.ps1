$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

Start-Transcript -Path $Env:ArcBoxLogsDir\SQLMIEndpoints.log

# Creating SQLMI Endpoints file 
New-Item -Path "$Env:ArcBoxDir\" -Name "SQLMIEndpoints.txt" -ItemType "file" 
$Endpoints = "$Env:ArcBoxDir\SQLMIEndpoints.txt"

# Retrieving SQL MI connection endpoints
Add-Content $Endpoints "Primary SQL Managed Instance external endpoint:"
$primaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.endpoints.primary}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints
Add-Content $Endpoints ""

Add-Content $Endpoints "Secondary SQL Managed Instance external endpoint:"
$secondaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.endpoints.secondary}'
$secondaryEndpoint = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(',')) + ",11433" | Add-Content $Endpoints

# Retrieving SQL MI connection username and password
Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance username:"
$Env:AZDATA_USERNAME | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance password:"
$Env:AZDATA_PASSWORD | Add-Content $Endpoints

Write-Host "`n"
Write-Host "Creating SQLMI Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\SQLMI Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()