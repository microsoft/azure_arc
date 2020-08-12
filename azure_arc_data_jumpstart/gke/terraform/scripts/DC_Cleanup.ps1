Start-Transcript -Path C:\tmp\dc_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
kubectl delete ns $env:ARC_DC_NAME
kubectl delete crd databases.mssqlcontroller.k8s.io
kubectl delete crd registrations.tina-instances.com
kubectl delete clusterrolebinding arcdatactrl:crb-mssql-metricsdc-reader
kubectl delete clusterrolebinding crb-arcdatactrl-controller
kubectl delete clusterrolebinding operator-rolebinding
kubectl delete clusterrole arcdatactrl:cr-mssql-metricsdc-reader

Stop-Transcript

Stop-Process -Name powershell -Force
