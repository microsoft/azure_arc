param (
    [string]$subscriptionId,
    [string]$servicePrincipalAppId,
    [string]$servicePrincipalSecret,
    [string]$servicePrincipalTenantId,
    [string]$resourceGroup,
    [string]$location,
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$workspaceName,
    [string]$templateBaseUrl
)

[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalAppId', $servicePrincipalAppId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalSecret', $servicePrincipalSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalTenantId', $servicePrincipalTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)

# Creating ArcBox path
Write-Output "Creating Jumpstart path"

$Env:JumpstartDir = "C:\Jumpstart"
$Env:JumpstartLogsDir = "C:\Jumpstart\Logs"
$Env:JumpstartScriptDir = "C:\Jumpstart\agentScript"
$Env:JumpstartTempDir = "C:\Temp"

New-Item -Path $Env:JumpstartDir -ItemType directory -Force
New-Item -Path $Env:JumpstartLogsDir -ItemType directory -Force
New-Item -Path $Env:JumpstartScriptDir -ItemType directory -Force
New-Item -Path $Env:JumpstartTempDir -ItemType directory -Force

Start-Transcript -Path $Env:JumpstartLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Installing tools
$chocolateyAppList = "az.powershell,azure-cli,sql-server-management-studio"

try{
    choco config get cacheLocation
}catch{
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Installing specified Chocolatey apps..."  

$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

foreach ($app in $appsToInstall)
{
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
}

# Downloading artifacts & enabling Fusion logging
Invoke-WebRequest ($templateBaseUrl + "arm_template/scripts/LogonScript.ps1") -OutFile $Env:JumpstartScriptDir\LogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "arm_template/scripts/installArcAgentSQL.ps1") -OutFile $Env:JumpstartScriptDir\installArcAgentSQL.ps1

New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Fusion" -Name "EnableLog" -Value 1 -PropertyType "DWord"

(Get-Content -path "$Env:JumpstartScriptDir\installArcAgentSQL.ps1" -Raw) -replace '\$spnClientId',"'$Env:servicePrincipalAppId'" -replace '\$spnClientSecret',"'$Env:servicePrincipalSecret'" -replace '\$myResourceGroup',"'$Env:resourceGroup'" -replace '\$spnTenantId',"'$Env:servicePrincipalTenantId'" -replace '\$azureLocation',"'$Env:location'" -replace '\$subscriptionId',"'$Env:subscriptionId'" -replace '\$logAnalyticsWorkspaceName',"'$Env:workspaceName'" | Set-Content -Path "$Env:JumpstartScriptDir\installArcAgentSQLModified.ps1"

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:JumpstartScriptDir\LogonScript.ps1
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
