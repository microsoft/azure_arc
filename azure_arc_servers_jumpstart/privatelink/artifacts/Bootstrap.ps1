param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$subscriptionId,
    [string]$Location,
    [string]$PEname, 
    [string]$adminUsername,
    [string]$PLscope 

)
[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('Location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('PEname', $PEname,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('PLscope', $PLscope,[System.EnvironmentVariableTarget]::Machine)

# Creating Log File
New-Item -Path "C:\" -Name "Temp" -ItemType "directory" -Force
Start-Transcript -Path C:\Temp\LogonScript.log

#Install pre-requisites
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell'
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
                        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
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
ClientTools_01 | Format-Table

#Download and run Arc onboarding script
Invoke-WebRequest ("https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/privatelink/artifacts/installArcAgent.ps1") -OutFile C:\Temp\installArcAgent.ps1

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HubsSidebarEnabled'
$Value        = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HideFirstRunExperience'
$Value        = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\installArcAgent.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "${adminUsername}" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content C:\Temp\LogonScript.log -Force | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content C:\Temp\LogonScript.log -Force
