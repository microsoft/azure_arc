param (
  [string]$adminUsername,
  [string]$adminPassword,
  [string]$spnClientId,
  [string]$spnClientSecret,
  [string]$spnObjectId,
  [string]$spnTenantId,
  [string]$spnAuthority,
  [string]$tenantId,
  [string]$subscriptionId,
  [string]$resourceGroup,
  [string]$azureLocation,
  [string]$stagingStorageAccountName,
  [string]$workspaceName,
  [string]$aksStagingClusterName,
  [string]$iotHubHostName,
  [string]$cosmosDBName,
  [string]$cosmosDBEndpoint,
  [string]$templateBaseUrl,
  [string]$rdpPort,
  [string]$githubAccount,
  [string]$githubBranch,
  [string]$githubPAT,
  [string]$githubUser,
  [string]$adxClusterName,
  [string]$namingGuid,
  [string]$scenario,
  [string]$customLocationRPOID,
  [string]$aioStorageAccountName,
  [string]$k3sArcClusterName,
  [string]$k3sArcDataClusterName,
  [string]$vmAutologon,
  [string]$openAIEndpoint,
  [string]$speachToTextEndpoint,
  [object]$azureOpenAIModel,
  [string]$openAIDeploymentName
)

##############################################################
# Inject ARM template parameters as environment variables
##############################################################
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnObjectID', $spnObjectId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksStagingClusterName', $aksStagingClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('iotHubHostName', $iotHubHostName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('cosmosDBName', $cosmosDBName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('cosmosDBEndpoint', $cosmosDBEndpoint, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubAccount', $githubAccount, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $githubPAT, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AgDir', "C:\Ag", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adxClusterName', $adxClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('namingGuid', $namingGuid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('scenario', $scenario, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('customLocationRPOID', $customLocationRPOID, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aioStorageAccountName', $aioStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcClusterName', $k3sArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcDataClusterName', $k3sArcDataClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('openAIEndpoint', $openAIEndpoint, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('speachToTextEndpoint', $speachToTextEndpoint, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureOpenAIModel', $azureOpenAIModel, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('openAIDeploymentName', $openAIDeploymentName, [System.EnvironmentVariableTarget]::Machine)

$ErrorActionPreference = 'Continue'

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

$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

if ($vmAutologon -eq "true") {

  Write-Host "Configuring VM Autologon"

  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" "1"
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUserName" $adminUsername
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" $adminPassword
  if($flavor -eq "DataOps"){
      Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultDomainName" "jumpstart.local"
  }
} else {

  Write-Host "Not configuring VM Autologon"

}

##############################################################
# Download configuration data file and declaring directories
##############################################################
$ConfigurationDataFile = "C:\Temp\AgConfig.psd1"

switch ($scenario) {
  "contoso_supermarket" { Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgConfig-contoso-supermarket.psd1") -OutFile $ConfigurationDataFile }
  "contoso_motors" {Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgConfig-contoso-motors.psd1") -OutFile $ConfigurationDataFile}
  "contoso_hypermarket" {Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgConfig-contoso-hypermarket.psd1") -OutFile $ConfigurationDataFile}
}

$AgConfig           = Import-PowerShellDataFile -Path $ConfigurationDataFile
$AgDirectory        = $AgConfig.AgDirectories["AgDir"]
$AgToolsDir         = $AgConfig.AgDirectories["AgToolsDir"]
$AgDeploymentFolder = $AgConfig.AgDirectories["AgL1Files"]
$AgIconsDir         = $AgConfig.AgDirectories["AgIconDir"]
$AgPowerShellDir    = $AgConfig.AgDirectories["AgPowerShellDir"]
$AgMonitoringDir    = $AgConfig.AgDirectories["AgMonitoringDir"]
$websiteUrls        = $AgConfig.URLs

function BITSRequest {
  Param(
    [Parameter(Mandatory = $True)]
    [hashtable]$Params
  )
  $url = $Params['Uri']
  $filename = $Params['Filename']
  $download = Start-BitsTransfer -Source $url -Destination $filename -Asynchronous
  $ProgressPreference = "Continue"
  while ($download.JobState -ne "Transferred") {
    if ($download.JobState -eq "TransientError") {
      Get-BitsTransfer $download.name | Resume-BitsTransfer -Asynchronous
    }
    [int] $dlProgress = ($download.BytesTransferred / $download.BytesTotal) * 100;
    Write-Progress -Activity "Downloading File $filename..." -Status "$dlProgress% Complete:" -PercentComplete $dlProgress;
  }
  Complete-BitsTransfer $download.JobId
  Write-Progress -Activity "Downloading File $filename..." -Status "Ready" -Completed
  $ProgressPreference = "SilentlyContinue"
}


##############################################################
# Extending C:\ partition to the maximum size
##############################################################
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

##############################################################
# Initialize and format the data disk
##############################################################
$disk = Get-Disk | Where-Object partitionstyle -eq 'raw' | sort number
$disk | Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $AgConfig.HostVMDrive |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "VMs" -Confirm:$false -Force

##############################################################
# Creating Ag paths
##############################################################
Write-Output "Creating Ag paths"
foreach ($path in $AgConfig.AgDirectories.values) {
  Write-Output "Creating path $path"
  New-Item -ItemType Directory $path -Force
}

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\Bootstrap.log")

$ErrorActionPreference = 'Continue'

##############################################################
# Testing connectivity to required URLs
##############################################################

Function Test-Url($url, $maxRetries = 3, $retryDelaySeconds = 5) {
  $retryCount = 0
  do {
      try {
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        $statusCode = $response.StatusCode

        if ($statusCode -eq 200) {
          Write-Host "$url is reachable."
          break  # Break out of the loop if website is reachable
        }
        else {
          Write-Host "$url is unreachable. Status code: $statusCode"
        }
      }
      catch {
        Write-Host "An error occurred while testing the website: $url - $_"
      }

      $retryCount++
      if ($retryCount -le $maxRetries) {
        Write-Host "Retrying in $retryDelaySeconds seconds..."
        Start-Sleep -Seconds $retryDelaySeconds
      }
    } while ($retryCount -le $maxRetries)

    if ($retryCount -gt $maxRetries) {
      Write-Host "Exceeded maximum number of retries. Exiting..."
      exit 1  # Stop script execution if maximum retries reached
    }
  }

foreach ($url in $websiteUrls.Values) {
  $maxRetries = 3
  $retryDelaySeconds = 5

  Test-Url $url -maxRetries $maxRetries -retryDelaySeconds $retryDelaySeconds
}


##############################################################
# Copy PowerShell Profile and Reload
##############################################################
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile "$AgPowerShellDir\Profile.ps1"
.$PsHome\Profile.ps1

##############################################################
# Installing PowerShell 7
##############################################################
$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

Copy-Item $PsHome\Profile.ps1 -Destination "C:\Program Files\PowerShell\7\"

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
$modules = @("Az", "Az.ConnectedMachine", "Az.ConnectedKubernetes", "Az.CustomLocation", "Azure.Arc.Jumpstart.Common", "Microsoft.PowerShell.SecretManagement", "Pester")

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

##############################################################
# Get latest Grafana OSS release
##############################################################
$latestRelease = (Invoke-RestMethod -Uri $websiteUrls["grafana"]).tag_name.replace('v', '')

##############################################################
# Download artifacts
##############################################################
[System.Environment]::SetEnvironmentVariable('AgConfigPath', "$AgPowerShellDir\AgConfig.psd1", [System.EnvironmentVariableTarget]::Machine)
Copy-Item $ConfigurationDataFile "$AgPowerShellDir\AgConfig.psd1" -Force

Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgLogonScript.ps1") -OutFile "$AgPowerShellDir\AgLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Modules/common.psm1") -OutFile "$AgPowerShellDir\common.psm1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Modules/contoso_supermarket.psm1") -OutFile "$AgPowerShellDir\contoso_supermarket.psm1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Modules/contoso_motors.psm1") -OutFile "$AgPowerShellDir\contoso_motors.psm1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Modules/contoso_hypermarket.psm1") -OutFile "$AgPowerShellDir\contoso_hypermarket.psm1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/DockerDesktopSettings.json") -OutFile "$AgToolsDir\settings.json"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/agora_wallpaper_dark.png" -OutFile $AgDirectory\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-node-exporter-full.json") -OutFile "$AgMonitoringDir\grafana-node-exporter-full.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-cluster-global.json") -OutFile "$AgMonitoringDir\grafana-cluster-global.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/arc-inventory-workbook.bicep") -OutFile "$AgMonitoringDir\arc-inventory-workbook.bicep"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/arc-osperformance-workbook.bicep") -OutFile "$AgMonitoringDir\arc-osperformance-workbook.bicep"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/prometheus-additional-scrape-config.yaml") -OutFile "$AgMonitoringDir\prometheus-additional-scrape-config.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/grafana.ico") -OutFile $AgIconsDir\grafana.ico
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso.png") -OutFile $AgIconsDir\contoso.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso.svg") -OutFile $AgIconsDir\contoso.svg
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso-motors.png") -OutFile $AgIconsDir\contoso-motors.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso-motors.svg") -OutFile $AgIconsDir\contoso-motors.svg
Invoke-WebRequest ($templateBaseUrl + "artifacts/L1Files/config.json") -OutFile $AgDeploymentFolder\config.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Winget.ps1") -OutFile "$AgPowerShellDir\Winget.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/common.tests.ps1") -OutFile "$AgDirectory\tests\common.tests.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/k8s.tests.ps1") -OutFile "$AgDirectory\tests\k8s.tests.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/Invoke-Test.ps1") -OutFile "$AgDirectory\tests\Invoke-Test.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/tests/ag-bginfo.bgi") -OutFile "$AgDirectory\tests\ag-bginfo.bgi"

if($scenario -eq "contoso_supermarket"){
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/Bookmarks-contoso-supermarket") -OutFile "$AgToolsDir\Bookmarks"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-freezer-monitoring.json") -OutFile "$AgMonitoringDir\grafana-freezer-monitoring.json"
}
elseif ($scenario -eq "contoso_motors") {
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/Bookmarks-contoso-motors") -OutFile "$AgToolsDir\Bookmarks"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mq_cloudConnector.yml") -OutFile "$AgToolsDir\mq_cloudConnector.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mqtt_explorer_settings_motors.json") -OutFile "$AgToolsDir\mqtt_explorer_settings.json"
}
elseif ($scenario -eq "contoso_hypermarket") {
  Invoke-WebRequest ($templateBaseUrl + "artifacts/kubernetes/K3s/longhorn.yaml") -OutFile "$AgToolsDir\longhorn.yaml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/kubernetes/K3s/kubeVipRbac.yml") -OutFile "$AgToolsDir\kubeVipRbac.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/kubernetes/K3s/kubeVipDaemon.yml") -OutFile "$AgToolsDir\kubeVipDaemon.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/Bookmarks-contoso-hypermarket") -OutFile "$AgToolsDir\Bookmarks"
  #Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mq_cloudConnector.yml") -OutFile "$AgToolsDir\mq_cloudConnector.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mqtt_explorer_settings_hypermarket.json") -OutFile "$AgToolsDir\mqtt_explorer_settings.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-app-workloads.json") -OutFile "$AgMonitoringDir\grafana-app-workloads.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-app-pods.json") -OutFile "$AgMonitoringDir\grafana-app-pods.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-node-exporter-full-v2.json") -OutFile "$AgMonitoringDir\grafana-node-exporter-full-v2.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-app-store-asset.json") -OutFile "$AgMonitoringDir\grafana-app-store-asset.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-app-store-shoppers.json") -OutFile "$AgMonitoringDir\grafana-app-store-shoppers.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-app-store-pos.json") -OutFile "$AgMonitoringDir\grafana-app-store-pos.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso-hypermarket.png") -OutFile $AgIconsDir\contoso-hypermarket.png
  Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso-hypermarket.svg") -OutFile $AgIconsDir\contoso-hypermarket.svg
}


