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
    [string]$MSSQL_MI_NAME,
    [string]$chocolateyAppList,
    [string]$DOCKER_REGISTRY,
    [string]$DOCKER_REPOSITORY,
    [string]$DOCKER_TAG
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
[System.Environment]::SetEnvironmentVariable('MSSQL_MI_NAME', $MSSQL_MI_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_REGISTRY', $DOCKER_REGISTRY,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_REPOSITORY', $DOCKER_REPOSITORY,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_TAG', $DOCKER_TAG,[System.EnvironmentVariableTarget]::Machine)

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
                    Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=2142211" -OutFile "C:\tmp\azuredatastudio.zip"
                    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\tmp\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/mssql_mi/scripts/MSSQL_MI_Cleanup.ps1" -OutFile "C:\tmp\MSSQL_MI_Cleanup.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/mssql_mi/scripts/MSSQL_MI_Deploy.ps1" -OutFile "C:\tmp\MSSQL_MI_Deploy.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/mssql_mi/settings_template.json" -OutFile "C:\tmp\settings_template.json"
                }
        }

ClientTools_01 | ft

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\tmp\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\tmp\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | ft 

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating Powershell sql_connectivity Script
$sql_connectivity = @'

Start-Transcript "C:\tmp\sql_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

Start-Transcript "C:\tmp\sql_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

# Retreving SQL Managed Instance IP
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline

# Retreving SQL Managed Instance FQDN
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.IndexOf(' ')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
Add-Content -Path "C:\tmp\merge.txt" -Value ("   ",$s) -Encoding ascii -NoNewline

# Adding SQL Instance FQDN & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\tmp\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii

# Retreving SQL Managed Instance FQDN & Port
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\tmp\sql_instance_settings.txt" -Encoding ascii -NoNewline

# Creating Azure Data Studio settings for SQL Managed Instance connection
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\tmp\settings_template_backup.json" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\sql_instance_settings.txt"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'arc_sql_mi',$s | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path "C:\tmp\settings_template.json"
(Get-Content -Path "C:\tmp\settings_template.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\tmp\settings_template.json"
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue

# Cleaning garbage
Remove-Item "C:\tmp\sql_instance_settings.txt" -Force
Remove-Item "C:\tmp\sql_instance_list.txt" -Force
Remove-Item "C:\tmp\merge.txt" -Force

# Downloading demo database
$podname = "$env:MSSQL_MI_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

Stop-Transcript

'@ > C:\tmp\sql_connectivity.ps1

# Creating Powershell Logon Script
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

$azurePassword = ConvertTo-SecureString $env:servicePrincipalClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:tenantId -ServicePrincipal
Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:clusterName -Force

kubectl get nodes
azdata --version

Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"

$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"

& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Deploying Azure Arc Data Controller
start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc config init --source azure-arc-aks-premium-storage --path ./custom
if(($env:DOCKER_REGISTRY -ne $NULL) -or ($env:DOCKER_REGISTRY -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.registry=$env:DOCKER_REGISTRY"
}
if(($env:DOCKER_REPOSITORY -ne $NULL) -or ($env:DOCKER_REPOSITORY -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.repository=$env:DOCKER_REPOSITORY"
}
if(($env:DOCKER_TAG -ne $NULL) -or ($env:DOCKER_TAG -ne ""))
{
    azdata arc dc config replace --path ./custom/control.json --json-values "spec.docker.imageTag=$env:DOCKER_TAG"
}

azdata arc dc create --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:resourceGroup --location $env:ARC_DC_REGION --connectivity-mode indirect --path ./custom

# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME --storage-class-data managed-premium --storage-class-logs managed-premium

azdata arc sql mi list

# Creating MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\sql_connectivity.ps1" -WindowStyle Hidden -Wait

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
