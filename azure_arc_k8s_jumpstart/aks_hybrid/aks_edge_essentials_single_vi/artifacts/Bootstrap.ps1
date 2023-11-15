param (
    [string]$adminUsername,
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$location,
    [string]$templateBaseUrl,
    [string]$resourceGroup,
    [string]$kubernetesDistribution,
    [string]$videoIndexerAccountName,
    [string]$videoIndexerAccountId,
    [string]$rdpPort
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('kubernetesDistribution', $kubernetesDistribution,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('videoIndexerAccountName', $videoIndexerAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('videoIndexerAccountId', $videoIndexerAccountId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('rdpPort', $rdpPort,[System.EnvironmentVariableTarget]::Machine)

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

$ErrorActionPreference = "SilentlyContinue"

##############################################################
# Change RDP Port 
##############################################################
Write-Host "RDP port number from configuration is $rdpPort"
if (($rdpPort -ne $null) -and ($rdpPort -ne "") -and ($rdpPort -ne "3389")) {
  Write-Host "Configuring RDP port number to $rdpPort"
  $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
  $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
  Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0

  # RDP port
  $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
  Write-Host "Current RDP PortNumber: $portNumber"
  if (!($portNumber -eq $rdpPort)) {
    Write-Host Setting RDP PortNumber to $rdpPort
    Set-ItemProperty -Path $RDPTCPpath -name 'PortNumber' -Value $rdpPort
    Restart-Service TermService -force
  }

  #Setup firewall rules
  if ($rdpPort -eq 3389) {
    netsh advfirewall firewall set rule group="remote desktop" new Enable=Yes
  } 
  else {
    $systemroot = get-content env:systemroot
    netsh advfirewall firewall add rule name="Remote Desktop - Custom Port" dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$RDPPort enable=yes
  }

  Write-Host "RDP port configuration complete."
}

# Downloading GitHub artifacts
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogonScript.ps1") -OutFile "C:\Temp\LogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/longhorn.yaml") -OutFile "C:\Temp\longhorn.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/video/video.mp4") -OutFile "C:\Temp\video.mp4"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "C:\Temp\wallpaper.png"
Invoke-WebRequest "https://github.com/certbot/certbot/releases/latest/download/certbot-beta-installer-win_amd64_signed.exe" -OutFile "C:\Temp\certbot-beta-installer-win_amd64_signed.exe"

##############################################################
# Install Azure CLI (64-bit not available via Chocolatey)
##############################################################
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

# Installing tools
Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'az.powershell,kubernetes-cli,kubernetes-helm,vscode'
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Start-Process "C:\Temp\certbot-beta-installer-win_amd64_signed.exe" -Wait -ArgumentList '/S'

try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Chocolatey Apps Specified"

$appsToInstall = $chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }

foreach ($app in $appsToInstall)
{
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
}

# Enable VirtualMachinePlatform feature, the vm reboot will be done in DSC extension
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

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

# Creating scheduled task for LogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content C:\Temp\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content C:\Temp\Bootstrap.log -Force