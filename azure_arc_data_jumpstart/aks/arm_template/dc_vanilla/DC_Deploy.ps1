Start-Transcript -Path C:\tmp\dc_deploy.log

# Deploying Azure Arc Data Controller
start Powershell {kubectl get pods -n $env:ARC_DC_NAME -w}
azdata arc dc create -p azure-arc-aks-private-preview --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect
azdata login -n $env:ARC_DC_NAME

Stop-Transcript

Stop-Process -Name kubectl -Force
Stop-Process -name powershell -Force
