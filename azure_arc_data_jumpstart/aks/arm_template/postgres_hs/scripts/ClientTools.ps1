param (
    [string]$servicePrincipalClientId,
    [string]$servicePrincipalClientSecret,
    [string]$adminUsername,
    [string]$tenantId,
    [string]$clusterName,
    [string]$resourceGroup,
    [string]$AZDATA_USERNAME,
    [string]$AZDATA_PASSWORD,
    [string]$ACCEPT_EULA,
    [string]$REGISTRY_USERNAME,
    [string]$REGISTRY_PASSWORD,
    [string]$ARC_DC_NAME,
    [string]$ARC_DC_SUBSCRIPTION,
    [string]$ARC_DC_REGION,
    [string]$POSTGRES_NAME,   
    [string]$POSTGRES_WORKER_NODE_COUNT,
    [string]$POSTGRES_DATASIZE,
    [string]$POSTGRES_SERVICE_TYPE,
    [string]$chocolateyAppList
)

[System.Environment]::SetEnvironmentVariable('servicePrincipalClientId', $servicePrincipalClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalClientSecret', $servicePrincipalClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $AZDATA_USERNAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $AZDATA_PASSWORD,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $ACCEPT_EULA,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('REGISTRY_USERNAME', $REGISTRY_USERNAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('REGISTRY_PASSWORD', $REGISTRY_PASSWORD,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_NAME', $ARC_DC_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_SUBSCRIPTION', $ARC_DC_SUBSCRIPTION,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_REGION', $ARC_DC_REGION,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_NAME', $POSTGRES_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_WORKER_NODE_COUNT', $POSTGRES_WORKER_NODE_COUNT,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_DATASIZE', $POSTGRES_DATASIZE,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_SERVICE_TYPE', $POSTGRES_SERVICE_TYPE,[System.EnvironmentVariableTarget]::Machine)

# Installing tools
New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli'
            #Run commands in parallel.
            Parallel 
                {
                    InlineScript {
                        param (
                            [string]$chocolateyAppList
                        )
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false)
                        {
                            try{
                                choco config get cacheLocation
                            }catch{
                                Write-Output "Chocolatey not detected, trying to install now"
                                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"
                    Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/microsoft.azuredatastudio-postgresql-0.2.6.zip" -OutFile "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/microsoft.arc-0.3.3.zip" -OutFile "C:\tmp\microsoft.arc-0.3.3.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/microsoft.azdata-0.1.2.zip" -OutFile "C:\tmp\microsoft.azdata-0.1.2.zip"
                    Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-aug-2020-new/msi/azdata-cli-20.1.1.msi" -OutFile "C:\tmp\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/scripts/Postgres_Cleanup.ps1" -OutFile "C:\tmp\Postgres_Cleanup.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/scripts/Postgres_Deploy.ps1" -OutFile "C:\tmp\Postgres_Deploy.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/settings_template.json" -OutFile "C:\tmp\settings_template.json"
                }
        }

ClientTools_01 | ft

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
                    Expand-Archive C:\tmp\azuredatastudio_repo.zip -DestinationPath 'C:\tmp\azuredatastudio_repo'
                    Expand-Archive C:\tmp\microsoft.arc-0.3.3.zip -DestinationPath 'C:\tmp\microsoft.arc-0.3.3'
                    Expand-Archive C:\tmp\microsoft.azdata-0.1.2.zip -DestinationPath 'C:\tmp\microsoft.azdata-0.1.2'                    
                    Expand-Archive C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip -DestinationPath 'C:\tmp\'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\tmp\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | ft 

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating Powershell postgres_connectivity Script
$postgres_connectivity = @'

Start-Transcript "C:\tmp\postgres_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

# Retreving PostgreSQL Server IP
azdata arc postgres server endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\tmp\postgres_instance_endpoint.txt"
Get-Content "C:\tmp\postgres_instance_endpoint.txt" | Where-Object {$_ -match '@'} | Set-Content "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt" 
$s.Split('@')[-1] | Out-File "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt"
$s.Substring(0, $s.IndexOf(':')) | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline

# Retreving PostgreSQL Server Name
Add-Content -Path "C:\tmp\merge.txt" -Value ("   ","postgres") -Encoding ascii -NoNewline

# Adding PostgreSQL Server Name & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\tmp\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii

# Creating Azure Data Studio settings for PostgreSQL connection
azdata arc postgres server endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\tmp\postgres_instance_endpoint.txt"
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\tmp\settings_template_backup.json" -Recurse -Force -ErrorAction Continue
Get-Content "C:\tmp\postgres_instance_endpoint.txt" | Where-Object {$_ -match '@'} | Set-Content "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt" 
$s.Split('@')[-1] | Out-File "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt"
$s.Substring(0, $s.IndexOf(':')) | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline
$s = Get-Content "C:\tmp\merge.txt"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'arc_postgres',$s | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\tmp\settings_template.json"
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue

# Cleaning garbage
Remove-Item "C:\tmp\postgres_instance_endpoint.txt" -Force
Remove-Item "C:\tmp\merge.txt" -Force
Remove-Item "C:\tmp\out.txt" -Force

# Restoring demo database
$podname = "$env:POSTGRES_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- /bin/bash -c "cd /tmp && curl -k -O https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/postgres_hs/AdventureWorks.sql"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- psql --username postgres -c 'CREATE DATABASE "adventureworks";'
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- psql --username postgres -d adventureworks -f /tmp/AdventureWorks.sql

Stop-Transcript

'@ > C:\tmp\postgres_connectivity.ps1

# Creating Powershell Logon Script
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

$azurePassword = ConvertTo-SecureString $env:servicePrincipalClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:tenantId -ServicePrincipal
Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:clusterName -Force

kubectl get nodes
azdata --version

Write-Host "Copying Azure Data Studio Extentions"
Write-Host "`n"

$ExtensionsDestination = "C:\Users\$env:adminUsername\.azuredatastudio-insiders\extensions\microsoft.arc-0.3.3"
Copy-Item -Path "C:\tmp\microsoft.arc-0.3.3\microsoft.arc-0.3.3\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\$env:adminUsername\.azuredatastudio-insiders\extensions\microsoft.azdata-0.1.2"
Copy-Item -Path "C:\tmp\microsoft.azdata-0.1.2\microsoft.azdata-0.1.2" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\$env:adminUsername\.azuredatastudio-insiders\extensions\"
Copy-Item -Path "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio - Insiders.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Deploying Azure Arc Data Controller
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --profile-name azure-arc-aks-premium-storage --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect
Start-Sleep -s 30

# Deploying Azure Arc PostgreSQL Hyperscale Server Group
azdata login --namespace $env:ARC_DC_NAME
azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT --storage-class-data managed-premium --storage-class-logs managed-premium
azdata arc postgres server endpoint list --name $env:POSTGRES_NAME

# Creating Postgres Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\postgres_connectivity.ps1" -WindowStyle Hidden -Wait

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
