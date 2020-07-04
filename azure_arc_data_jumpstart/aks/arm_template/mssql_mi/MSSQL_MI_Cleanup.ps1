Start-Transcript -Path C:\tmp\mssql_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources (MSSQL incl.)
start Powershell {kubectl get pods -n $env:ARC_DC_NAME -w}
kubectl delete ns $env:ARC_DC_NAME
kubectl delete crd databases.mssqlcontroller.k8s.io
kubectl delete crd registrations.tina-instances.com
kubectl delete clusterrolebinding arcdatactrl:crb-mssql-metricsdc-reader
kubectl delete clusterrolebinding crb-arcdatactrl-controller
kubectl delete clusterrolebinding operator-rolebinding
kubectl delete clusterrole arcdatactrl:cr-mssql-metricsdc-reader

# Restoring State
Copy-Item -Path "C:\tmp\settings_backup.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\hosts_backup" -Destination "C:\Windows\System32\drivers\etc\hosts" -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\settings_template_backup.json" -Destination "C:\tmp\settings_template.json" -Recurse -Force -ErrorAction Continue

Remove-Item "C:\tmp\settings_backup.json" -Force
Remove-Item "C:\tmp\hosts_backup" -Force
Remove-Item "C:\tmp\settings_template_backup.json" -Force

Stop-Transcript

Stop-Process -Name kubectl -Force
Stop-Process -Name powershell -Force
