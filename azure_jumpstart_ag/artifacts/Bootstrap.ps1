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
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$aksProdClusterName,
    [string]$aksDevClusterName,
    [string]$iotHubHostName,
    [string]$acrNameProd,
    [string]$acrNameDev,
    [string]$githubUser,
    [string]$templateBaseUrl
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
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksProdClusterName', $aksProdClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksDevClusterName', $aksDevClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('iotHubHostName', $iotHubHostName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('acrNameProd', $acrNameProd, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('acrNameDev', $acrNameDev, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AgDir', "C:\Ag", [System.EnvironmentVariableTarget]::Machine)


# Creating Ag path
Write-Output "Creating Ag path"
$Env:AgDir = "C:\Ag"
$Env:AgLogsDir = "$Env:AgDir\Logs"
$Env:AgVMDir = "$Env:AgDir\Virtual Machines"
$Env:AgKVDir = "$Env:AgDir\KeyVault"
$Env:AgGitOpsDir = "$Env:AgDir\GitOps"
$Env:AgIconDir = "$Env:AgDir\Icons"
$Env:agentScript = "$Env:AgDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:AgRetailDir = "$Env:AgDir\Retail"

New-Item -Path $Env:AgDir -ItemType directory -Force
New-Item -Path $Env:AgLogsDir -ItemType directory -Force
New-Item -Path $Env:AgVMDir -ItemType directory -Force
New-Item -Path $Env:AgKVDir -ItemType directory -Force
New-Item -Path $Env:AgGitOpsDir -ItemType directory -Force
New-Item -Path $Env:AgIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force
New-Item -Path $Env:AgRetailDir -ItemType directory -Force

Start-Transcript -Path $Env:AgLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing tools
Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,ssms,dotnetcore-3.1-sdk,setdefaultbrowser,zoomit,openssl.light,mqtt-explorer'

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

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

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

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

# All Industries
Write-Host "Fetching Artifacts for All Industries"
Invoke-WebRequest ($templateBaseUrl + "artifacts/agLogonScript.ps1") -OutFile $Env:AgDir\agLogonScript.ps1

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:AgDir\agLogonScript.ps1
Register-ScheduledTask -TaskName "AgLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force


# Installing DHCP service
#Write-Output "Installing DHCP service"
#Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

<#Write-Header "Install Az Powershell module"
Install-Module -Name PowerShellGet -Force
Install-Module -Name Az -Scope AllUsers -Repository PSGallery -Force
#>

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

Stop-Transcript

# Clean up Bootstrap.log
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:AgLogsDir\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:AgLogsDir\Bootstrap.log -Force
