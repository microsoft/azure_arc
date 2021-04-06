Start-Transcript -Path C:\tmp\mssql_mi_deploy.log

# Deploying Azure Arc Data Controller
start PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode indirect --path "C:\tmp\custom"

# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME
azdata arc sql mi list

# Configuring MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\sql_connectivity.ps1" -WindowStyle Hidden -Wait

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized

Stop-Process -name powershell -Force
