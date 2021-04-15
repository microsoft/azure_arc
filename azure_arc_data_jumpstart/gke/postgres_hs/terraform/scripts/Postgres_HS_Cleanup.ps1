Start-Transcript -Path C:\tmp\postgres_hs_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources (PostgreSQL incl.)
Start-Process PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; Start-Sleep 5; Clear-Host }}
azdata arc postgres server delete --name $env:POSTGRES_NAME --yes
azdata arc dc delete --name $env:ARC_DC_NAME --namespace $env:ARC_DC_NAME --yes

# az login --service-principal -u $env:SPN_CLIENT_ID -p $env:SPN_CLIENT_SECRET --tenant $env:SPN_TENANT_ID --output none  // Will be uncomment upon "Directly Connected" functionality restore 
# az resource delete -g $env:ARC_DC_RG -n $env:ARC_DC_NAME --namespace "Microsoft.AzureArcData" --resource-type "dataControllers"  // Will be uncomment upon "Directly Connected" functionality restore 

# Restoring State
Copy-Item -Path "C:\tmp\hosts_backup" -Destination "C:\Windows\System32\drivers\etc\hosts" -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\settings_backup.json" -Destination "C:\tmp\settings.json" -Recurse -Force -ErrorAction Continue

Remove-Item "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\User\settings.json" -Force
Remove-Item "C:\tmp\hosts_backup" -Force
Remove-Item "C:\tmp\settings_backup.json" -Force

Stop-Transcript

Stop-Process -Name powershell -Force
