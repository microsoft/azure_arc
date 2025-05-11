param (
  [string]$adminUsername,
  [string]$adminPassword,
  [string]$spnClientId,
  [string]$spnClientSecret,
  [string]$spnProviderId,
  [string]$spnTenantId,
  [string]$subscriptionId,
  [string]$resourceGroup,
  [string]$azureLocation,
  [string]$stagingStorageAccountName,
  [string]$workspaceName,
  [string]$templateBaseUrl,
  [string]$registerCluster,
  [string]$deployAKSHCI,
  [string]$deployResourceBridge,
  [string]$natDNS,
  [string]$rdpPort,
  [string]$autoDeployClusterResource,
  [string]$autoUpgradeClusterResource,
  [string]$debugEnabled,
  [string]$vmAutologon
)

Write-Output "Input parameters:"
$PSBoundParameters

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnProviderId', $spnProviderId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', $deployAKSHCI, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployResourceBridge', $deployResourceBridge, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoDeployClusterResource', $autoDeployClusterResource, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoUpgradeClusterResource', $autoUpgradeClusterResource, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registerCluster', $registerCluster, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('natDNS', $natDNS, [System.EnvironmentVariableTarget]::Machine)

if ($debugEnabled -eq "true") {
  [System.Environment]::SetEnvironmentVariable('ErrorActionPreference', "Break", [System.EnvironmentVariableTarget]::Machine)
} else {
  [System.Environment]::SetEnvironmentVariable('ErrorActionPreference', "Continue", [System.EnvironmentVariableTarget]::Machine)
}

$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

if ($vmAutologon -eq "true") {

  Write-Host "Configuring VM Autologon"

  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" "1"
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUserName" $adminUsername
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" $adminPassword

} else {

  Write-Host "Not configuring VM Autologon"

}

#######################################################################
## Setup basic environment
#######################################################################
# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Creating LocalBox path
$LocalBoxPath = "C:\LocalBox"
[System.Environment]::SetEnvironmentVariable('LocalBoxDir', $LocalBoxPath, [System.EnvironmentVariableTarget]::Machine)
New-Item -Path $LocalBoxPath -ItemType directory -Force

# Downloading configuration file
$ConfigurationDataFile = "$LocalBoxPath\LocalBox-Config.psd1"
[System.Environment]::SetEnvironmentVariable('LocalBoxConfigFile', $ConfigurationDataFile, [System.EnvironmentVariableTarget]::Machine)
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/LocalBox-Config.psd1") -OutFile $ConfigurationDataFile

# Importing configuration data
$LocalBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Create paths
foreach ($path in $LocalBoxConfig.Paths.GetEnumerator()) {
  Write-Output "Creating path $($path.Value)"
  New-Item -Path $path.Value -ItemType directory -Force | Out-Null
}

# Begin transcript
Start-Transcript -Path "$($LocalBoxConfig.Paths["LogsDir"])\Bootstrap.log"

#################################################################################
## Setup host infrastructure and apps
#################################################################################
# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

Write-Host "Downloading Azure Local configuration scripts"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/localbox_wallpaper_dark.png" -OutFile $LocalBoxPath\wallpaper.png
Invoke-WebRequest https://aka.ms/wacdownload -OutFile "$($LocalBoxConfig.Paths["WACDir"])\WindowsAdminCenter.msi"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/LocalBoxLogonScript.ps1") -OutFile $LocalBoxPath\LocalBoxLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/New-LocalBoxCluster.ps1") -OutFile $LocalBoxPath\New-LocalBoxCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Configure-AKSWorkloadCluster.ps1") -OutFile $LocalBoxPath\Configure-AKSWorkloadCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Configure-VMLogicalNetwork.ps1") -OutFile $LocalBoxPath\Configure-VMLogicalNetwork.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Generate-ARM-Template.ps1") -OutFile $LocalBoxPath\Generate-ARM-Template.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/common.tests.ps1") -OutFile "$($LocalBoxConfig.Paths["TestsDir"])\common.tests.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/azlocal.tests.ps1") -OutFile "$($LocalBoxConfig.Paths["TestsDir"])\azlocal.tests.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/localbox-bginfo.bgi") -OutFile "$($LocalBoxConfig.Paths["TestsDir"])\localbox-bginfo.bgi"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/Invoke-Test.ps1") -OutFile "$($LocalBoxConfig.Paths["TestsDir"])\Invoke-Test.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile "$($LocalBoxConfig.Paths["LogsDir"])\LogInstructions.txt"
Invoke-WebRequest ($templateBaseUrl + "artifacts/jumpstart-user-secret.yaml") -OutFile $LocalBoxPath\jumpstart-user-secret.yaml
Invoke-WebRequest ($templateBaseUrl + "artifacts/azlocal.json") -OutFile $LocalBoxPath\azlocal.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/azlocal.parameters.json") -OutFile $LocalBoxPath\azlocal.parameters.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/dsc/packages.dsc.yml") -OutFile "$($LocalBoxConfig.Paths["DSCDir"])\packages.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/dsc/hyper-v.dsc.yml") -OutFile "$($LocalBoxConfig.Paths["DSCDir"])\hyper-v.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/WinGet.ps1") -OutFile "$LocalBoxPath\WinGet.ps1"

