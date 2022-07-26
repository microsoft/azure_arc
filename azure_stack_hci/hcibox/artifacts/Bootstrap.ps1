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
Write-Output "Creating HciBox path"
$Env:HciBoxDir = "C:\HciBox"
$Env:HciBoxLogsDir = "C:\HciBox\Logs"
$Env:HciBoxVMDir = "C:\HciBox\Virtual Machines"
$Env:HciBoxKVDir = "C:\HciBox\KeyVault"
$Env:HciBoxGitOpsDir = "C:\HciBox\GitOps"
$Env:HciBoxIconDir = "C:\HciBox\Icons"
$Env:HciBoxVHDDir = "C:\HciBox\VHD"
$Env:HciBoxSDNDir = "C:\HciBox\sdn"
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

# All flavors
Write-Host "Fetching Artifacts for All Flavors"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/HciBox_wallpaper.png" -OutFile $Env:HciBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/MonitorWorkbookLogonScript.ps1") -OutFile $Env:HciBoxDir\MonitorWorkbookLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.parameters.json") -OutFile $Env:HciBoxDir\mgmtMonitorWorkbook.parameters.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile $Env:HciBoxDir\DeploymentStatus.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:HciBoxLogsDir\LogInstructions.txt

Invoke-WebRequest ($templateBaseUrl + "../tests/GHActionDeploy.ps1") -OutFile "$Env:HciBoxDir\GHActionDeploy.ps1"
Invoke-WebRequest ($templateBaseUrl + "../tests/OpenSSHDeploy.ps1") -OutFile "$Env:HciBoxDir\OpenSSHDeploy.ps1"

# Workbook template
if ($flavor -eq "ITPro") {
    Write-Host "Fetching Workbook Template Artifact for ITPro"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookITPro.json") -OutFile $Env:HciBoxDir\mgmtMonitorWorkbook.json
}
elseif ($flavor -eq "DevOps") {
    Write-Host "Fetching Workbook Template Artifact for DevOps"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookDevOps.json") -OutFile $Env:HciBoxDir\mgmtMonitorWorkbook.json
}
else {
    Write-Host "Fetching Workbook Template Artifact for Full"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookFull.json") -OutFile $Env:HciBoxDir\mgmtMonitorWorkbook.json
}

# ITPro
if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    Write-Host "Fetching Artifacts for ITPro Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:HciBoxDir\ArcServersLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:HciBoxDir\agentScript\installArcAgent.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:HciBoxDir\agentScript\installArcAgentSQLSP.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentUbuntu.sh") -OutFile $Env:HciBoxDir\agentScript\installArcAgentUbuntu.sh
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentCentOS.sh") -OutFile $Env:HciBoxDir\agentScript\installArcAgentCentOS.sh
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arcsql.ico") -OutFile $Env:HciBoxIconDir\arcsql.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcSQLManualOnboarding.ps1") -OutFile $Env:HciBoxDir\ArcSQLManualOnboarding.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLUser.ps1") -OutFile $Env:HciBoxDir\installArcAgentSQLUser.ps1
}

# DevOps
if ($flavor -eq "DevOps") {
    Write-Host "Fetching Artifacts for DevOps Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DevOpsLogonScript.ps1") -OutFile $Env:HciBoxDir\DevOpsLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/BookStoreLaunch.ps1") -OutFile $Env:HciBoxDir\BookStoreLaunch.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookbuyer.yaml") -OutFile $Env:HciBoxKVDir\bookbuyer.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookstore.yaml") -OutFile $Env:HciBoxKVDir\bookstore.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/hello-arc.yaml") -OutFile $Env:HciBoxKVDir\hello-arc.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sGitOps.ps1") -OutFile $Env:HciBoxGitOpsDir\K3sGitOps.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sRBAC.ps1") -OutFile $Env:HciBoxGitOpsDir\K3sRBAC.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/ResetBookstore.ps1") -OutFile $Env:HciBoxGitOpsDir\ResetBookstore.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arc.ico") -OutFile $Env:HciBoxIconDir\arc.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/bookstore.ico") -OutFile $Env:HciBoxIconDir\bookstore.ico
}

