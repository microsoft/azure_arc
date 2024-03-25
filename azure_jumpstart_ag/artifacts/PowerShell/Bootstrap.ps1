param (
  [string]$adminUsername,
  [string]$adminPassword,
  [string]$spnClientId,
  [string]$spnClientSecret,
  [string]$spnObjectId,
  [string]$spnTenantId,
  [string]$spnAuthority,
  [string]$subscriptionId,
  [string]$resourceGroup,
  [string]$azureLocation,
  [string]$stagingStorageAccountName,
  [string]$workspaceName,
  [string]$aksStagingClusterName,
  [string]$iotHubHostName,
  [string]$acrName,
  [string]$cosmosDBName,
  [string]$cosmosDBEndpoint,
  [string]$githubUser,
  [string]$templateBaseUrl,
  [string]$rdpPort,
  [string]$githubAccount,
  [string]$githubBranch,
  [string]$githubPAT,
  [string]$adxClusterName,
  [string]$namingGuid,
  [string]$industry,
  [string]$customLocationRPOID,
  [string]$aioStorageAccountName,
  [string]$stcontainerName
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
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksStagingClusterName', $aksStagingClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('iotHubHostName', $iotHubHostName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('acrName', $acrName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('cosmosDBName', $cosmosDBName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('cosmosDBEndpoint', $cosmosDBEndpoint, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubAccount', $githubAccount, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $githubPAT, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AgDir', "C:\Ag", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adxClusterName', $adxClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('namingGuid', $namingGuid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('industry', $industry, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('customLocationRPOID', $customLocationRPOID, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aioStorageAccountName', $aioStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stcontainerName', $stcontainerName, [System.EnvironmentVariableTarget]::Machine)

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


##############################################################
# Download configuration data file and declaring directories
##############################################################
$ConfigurationDataFile = "C:\Temp\AgConfig.psd1"

switch ($industry) {
  "retail" { Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgConfig-retail.psd1") -OutFile $ConfigurationDataFile }
  "manufacturing" {Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/AgConfig-manufacturing.psd1") -OutFile $ConfigurationDataFile}
}

$AgConfig         = Import-PowerShellDataFile -Path $ConfigurationDataFile
$AgDirectory      = $AgConfig.AgDirectories["AgDir"]
$AgToolsDir       = $AgConfig.AgDirectories["AgToolsDir"]
$AgIconsDir       = $AgConfig.AgDirectories["AgIconDir"]
$AgPowerShellDir  = $AgConfig.AgDirectories["AgPowerShellDir"]
$AgMonitoringDir  = $AgConfig.AgDirectories["AgMonitoringDir"]
$websiteUrls      = $AgConfig.URLs

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
.$PsHome\Profile.ps1

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
Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/DockerDesktopSettings.json") -OutFile "$AgToolsDir\settings.json"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/agora_wallpaper_dark.png" -OutFile $AgDirectory\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-node-exporter-full.json") -OutFile "$AgMonitoringDir\grafana-node-exporter-full.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-cluster-global.json") -OutFile "$AgMonitoringDir\grafana-cluster-global.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/prometheus-additional-scrape-config.yaml") -OutFile "$AgMonitoringDir\prometheus-additional-scrape-config.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/grafana.ico") -OutFile $AgIconsDir\grafana.ico
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso.png") -OutFile $AgIconsDir\contoso.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/contoso.svg") -OutFile $AgIconsDir\contoso.svg

if($industry -eq "retail"){
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/Bookmarks-retail") -OutFile "$AgToolsDir\Bookmarks"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/monitoring/grafana-freezer-monitoring.json") -OutFile "$AgMonitoringDir\grafana-freezer-monitoring.json"
}
elseif ($industry -eq "manufacturing") {
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/Bookmarks-manufacturing") -OutFile "$AgToolsDir\Bookmarks"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mq_cloudConnector.yml") -OutFile "$AgToolsDir\mq_cloudConnector.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/mqtt_explorer_settings.json") -OutFile "$AgToolsDir\mqtt_explorer_settings.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/influxdb-setup.yml") -OutFile "$AgToolsDir\influxdb-setup.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/influxdb-configmap.yml") -OutFile "$AgToolsDir\influxdb-configmap.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/influxdb-import-dashboard.yml") -OutFile "$AgToolsDir\influxdb-import-dashboard.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/influxdb.yml") -OutFile "$AgToolsDir\influxdb.yml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/ESA/config.json") -OutFile "$AgToolsDir\config.json"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/ESA/pv.yaml") -OutFile "$AgToolsDir\pv.yaml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/ESA/pvc.yaml") -OutFile "$AgToolsDir\pvc.yaml"
  Invoke-WebRequest ($templateBaseUrl + "artifacts/settings/ESA/configPod.yaml") -OutFile "$AgToolsDir\configPod.yaml"
}

BITSRequest -Params @{'Uri' = 'https://aka.ms/wslubuntu'; 'Filename' = "$AgToolsDir\Ubuntu.appx" }
BITSRequest -Params @{'Uri' = $websiteUrls["wslStoreStorage"]; 'Filename' = "$AgToolsDir\wsl_update_x64.msi" }
BITSRequest -Params @{'Uri' = $websiteUrls["docker"]; 'Filename' = "$AgToolsDir\DockerDesktopInstaller.exe" }
BITSRequest -Params @{'Uri' = "https://dl.grafana.com/oss/release/grafana-$latestRelease.windows-amd64.msi"; 'Filename' = "$AgToolsDir\grafana-$latestRelease.windows-amd64.msi" }

##############################################################
# Install Chocolatey packages
##############################################################
$maxRetries = 3
$retryDelay = 30  # seconds

$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
  try {
    Write-Header "Installing Chocolatey packages"
    try {
      choco config get cacheLocation
    }
    catch {
      Write-Output "Chocolatey not detected, trying to install now"
      Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($AgConfig.URLs.chocoInstallScript))
    }

    Write-Host "Chocolatey packages specified"

    foreach ($app in $AgConfig.ChocolateyPackagesList) {
      Write-Host "Installing $app"
      & choco install $app /y -Force | Write-Output
    }

    # If the command succeeds, set $success to $true to exit the loop
    $success = $true
  }
  catch {
    # If an exception occurs, increment the retry count
    $retryCount++

    # If the maximum number of retries is not reached yet, display an error message
    if ($retryCount -lt $maxRetries) {
      Write-Host "Attempt $retryCount failed. Retrying in $retryDelay seconds..."
      Start-Sleep -Seconds $retryDelay
    }
    else {
      Write-Host "All attempts failed. Exiting..."
      exit 1  # Stop script execution if maximum retries reached
    }
  }
}

##############################################################
# Install Azure CLI (64-bit not available via Chocolatey)
##############################################################
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

##############################################################
# Create Docker Desktop group
##############################################################
New-LocalGroup -Name "docker-users" -Description "docker Users Group"
Add-LocalGroupMember -Group "docker-users" -Member $adminUsername

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

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
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$AgPowerShellDir\AgLogonScript.ps1"
Register-ScheduledTask -TaskName "AgLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

##############################################################
# Disabling Windows Server Manager Scheduled Task
##############################################################
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

##############################################################
# Install Hyper-V, WSL and reboot
##############################################################
Write-Header "Installing Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

Stop-Transcript

##############################################################
# Clean up Bootstrap.log
##############################################################
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content "$AgDirectory\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "$AgDirectory\Bootstrap.log" -Force