# Replace password and DNS placeholder
Write-Host "Updating config placeholders with injected values."
(Get-Content -Path $LocalBoxPath\LocalBox-Config.psd1) -replace '%staging-password%', $adminPassword | Set-Content -Path $LocalBoxPath\LocalBox-Config.psd1
(Get-Content -Path $LocalBoxPath\LocalBox-Config.psd1) -replace '%staging-natDNS%', $natDNS | Set-Content -Path $LocalBoxPath\LocalBox-Config.psd1

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Write-Host "Installing PowerShell modules..."

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
$modules = @("Az", "Az.ConnectedMachine", "Azure.Arc.Jumpstart.Common", "Microsoft.PowerShell.SecretManagement", "Pester")

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

Connect-AzAccount -Identity

$DeploymentProgressString = "Started bootstrap-script..."

$tags = Get-AzResourceGroup -Name $resourceGroup | Select-Object -ExpandProperty Tags

if ($null -ne $tags) {
    $tags["DeploymentProgress"] = $DeploymentProgressString
} else {
    $tags = @{"DeploymentProgress" = $DeploymentProgressString}
}

$null = Set-AzResourceGroup -ResourceGroupName $resourceGroup -Tag $tags

##############################################################
# Installing PowerShell 7
##############################################################

Write-Host "Installing PowerShell 7..."

$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

Copy-Item $PsHome\Profile.ps1 -Destination "C:\Program Files\PowerShell\7\"

# Disabling Windows Server Manager Scheduled Task
Write-Host "Disabling Windows Server Manager scheduled task."
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Disable Server Manager WAC prompt
Write-Host "Disabling Server Manager WAC prompt."
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\ServerManager"
$Name = "DoNotPopWACConsoleAtSMLaunch"
$Value = "1"
if (-not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Network Profile prompt
Write-Host "Disabling network profile prompt."
$RegistryPath = "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

# Configuring CredSSP and WinRM
Write-Host "Enabling CredSSP."
Enable-WSManCredSSP -Role Server -Force | Out-Null
Enable-WSManCredSSP -Role Client -DelegateComputer $Env:COMPUTERNAME -Force | Out-Null

$DeploymentProgressString = "Restarting and installing WinGet packages..."

$tags = Get-AzResourceGroup -Name $resourceGroup | Select-Object -ExpandProperty Tags

if ($null -ne $tags) {
    $tags["DeploymentProgress"] = $DeploymentProgressString
} else {
    $tags = @{"DeploymentProgress" = $DeploymentProgressString}
}

$null = Set-AzResourceGroup -ResourceGroupName $resourceGroup -Tag $tags

$ScheduledTaskExecutable = "pwsh.exe"

# Creating scheduled task for WinGet.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $LocalBoxPath\WinGet.ps1
Register-ScheduledTask -TaskName "WinGetLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Creating scheduled task for LocalBoxLogonScript.ps1
Write-Host "Creating scheduled task for LocalBoxLogonScript.ps1"
$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $LocalBoxPath\LocalBoxLogonScript.ps1
Register-ScheduledTask -TaskName "LocalBoxLogonScript"  -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disable Edge 'First Run' Setup
Write-Host "Configuring Microsoft Edge."
$edgePolicyRegistryPath = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
$firstRunRegistryName = 'HideFirstRunExperience'
$firstRunRegistryValue = '0x00000001'
$savePasswordRegistryName = 'PasswordManagerEnabled'
$savePasswordRegistryValue = '0x00000000'

if (-NOT (Test-Path -Path $edgePolicyRegistryPath)) {
  New-Item -Path $edgePolicyRegistryPath -Force | Out-Null
}

New-ItemProperty -Path $edgePolicyRegistryPath -Name $firstRunRegistryName -Value $firstRunRegistryValue -PropertyType DWORD -Force
New-ItemProperty -Path $edgePolicyRegistryPath -Name $savePasswordRegistryName -Value $savePasswordRegistryValue -PropertyType DWORD -Force

# Set Diagnostic Data settings

$telemetryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
$telemetryProperty = "AllowTelemetry"
$telemetryValue = 3

$oobePath = "HKLM:\Software\Policies\Microsoft\Windows\OOBE"
$oobeProperty = "DisablePrivacyExperience"
$oobeValue = 1

# Create the registry key and set the value for AllowTelemetry
if (-not (Test-Path $telemetryPath)) {
    New-Item -Path $telemetryPath -Force | Out-Null
}
Set-ItemProperty -Path $telemetryPath -Name $telemetryProperty -Value $telemetryValue

# Create the registry key and set the value for DisablePrivacyExperience
if (-not (Test-Path $oobePath)) {
    New-Item -Path $oobePath -Force | Out-Null
}
Set-ItemProperty -Path $oobePath -Name $oobeProperty -Value $oobeValue

Write-Host "Registry keys and values for Diagnostic Data settings have been set successfully."

# Change RDP Port
Write-Host "Updating RDP Port - RDP port number from configuration is $rdpPort"
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

# Workaround for https://github.com/microsoft/azure_arc/issues/3035

# Define firewall rule name
$ruleName = "Block RDP UDP 3389"

# Check if the rule already exists
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Firewall rule '$ruleName' already exists. No changes made."
} else {
    # Create a new firewall rule to block UDP traffic on port 3389
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort 3389 -Action Block -Enabled True
    Write-Host "Firewall rule '$ruleName' created successfully. RDP UDP is now blocked."
}

