$ArcBoxDir = "C:\ArcBox"
$ArcBoxLogsDir = "$ArcBoxDir\Logs"

# Creating deployment logs bundle
Write-Host "`n"
Write-Host "Sleeping for 10 seconds before creating deployment logs bundle"
Start-Sleep -Seconds 10
Write-Host "`n"
Write-Host "Creating deployment logs bundle"
7z a $ArcBoxLogsDir\LogsBundle-"$env:subscriptionId".zip $ArcBoxLogsDir\*.log -xr!$ArcBoxLogsDir\*.zip
