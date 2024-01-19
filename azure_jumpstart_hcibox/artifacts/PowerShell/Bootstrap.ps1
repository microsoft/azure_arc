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
    [string]$rdpPort
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnProviderId', $spnProviderId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', $deployAKSHCI,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployResourceBridge', $deployResourceBridge,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registerCluster', $registerCluster,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('natDNS', $natDNS,[System.EnvironmentVariableTarget]::Machine)

#######################################################################
## Setup basic environment
#######################################################################
# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Creating HCIBox path
$HCIPath = "C:\HCIBox"
[System.Environment]::SetEnvironmentVariable('HCIBoxDir', $HCIPath,[System.EnvironmentVariableTarget]::Machine)
New-Item -Path $HCIPath -ItemType directory -Force

# Downloading configuration file
$ConfigurationDataFile = "$HCIPath\HCIBox-Config.psd1"
[System.Environment]::SetEnvironmentVariable('HCIBoxConfigFile', $ConfigurationDataFile,[System.EnvironmentVariableTarget]::Machine)
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBox-Config.psd1") -OutFile $ConfigurationDataFile

# Importing configuration data
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Create paths
foreach ($path in $HCIBoxConfig.Paths.GetEnumerator()) {
    Write-Output "Creating path $($path.Value)"
    New-Item -Path $path.Value -ItemType directory -Force | Out-Null
}

# Begin transcript
Start-Transcript -Path "$($HCIBoxConfig.Paths["LogsDir"])\Bootstrap.log"

#################################################################################
## Setup host infrastructure and apps
#################################################################################
# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing Posh-SSH PowerShell Module
# Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Installing tools
Write-Header "Installing Chocolatey Apps"
try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

foreach ($app in $HCIBoxConfig.ChocolateyPackagesList)
{
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
}

Write-Header "Install Azure CLI (64-bit not available via Chocolatey)"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

Write-Host "Downloading Azure Stack HCI configuration scripts"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/hcibox_wallpaper.png" -OutFile $HCIPath\wallpaper.png
Invoke-WebRequest https://aka.ms/wacdownload -OutFile "$($HCIBoxConfig.Paths["WACDir"])\WindowsAdminCenter.msi"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBoxLogonScript.ps1") -OutFile $HCIPath\HCIBoxLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/New-HCIBoxCluster.ps1") -OutFile $HCIPath\New-HCIBoxCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Register-AzSHCI.ps1") -OutFile $HCIPath\Register-AzSHCI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Configure-AKS.ps1") -OutFile $HCIPath\Deploy-AKS.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-SQLMI.ps1") -OutFile $HCIPath\Deploy-SQLMI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Uninstall-AKS.ps1") -OutFile $HCIPath\Uninstall-AKS.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-ArcResourceBridge.ps1") -OutFile $HCIPath\Deploy-ArcResourceBridge.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Uninstall-ResourceBridge.ps1") -OutFile $HCIPath\Uninstall-ResourceBridge.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-GitOps.ps1") -OutFile $HCIPath\Deploy-GitOps.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Cloud-Cluster-Deploy.ps1") -OutFile $HCIPath\Cloud-Cluster-Deploy.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/GetServiceAccountBearerToken.ps1") -OutFile $HCIPath\GetServiceAccountBearerToken.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $HCIBoxConfig.Paths["LogsDir"]\LogInstructions.txt
Invoke-WebRequest ($templateBaseUrl + "artifacts/jumpstart-user-secret.yaml") -OutFile $HCIPath\jumpstart-user-secret.yaml
Invoke-WebRequest ($templateBaseUrl + "artifacts/hci.json") -OutFile $HCIPath\hci.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/hci.parameters.json") -OutFile $HCIPath\hci.parameters.json

# Replace password and DNS placeholder
Write-Host "Updating config placeholders with injected values."
$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
(Get-Content -Path $HCIPath\HCIBox-Config.psd1) -replace '%staging-password%',$adminPassword | Set-Content -Path $HCIPath\HCIBox-Config.psd1
(Get-Content -Path $HCIPath\HCIBox-Config.psd1) -replace '%staging-natDNS%',$natDNS | Set-Content -Path $HCIPath\HCIBox-Config.psd1

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

# Creating scheduled task for HCIBoxLogonScript.ps1
Write-Host "Creating scheduled task for HCIBoxLogonScript.ps1"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $HCIPath\HCIBoxLogonScript.ps1
Register-ScheduledTask -TaskName "HCIBoxLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disable Edge 'First Run' Setup
Write-Host "Configuring Microsoft Edge."
$edgePolicyRegistryPath  = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
$desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
$firstRunRegistryName  = 'HideFirstRunExperience'
$firstRunRegistryValue = '0x00000001'
$savePasswordRegistryName = 'PasswordManagerEnabled'
$savePasswordRegistryValue = '0x00000000'
$autoArrangeRegistryName = 'FFlags'
$autoArrangeRegistryValue = '1075839525'

if (-NOT (Test-Path -Path $edgePolicyRegistryPath)) {
    New-Item -Path $edgePolicyRegistryPath -Force | Out-Null
}

New-ItemProperty -Path $edgePolicyRegistryPath -Name $firstRunRegistryName -Value $firstRunRegistryValue -PropertyType DWORD -Force
New-ItemProperty -Path $edgePolicyRegistryPath -Name $savePasswordRegistryName -Value $savePasswordRegistryValue -PropertyType DWORD -Force
Set-ItemProperty -Path $desktopSettingsRegistryPath -Name $autoArrangeRegistryName -Value $autoArrangeRegistryValue -Force

# Change RDP Port
Write-Host "Updating RDP Port - RDP port number from configuration is $rdpPort"
if (($rdpPort -ne $null) -and ($rdpPort -ne "") -and ($rdpPort -ne "3389"))
{
    Write-Host "Configuring RDP port number to $rdpPort"
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0

    # RDP port
    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host "Current RDP PortNumber: $portNumber"
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

    Write-Host "RDP port configuration complete."
}

# Install Hyper-V and reboot
Write-Header "Installing Hyper-V."
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log."
Stop-Transcript
$logSuppress = Get-Content $($HCIBoxConfig.Paths["LogsDir"])\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $($HCIBoxConfig.Paths["LogsDir"])\Bootstrap.log -Force
