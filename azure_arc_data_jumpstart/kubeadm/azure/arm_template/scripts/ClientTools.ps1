param (
    [string]$servicePrincipalClientId,
    [string]$servicePrincipalClientSecret,
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$K8svmName,
    [string]$tenantId,
    [string]$ARC_DC_RG,
    [string]$AZDATA_USERNAME,
    [string]$AZDATA_PASSWORD,
    [string]$ACCEPT_EULA,
    [string]$DOCKER_USERNAME,
    [string]$DOCKER_PASSWORD,
    [string]$ARC_DC_NAME,
    [string]$ARC_DC_SUBSCRIPTION,
    [string]$ARC_DC_REGION,
    [string]$chocolateyAppList
)

[System.Environment]::SetEnvironmentVariable('servicePrincipalClientId', $servicePrincipalClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalClientSecret', $servicePrincipalClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('K8svmName', $K8svmName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_RG', $ARC_DC_RG,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $AZDATA_USERNAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $AZDATA_PASSWORD,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $ACCEPT_EULA,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_USERNAME', $DOCKER_USERNAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('DOCKER_PASSWORD', $DOCKER_PASSWORD,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_NAME', $ARC_DC_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_SUBSCRIPTION', $ARC_DC_SUBSCRIPTION,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ARC_DC_REGION', $ARC_DC_REGION,[System.EnvironmentVariableTarget]::Machine)

# Installing tools
New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,putty'
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
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/microsoft.azuredatastudio-postgresql-0.2.6.zip" -OutFile "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip"                    
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/microsoft.arc-0.3.3.zip" -OutFile "C:\tmp\microsoft.arc-0.3.3.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/microsoft.azdata-0.1.2.zip" -OutFile "C:\tmp\microsoft.azdata-0.1.2.zip"
                    Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-aug-2020-new/msi/azdata-cli-20.1.1.msi" -OutFile "C:\tmp\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/aks/arm_template/dc_vanilla/settings.json" -OutFile "C:\tmp\settings.json"                    
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

# Creating Powershell Logon Script
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

Write-Host "Connecting to Azure account"
Write-Host "`n"
$azurePassword = ConvertTo-SecureString $env:servicePrincipalClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:tenantId -ServicePrincipal

Write-Host "Copying kubeconfig file from Kubernetes VM"
Write-Host "`n"
$VM=Get-AzVM -ResourceGroupName $env:ARC_DC_RG -Name $env:K8svmName
$Profile=$VM.NetworkProfile.NetworkInterfaces.Id.Split("/") | Select -Last 1
$IPConfig=Get-AzNetworkInterface -Name $Profile
$env:IPAddress=$IPConfig.IpConfigurations.PrivateIpAddress

New-Item -Path "C:\Users\$env:adminUsername" -Name ".kube" -ItemType "directory" -Force
echo y | pscp -pw $env:adminPassword -P 22 $env:IPAddress':/home/'$env:adminUsername'/.kube/config' C:\Users\$env:adminUsername\.kube\config

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

$SettingsDestination = "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User"
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Hidden
Start-Sleep -s 5
Stop-Process -Name "azuredatastudio-insiders" -Force
Copy-Item -Path "C:\tmp\settings.json" -Destination $SettingsDestination -Recurse -Force -ErrorAction Continue

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio - Insiders.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

Stop-Transcript

Stop-Process -name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
