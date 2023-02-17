param (
    [string]$adminUsername,
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
    [string]$automationTriggerAtLogon
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon,[System.EnvironmentVariableTarget]::Machine)

# Creating ArcJS path
Write-Output "Creating ArcJS path"
$Env:ArcJSDir = "C:\Jumpstart"
$Env:ArcJSLogsDir = "$Env:ArcJSDir\Logs"
$Env:ArcJSVMDir = "$Env:ArcJSDir\VirtualMachines"
$Env:ArcJSIconDir = "$Env:ArcJSDir\Icons"
$Env:agentScript = "$Env:ArcJSDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"

New-Item -Path $Env:ArcJSDir -ItemType directory -Force
New-Item -Path $Env:ArcJSLogsDir -ItemType directory -Force
New-Item -Path $Env:ArcJSVMDir -ItemType directory -Force
New-Item -Path $Env:ArcJSIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force

Start-Transcript -Path "$Env:ArcJSLogsDir\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
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
$chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,ssms,dotnetcore-3.1-sdk,setdefaultbrowser,zoomit'

try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Chocolatey Apps Specified"

$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

foreach ($app in $appsToInstall)
{
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
}

Write-Header "Fetching GitHub Artifacts"

Write-Host "Fetching Artifacts for All Flavors"
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/LogInstructions.txt") -OutFile $Env:ArcJSLogsDir\LogInstructions.txt

Write-Host "Fetching Artifacts for Arc SQL Server"
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/ArcServersLogonScript.ps1") -OutFile "$Env:ArcJSDir\ArcServersLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/installArcAgentSQLSP.ps1") -OutFile "$Env:agentScript\installArcAgentSQLSP.ps1"
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/installArcAgent.ps1") -OutFile "$Env:agentScript\installArcAgent.ps1"
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/icons/arcsql.ico") -OutFile $Env:ArcJSIconDir\arcsql.ico
Invoke-WebRequest ($templateBaseUrl + "azure/windows/defender_sql/arm_template/scripts/testDefenderForSQL.ps1") -OutFile $Env:ArcJSDir\testDefenderForSQL.ps1
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "$Env:tempDir\wallpaper.png"

Write-Header "Configuring Logon Scripts"

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

# Creating scheduled task for ArcServersLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcJSDir\ArcServersLogonScript.ps1
Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

Write-Header "Installing Hyper-V"

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:ArcJSLogsDir\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:ArcJSLogsDir\Bootstrap.log -Force
