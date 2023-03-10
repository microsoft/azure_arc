param (
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$workspaceName,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$rdpPort
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ArcBoxDir', "C:\ArcBoxLevelup", [System.EnvironmentVariableTarget]::Machine)

# Creating ArcBox path
Write-Output "Creating ArcBox path"
$Env:ArcBoxDir = "C:\ArcBoxLevelup"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$Env:agentScript = "$Env:ArcBoxDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"

New-Item -Path $Env:ArcBoxDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxVMDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxGitOpsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force

Start-Transcript -Path $Env:ArcBoxLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

# Installing DHCP service 
Write-Output "Installing DHCP service"
Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

# Installing tools
Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'azure-cli,az.powershell,microsoft-edge,azcopy10,ssms,setdefaultbrowser'

try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Chocolatey Apps Specified"

$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

foreach ($app in $appsToInstall) {
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
    
}

Write-Host "Fetching Artifacts for levelup"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/arcbox_wallpaper.png" -OutFile $Env:ArcBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile $Env:ArcBoxDir\DeploymentStatus.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:ArcBoxLogsDir\LogInstructions.txt

# ITPro
Write-Host "Fetching Artifacts for ArcBox Levelup"
Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgent.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentSQLSP.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/testDefenderForSQL.ps1") -OutFile $Env:ArcBoxDir\testDefenderForSQL.ps1   
Invoke-WebRequest ($templateBaseUrl + "artifacts/InstallArcSQLExtensionAtScale.ps1  ") -OutFile $Env:agentScript\InstallArcSQLExtensionAtScale.ps1   

Write-Header "Configuring Logon Scripts"

# Creating scheduled task for ArcServersLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcBoxDir\ArcServersLogonScript.ps1
Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

Write-Header "Installing Hyper-V"

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Change RDP Port
if (($rdpPort -ne $null) -and ($rdpPort -ne "") -and ($rdpPort -ne "3389"))
{
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0
    
    # RDP port
    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host Get RDP PortNumber: $portNumber
    if (!($portNumber -eq $rdpPort))
    {
      Write-Host Setting RDP PortNumber to $rdpPort
      Set-ItemProperty -Path $RDPTCPpath -name 'PortNumber' -Value $rdpPort
      Restart-Service TermService -force
    }
    
    #Setup firewall rules
    if ($rdpPort -eq 3389)
    {
      netsh advfirewall firewall set rule group="remote desktop" new Enable=Yes
    } 
    else
    {
      $systemroot = get-content env:systemroot
      netsh advfirewall firewall add rule name="Remote Desktop - Custom Port" dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$RDPPort enable=yes
    }
}

# Clean up Bootstrap.log
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:ArcBoxLogsDir\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:ArcBoxLogsDir\Bootstrap.log -Force