BITSRequest -Params @{'Uri' = 'https://aka.ms/wslubuntu'; 'Filename' = "$AgToolsDir\Ubuntu.appx" }
BITSRequest -Params @{'Uri' = $websiteUrls["wslStoreStorage"]; 'Filename' = "$AgToolsDir\wsl_update_x64.msi" }
BITSRequest -Params @{'Uri' = $websiteUrls["docker"]; 'Filename' = "$AgToolsDir\DockerDesktopInstaller.exe" }
BITSRequest -Params @{'Uri' = "https://dl.grafana.com/oss/release/grafana-$latestRelease.windows-amd64.msi"; 'Filename' = "$AgToolsDir\grafana-$latestRelease.windows-amd64.msi" }


##############################################################
# Create Docker Desktop group
##############################################################
New-LocalGroup -Name "docker-users" -Description "docker Users Group"
Add-LocalGroupMember -Group "docker-users" -Member $adminUsername

##############################################################
# Disable Network Profile prompt
##############################################################
$RegistryPath = "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

##############################################################
# Updating Microsoft Edge startup settings
##############################################################
# Disable Microsoft Edge sidebar
$Name = 'HubsSidebarEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueFalse -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$Name = 'HideFirstRunExperience'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueTrue -PropertyType DWORD -Force