# Full
if ($flavor -eq "Full") {
    Write-Host "Fetching Artifacts for Full Flavor"
    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile $Env:HciBoxDir\azuredatastudio.zip
    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile $Env:HciBoxDir\AZDataCLI.msi
    Invoke-WebRequest ($templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile $Env:HciBoxDir\settingsTemplate.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataServicesLogonScript.ps1") -OutFile $Env:HciBoxDir\DataServicesLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DeployPostgreSQL.ps1") -OutFile $Env:HciBoxDir\DeployPostgreSQL.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMI.ps1") -OutFile $Env:HciBoxDir\DeploySQLMI.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:HciBoxDir\dataController.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:HciBoxDir\dataController.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.json") -OutFile $Env:HciBoxDir\postgreSQL.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.parameters.json") -OutFile $Env:HciBoxDir\postgreSQL.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.json") -OutFile $Env:HciBoxDir\sqlmi.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.parameters.json") -OutFile $Env:HciBoxDir\sqlmi.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile $Env:HciBoxDir\SQLMIEndpoints.ps1
    Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip" -OutFile $Env:HciBoxDir\SqlQueryStress.zip
}

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

if ($flavor -eq "Full") {
    Write-Header "Installing Azure Data Studio"
    Expand-Archive $Env:HciBoxDir\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
    Start-Process msiexec.exe -Wait -ArgumentList "/I $Env:HciBoxDir\AZDataCLI.msi /quiet"
}

Write-Header "Configuring Logon Scripts"

if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    # Creating scheduled task for ArcServersLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\ArcServersLogonScript.ps1
    #Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "Full") {
    # Creating scheduled task for DataServicesLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn 
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\DataServicesLogonScript.ps1
    #Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "DevOps") {
    # Creating scheduled task for DevOpsLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn 
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\DevOpsLogonScript.ps1
    #Register-ScheduledTask -TaskName "DevOpsLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HciBoxDir\MonitorWorkbookLogonScript.ps1
#Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Downloading AzSHCI files
Write-Header "Downloading Azure Stack HCI configuration scripts"
# Invoke-WebRequest https://aka.ms/AAd8dvp -OutFile $Env:HciBoxVHDDir\AZSHCI.vhdx
# Invoke-WebRequest https://aka.ms/AAbclsv -OutFile $Env:HciBoxVHDDir\GUI.vhdx
# Invoke-WebRequest https://aka.ms/wacdownload -OutFile $Env:HciBoxVHDDir\WindowsAdminCenter.msi
Invoke-WebRequest ($templateBaseUrl + "artifacts/Setup-AzSHCI.ps1") -OutFile $Env:HciBoxDir\Setup-AzSHCI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/Register-AzSHCI.ps1") -OutFile $Env:HciBoxDir\Register-AzSHCI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/AzSHCI-Config.psd1") -OutFile $Env:HciBoxDir\AzSHCI-Config.psd1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/CertHelpers.ps1") -OutFile $Env:HciBoxSDNDir\CertHelpers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/NetworkControllerRESTWrappers.ps1") -OutFile $Env:HciBoxSDNDir\NetworkControllerRESTWrappers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/NetworkControllerWorkloadHelpers.psm1") -OutFile $Env:HciBoxSDNDir\NetworkControllerWorkloadHelpers.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/SDNExplorer.ps1") -OutFile $Env:HciBoxSDNDir\SDNExplorer.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/SDNExpress.ps1") -OutFile $Env:HciBoxSDNDir\SDNExpress.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/SDNExpressModule.psm1") -OutFile $Env:HciBoxSDNDir\SDNExpressModule.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/SDNExpressUI.psm1") -OutFile $Env:HciBoxSDNDir\SDNExpressUI.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/sdn/Single-NC.psd1") -OutFile $Env:HciBoxSDNDir\Single-NC.psd1

# Configure storage pools and data disks
Write-Header "Configuring storage"
New-StoragePool -FriendlyName AsHciPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
$disks = Get-StoragePool -FriendlyName AsHciPool -IsPrimordial $False | Get-PhysicalDisk
$diskNum = $disks.Count
New-VirtualDisk -StoragePoolFriendlyName AsHciPool -FriendlyName AsHciDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
$vDisk = Get-VirtualDisk -FriendlyName AsHciDisk
if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter V -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}
elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
    $vDisk | Get-Disk | New-Partition -DriveLetter V -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}

# Install Hyper-V and reboot
Write-Header "Installing Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:HciBoxLogsDir\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:HciBoxLogsDir\Bootstrap.log -Force
