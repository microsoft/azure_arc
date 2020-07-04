Start-Transcript -Path C:\tmp\mssql_deploy.log

# Deploying Azure Arc Data Controller
start Powershell {kubectl get pods -n $env:ARC_DC_NAME -w}
azdata arc dc create -c azure-arc-aks-private-preview --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect

# Deploying Azure Arc SQL Managed Instance
azdata login -n $env:ARC_DC_NAME
azdata sql instance create -n $env:MSSQL_MI_NAME -c $env:MSSQL_MI_vCores -s $env:ARC_DC_SUBSCRIPTION -r $env:resourceGroup
azdata sql instance list

# Retreving SQL Managed Instance IP
azdata sql instance list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(',')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline

# Retreving SQL Managed Instance FQDN
azdata sql instance list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.IndexOf(' ')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
Add-Content -Path "C:\tmp\merge.txt" -Value ("   ",$s.Substring(0, $s.LastIndexOf(','))) -Encoding ascii -NoNewline

# Adding SQL Instance FQDN & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\tmp\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii

# Retreving SQL Managed Instance FQDN & Port
azdata sql instance list | Tee-Object "C:\tmp\sql_instance_settings.txt"
$lines = Get-Content "C:\tmp\sql_instance_settings.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_settings.txt"
$lines = Get-Content "C:\tmp\sql_instance_settings.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_settings.txt"
$s = Get-Content "C:\tmp\sql_instance_settings.txt"
$s.Substring(0, $s.IndexOf(' ')) | Out-File "C:\tmp\sql_instance_settings.txt"

# Creating Azure Data Studio settings for SQL Managed Instance connection
Copy-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Destination "C:\tmp\settings_backup.json" -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\tmp\settings_template_backup.json" -Recurse -Force -ErrorAction Continue

$s = Get-Content "C:\tmp\sql_instance_settings.txt"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'arc_sql_mi',$s | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'sa_password',$env:MSSQL_SA_PASSWORD | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\tmp\settings_template.json"
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue

# Downloading demo database
$podname = "$env:MSSQL_MI_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
kubectl exec $podname -n $env:ARC_DC_NAME -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $env:MSSQL_SA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

# Cleaning garbage
Remove-Item "C:\tmp\sql_instance_settings.txt" -Force
Remove-Item "C:\tmp\sql_instance_list.txt" -Force
Remove-Item "C:\tmp\merge.txt" -Force

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Maximized

Stop-Transcript

Stop-Process -Name kubectl -Force
Stop-Process -Name powershell -Force