# Define the registry path
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"

# Define the registry key name
$registryName = "fClientDisableUDP"

# Define the value (1 = Disable Connect Time Detect and Continuous Network Detect)
$registryValue = 1

# Check if the registry path exists, if not, create it
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Set the registry key
Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -Type DWord

# Confirm the change
Write-Host "Registry setting applied successfully. fClientDisableUDP set to $registryValue"

# Install Hyper-V and reboot
Write-Header "Installing Hyper-V."
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

Write-Header "Configuring Windows Defender exclusions for Hyper-V."

Add-MpPreference -ExclusionExtension ".vhd"
Add-MpPreference -ExclusionExtension ".vhdx"
Add-MpPreference -ExclusionExtension ".avhd"
Add-MpPreference -ExclusionExtension ".avhdx"
Add-MpPreference -ExclusionExtension ".vhds"
Add-MpPreference -ExclusionExtension ".vhdpmem"
Add-MpPreference -ExclusionExtension ".iso"
Add-MpPreference -ExclusionExtension ".rct"
Add-MpPreference -ExclusionExtension ".mrt"
Add-MpPreference -ExclusionExtension ".vsv"
Add-MpPreference -ExclusionExtension ".bin"
Add-MpPreference -ExclusionExtension ".xml"
Add-MpPreference -ExclusionExtension ".vmcx"
Add-MpPreference -ExclusionExtension ".vmrs"
Add-MpPreference -ExclusionExtension ".vmgs"
Add-MpPreference -ExclusionPath "%ProgramData%\Microsoft\Windows\Hyper-V"
Add-MpPreference -ExclusionPath "%Public%\Documents\Hyper-V\Virtual Hard Disks"
Add-MpPreference -ExclusionPath "%SystemDrive%\ProgramData\Microsoft\Windows\Hyper-V\Snapshots"
Add-MpPreference -ExclusionPath "C:\LocalBox\VHD"
Add-MpPreference -ExclusionPath "V:\VMs"
Add-MpPreference -ExclusionProcess  "%systemroot%\System32\Vmms.exe"
Add-MpPreference -ExclusionProcess  "%systemroot%\System32\Vmwp.exe"
Add-MpPreference -ExclusionProcess  "%systemroot%\System32\Vmsp.exe"
Add-MpPreference -ExclusionProcess  "%systemroot%\System32\Vmcompute.exe"

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log."
Stop-Transcript
$logSuppress = Get-Content "$($LocalBoxConfig.Paths.LogsDir)\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "$($LocalBoxConfig.Paths.LogsDir)\Bootstrap.log" -Force
