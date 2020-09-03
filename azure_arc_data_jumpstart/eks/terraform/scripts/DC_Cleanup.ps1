Start-Transcript -Path C:\tmp\dc_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc delete --name $env:ARC_DC_NAME --namespace $env:ARC_DC_NAME --force
kubectl delete ns $env:ARC_DC_NAME

Stop-Transcript

Stop-Process -Name powershell -Force
