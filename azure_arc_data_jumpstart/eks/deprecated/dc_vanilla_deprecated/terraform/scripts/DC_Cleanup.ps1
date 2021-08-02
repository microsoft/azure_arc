Start-Transcript -Path C:\tmp\dc_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources
start PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc delete --name $env:ARC_DC_NAME --namespace $env:ARC_DC_NAME --force
kubectl delete ns $env:ARC_DC_NAME

az login --service-principal -u $env:SPN_CLIENT_ID -p $env:SPN_CLIENT_SECRET --tenant $env:SPN_TENANT_ID --output none
az resource delete -g $env:ARC_DC_RG -n $env:ARC_DC_NAME --namespace "Microsoft.AzureArcData" --resource-type "dataControllers"

Stop-Transcript

Stop-Process -Name powershell -Force
