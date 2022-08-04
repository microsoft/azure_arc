param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$registryUsername,
    [string]$registryPassword,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$mssqlmiName,
    [string]$POSTGRES_NAME,   
    [string]$POSTGRES_WORKER_NODE_COUNT,
    [string]$POSTGRES_DATASIZE,
    [string]$POSTGRES_SERVICE_TYPE,
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$capiArcDataClusterName,
    [string]$k3sArcClusterName,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$addsDomainName,
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
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryPassword', $registryPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('mssqlmiName', $mssqlmiName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_NAME', $POSTGRES_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_WORKER_NODE_COUNT', $POSTGRES_WORKER_NODE_COUNT,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_DATASIZE', $POSTGRES_DATASIZE,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_SERVICE_TYPE', $POSTGRES_SERVICE_TYPE,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('capiArcDataClusterName', $capiArcDataClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcClusterName', $k3sArcClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('addsDomainName', $addsDomainName,[System.EnvironmentVariableTarget]::Machine)

# Creating HciBox path
Write-Output "Creating HciBox paths"
$Env:HciBoxDir = "C:\HciBox"
$Env:HciBoxLogsDir = "C:\HciBox\Logs"
$Env:HciBoxVMDir = "C:\HciBox\Virtual Machines"
$Env:HciBoxKVDir = "C:\HciBox\KeyVault"
$Env:HciBoxGitOpsDir = "C:\HciBox\GitOps"
$Env:HciBoxIconDir = "C:\HciBox\Icons"
$Env:HciBoxVHDDir = "C:\HciBox\VHD"
$Env:HciBoxSDNDir = "C:\HciBox\SDN"
$Env:HciBoxWACDir = "C:\HciBox\Windows Admin Center"
$Env:agentScript = "C:\HciBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

New-Item -Path $Env:HciBoxDir -ItemType directory -Force
New-Item -Path $Env:HciBoxVHDDir -ItemType directory -Force
New-Item -Path $Env:HciBoxSDNDir -ItemType directory -Force
New-Item -Path $Env:HciBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:HciBoxVMDir -ItemType directory -Force
New-Item -Path $Env:HciBoxKVDir -ItemType directory -Force
New-Item -Path $Env:HciBoxGitOpsDir -ItemType directory -Force
New-Item -Path $Env:HciBoxIconDir -ItemType directory -Force
New-Item -Path $Env:HciBoxWACDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force

Start-Transcript -Path $Env:HciBoxLogsDir\Bootstrap.log

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

# All flavors
Write-Host "Fetching artifacts"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/hcibox_logo.png" -OutFile $Env:HciBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile $Env:HciBoxDir\DeploymentStatus.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:HciBoxLogsDir\LogInstructions.txt

Invoke-WebRequest ($templateBaseUrl + "../tests/GHActionDeploy.ps1") -OutFile "$Env:HciBoxDir\GHActionDeploy.ps1"
Invoke-WebRequest ($templateBaseUrl + "../tests/OpenSSHDeploy.ps1") -OutFile "$Env:HciBoxDir\OpenSSHDeploy.ps1"

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
#$Trigger = New-ScheduledTaskTrigger -AtLogOn
#$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\MonitorWorkbookLogonScript.ps1
#Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Downloading AzSHCI files
Write-Header "Downloading Azure Stack HCI configuration scripts"
Invoke-WebRequest https://aka.ms/wacdownload -OutFile $Env:HciBoxWACDir\WindowsAdminCenter.msi
Invoke-WebRequest ($templateBaseUrl + "artifacts/HciBoxLogonScript.ps1") -OutFile $Env:HciBoxDir\HciBoxLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/New-AzSHCISandbox.ps1") -OutFile $Env:HciBoxDir\New-AzSHCISandbox.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/Register-AzSHCI.ps1") -OutFile $Env:HciBoxDir\Register-AzSHCI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/AzSHCISandbox-Config.psd1") -OutFile $Env:HciBoxDir\AzSHCISandbox-Config.psd1
Invoke-WebRequest ($templateBaseUrl + "artifacts/Deploy-AKS.psd1") -OutFile $Env:HciBoxDir\Deploy-AKS.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/CertHelpers.ps1") -OutFile $Env:HciBoxSDNDir\CertHelpers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/NetworkControllerRESTWrappers.ps1") -OutFile $Env:HciBoxSDNDir\NetworkControllerRESTWrappers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/NetworkControllerWorkloadHelpers.psm1") -OutFile $Env:HciBoxSDNDir\NetworkControllerWorkloadHelpers.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExplorer.ps1") -OutFile $Env:HciBoxSDNDir\SDNExplorer.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpress.ps1") -OutFile $Env:HciBoxSDNDir\SDNExpress.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpressModule.psm1") -OutFile $Env:HciBoxSDNDir\SDNExpressModule.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpressUI.psm1") -OutFile $Env:HciBoxSDNDir\SDNExpressUI.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/Single-NC.psd1") -OutFile $Env:HciBoxSDNDir\Single-NC.psd1

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Disable Server Manager WAC prompt
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\ServerManager"
$Name = "DoNotPopWACConsoleAtSMLaunch"
$Value = "1"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Network Profile prompt
$RegistryPath = "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}

# Configuring CredSSP and WinRM
#Enable-WSManCredSSP -Role Server -Force | Out-Null
#Enable-WSManCredSSP -Role Client -DelegateComputer $Env:COMPUTERNAME -Force | Out-Null

# Creating scheduled task for HciBoxLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\HciBoxLogonScript.ps1
Register-ScheduledTask -TaskName "HciBoxLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Install Hyper-V and reboot
Write-Header "Installing Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:HciBoxLogsDir\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:HciBoxLogsDir\Bootstrap.log -Force
