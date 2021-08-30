Start-Transcript -Path C:\Temp\RestoreDB.log

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
Write-Host "`n"
Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
kubectl exec $podname -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
kubectl exec $podname -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null

Write-Host "`n"
Write-Host "Creating Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Arc Data Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()