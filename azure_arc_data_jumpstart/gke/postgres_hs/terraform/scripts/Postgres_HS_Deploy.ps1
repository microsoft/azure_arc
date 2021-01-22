Start-Transcript -Path C:\tmp\postgres_hs_deploy.log

# Deploying Azure Arc Data Controller
start PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode direct --path "C:\tmp\custom"

# Deploying Azure Arc PostgreSQL Hyperscale Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc postgres endpoint list --name $env:POSTGRES_NAME

# Creating POSTGRES Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\postgres_connectivity.ps1" -WindowStyle Hidden -Wait

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized

Stop-Process -name powershell -Force
