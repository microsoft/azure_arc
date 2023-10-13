param (
    [string]$adminUsername,
    [securestring]$adminPassword,
    [string]$spnClientId,
    [securestring]$spnClientSecret,
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

# Creating HCIBox path
$HCIPath = "C:\HCIBox"
[System.Environment]::SetEnvironmentVariable('HCIBoxDir', $HCIPath,[System.EnvironmentVariableTarget]::Machine)
New-Item -Path $HCIPath -ItemType directory -Force

# Downloading configuration file
$ConfigurationDataFile = "$HCIPath\HCIBox-Config.psd1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBox-Config.psd1") -OutFile $ConfigurationDataFile

# Importing configuration data
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

## This section needs to be imported from data file, not hardcoded
Write-Output "Creating HCIBox paths"

$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

New-Item -Path $Env:HCIBoxDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxVHDDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxSDNDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxVMDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxIconDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxWACDir -ItemType directory -Force
New-Item -Path $Env:HCIBoxKVDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force

Start-Transcript -Path $Env:HCIBoxLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

# Installing tools
Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,dotnet-sdk,setdefaultbrowser,zoomit,azure-data-studio'

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

Write-Header "Install Azure CLI (64-bit not available via Chocolatey)"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

Write-Header "Downloading Azure Stack HCI configuration scripts"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/hcibox_wallpaper.png" -OutFile $Env:HCIBoxDir\wallpaper.png
Invoke-WebRequest https://aka.ms/wacdownload -OutFile $Env:HCIBoxWACDir\WindowsAdminCenter.msi
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBoxLogonScript.ps1") -OutFile $Env:HCIBoxDir\HCIBoxLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/New-HCIBoxCluster.ps1") -OutFile $Env:HCIBoxDir\New-HCIBoxCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Register-AzSHCI.ps1") -OutFile $Env:HCIBoxDir\Register-AzSHCI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-AKS.ps1") -OutFile $Env:HCIBoxDir\Deploy-AKS.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-SQLMI.ps1") -OutFile $Env:HCIBoxDir\Deploy-SQLMI.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Uninstall-AKS.ps1") -OutFile $Env:HCIBoxDir\Uninstall-AKS.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-ArcResourceBridge.ps1") -OutFile $Env:HCIBoxDir\Deploy-ArcResourceBridge.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Uninstall-ResourceBridge.ps1") -OutFile $Env:HCIBoxDir\Uninstall-ResourceBridge.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Deploy-GitOps.ps1") -OutFile $Env:HCIBoxDir\Deploy-GitOps.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/GetServiceAccountBearerToken.ps1") -OutFile $Env:HCIBoxDir\GetServiceAccountBearerToken.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/CertHelpers.ps1") -OutFile $Env:HCIBoxSDNDir\CertHelpers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/NetworkControllerRESTWrappers.ps1") -OutFile $Env:HCIBoxSDNDir\NetworkControllerRESTWrappers.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/NetworkControllerWorkloadHelpers.psm1") -OutFile $Env:HCIBoxSDNDir\NetworkControllerWorkloadHelpers.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExplorer.ps1") -OutFile $Env:HCIBoxSDNDir\SDNExplorer.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpress.ps1") -OutFile $Env:HCIBoxSDNDir\SDNExpress.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpressModule.psm1") -OutFile $Env:HCIBoxSDNDir\SDNExpressModule.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/SDNExpressUI.psm1") -OutFile $Env:HCIBoxSDNDir\SDNExpressUI.psm1
Invoke-WebRequest ($templateBaseUrl + "artifacts/SDN/Single-NC.psd1") -OutFile $Env:HCIBoxSDNDir\Single-NC.psd1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:HCIBoxLogsDir\LogInstructions.txt
Invoke-WebRequest ($templateBaseUrl + "artifacts/jumpstart-user-secret.yaml") -OutFile $Env:HCIBoxDir\jumpstart-user-secret.yaml

# Replace password and DNS placeholder
$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
(Get-Content -Path $Env:HCIBoxDir\HCIBox-Config.psd1) -replace '%staging-password%',$adminPassword | Set-Content -Path $Env:HCIBoxDir\HCIBox-Config.psd1
(Get-Content -Path $Env:HCIBoxDir\HCIBox-Config.psd1) -replace '%staging-natDNS%',$natDNS | Set-Content -Path $Env:HCIBoxDir\HCIBox-Config.psd1

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
Enable-WSManCredSSP -Role Server -Force | Out-Null
Enable-WSManCredSSP -Role Client -DelegateComputer $Env:COMPUTERNAME -Force | Out-Null

# Creating scheduled task for HCIBoxLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:HCIBoxDir\HCIBoxLogonScript.ps1
Register-ScheduledTask -TaskName "HCIBoxLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disable Edge 'First Run' Setup
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
Write-Host "RDP port number from configuration is $rdpPort"
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
Write-Header "Installing Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $Env:HCIBoxLogsDir\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $Env:HCIBoxLogsDir\Bootstrap.log -Force
