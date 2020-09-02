Start-Transcript -Path C:\tmp\postgres_deploy.log

# Deploying Azure Arc Data Controller
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --profile-name azure-arc-aks-premium-storage --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect
Start-Sleep -s 30

# Deploying Azure Arc PostgreSQL Hyperscale Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc postgres server endpoint list --name $env:POSTGRES_NAME

# Creating POSTGRES Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\postgres_connectivity.ps1" -WindowStyle Hidden -Wait

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Maximized
Stop-Process -name powershell -Force
