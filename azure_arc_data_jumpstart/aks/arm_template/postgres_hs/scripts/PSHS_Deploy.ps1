Start-Transcript -Path C:\tmp\mssql_deploy.log

# Deploying Azure Arc Data Controller
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create -p azure-arc-aks-private-preview --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect

# Deploying Azure Arc PostgreSQL Hyperscale Instance
azdata login -n $env:ARC_DC_NAME
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:PSHS_NAMESPACE; sleep 5; clear }}
azdata postgres server create --name $env:PSHS_NAME --namespace $env:PSHS_NAMESPACE --password $env:AZDATA_PASSWORD -w $env:PSHS_WORKER_NODE_COUNT --dataSizeMb $env:PSHS_DATASIZE --serviceType $env:PSHS_SERVICE_TYPE
azdata postgres server list -ns $env:PSHS_NAMESPACE

# Cleaning MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\pshs_connectivity.ps1" -WindowStyle Hidden -Wait

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Maximized
Stop-Process -name powershell -Force