# Disable Microsoft Edge "Personalize your web experience" prompt
$Name = 'PersonalizationReportingEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueFalse -PropertyType DWORD -Force

# Show Favorites Bar in Microsoft Edge
$Name = 'FavoritesBarEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueTrue -PropertyType DWORD -Force

##############################################################
# Installing Posh-SSH PowerShell Module
##############################################################
Install-Module -Name Posh-SSH -Force

$ScheduledTaskExecutable = "C:\Program Files\PowerShell\7\pwsh.exe"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "${ScheduledTaskExecutable}" -Argument $AgPowerShellDir\WinGet.ps1
Register-ScheduledTask -TaskName "WinGetLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

$Action = New-ScheduledTaskAction -Execute "${ScheduledTaskExecutable}" -Argument "$AgPowerShellDir\AgLogonScript.ps1"
Register-ScheduledTask -TaskName "AgLogonScript" -User $adminUsername -Action $Action -RunLevel "Highest" -Force

##############################################################
# Disabling Windows Server Manager Scheduled Task
##############################################################
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

##############################################################
# Install Hyper-V, WSL and reboot
##############################################################
if($scenario -eq "contoso_supermarket" -or $scenario -eq "contoso_motors"){
  Write-Header "Installing Hyper-V"
  Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
  Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
  Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart
}else{
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
}

# Restart machine to initiate VM autologon
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-Command "Restart-Computer -Force"'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10))
$taskName = "Restart-Computer-Delayed"

# Define the restart action and schedule it to run after 10 seconds
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-Command "Restart-Computer -Force"'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10))

# Configure the task to run with highest privileges and use the current user's credentials
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Principal $principal -Description "Restart computer after script exits"


Stop-Transcript

##############################################################
# Clean up Bootstrap.log
##############################################################
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content "$AgDirectory\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "$AgDirectory\Bootstrap.log" -Force
