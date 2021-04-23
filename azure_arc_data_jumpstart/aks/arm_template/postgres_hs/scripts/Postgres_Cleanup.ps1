Start-Transcript -Path C:\tmp\postgres_cleanup.log

# Deleting Azure Arc Data Controller namespace and it's resources (PostgreSQL incl.)
Start-Process PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; Start-Sleep 5; Clear-Host }}
azdata arc postgres server delete --name $env:POSTGRES_NAME --force
azdata arc dc delete --name $env:ARC_DC_NAME --namespace $env:ARC_DC_NAME --yes

# az login --service-principal --username $env:SPN_CLIENT_ID --password $env:SPN_CLIENT_SECRET --tenant $env:SPN_TENANT_ID --output none // Will be uncomment upon "Directly Connected" functionality restore 
# az resource delete -g $env:resourceGroup -n $env:ARC_DC_NAME --namespace "Microsoft.AzureArcData" --resource-type "dataControllers" // Will be uncomment upon "Directly Connected" functionality restore

# Restoring State
Copy-Item -Path "C:\tmp\hosts_backup" -Destination "C:\Windows\System32\drivers\etc\hosts" -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\settings_template_backup.json" -Destination "C:\tmp\settings_template.json" -Recurse -Force -ErrorAction Continue

Remove-Item "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Force
Remove-Item "C:\tmp\hosts_backup" -Force
Remove-Item "C:\tmp\settings_template_backup.json" -Force

Stop-Transcript

Stop-Process -Name powershell -Force
