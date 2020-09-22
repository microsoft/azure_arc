Start-Transcript -Path C:\tmp\mssql_deploy.log

# Deploying Azure Arc Data Controller
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --profile-name azure-arc-aks-premium-storage --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect

# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc sql mi list

# Cleaning MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\sql_connectivity.ps1" -WindowStyle Hidden -Wait

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Maximized

Stop-Process -name powershell -Force
