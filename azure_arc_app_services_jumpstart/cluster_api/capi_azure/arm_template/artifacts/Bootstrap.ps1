param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$deployAppService,
    [string]$deployFunction,
    [string]$deployLogicApp,
    [string]$templateBaseUrl,
    [string]$adminEmail,
    [string]$deployApiMgmt
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployAppService', $deployAppService,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployFunction', $deployFunction,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployLogicApp', $deployLogicApp,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployApiMgmt', $deployApiMgmt,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminEmail', $adminEmail,[System.EnvironmentVariableTarget]::Machine)

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Downloading GitHub artifacts for AppServicesLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/capiStorageClass.yaml") -OutFile "C:\Temp\capiStorageClass.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/AppServicesLogonScript.ps1") -OutFile "C:\Temp\AppServicesLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployAppService.ps1") -OutFile "C:\Temp\deployAppService.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployFunction.ps1") -OutFile "C:\Temp\deployFunction.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployApiMgmt.ps1") -OutFile "C:\Temp\deployApiMgmt.ps1" 
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployLogicApp.ps1") -OutFile "C:\Temp\deployLogicApp.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "C:\Temp\wallpaper.png"

# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm,azure-functions-core-tools-3,azurefunctions-vscode,dotnetcore-sdk,vscode-csharp,microsoftazurestorageexplorer,7zip'
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
                }
        }

ClientTools_01 | Format-Table

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

Creating scheduled task for AppServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\AppServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "AppServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
