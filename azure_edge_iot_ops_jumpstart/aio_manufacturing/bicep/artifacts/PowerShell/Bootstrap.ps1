param (
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnObjectId,
    [string]$subscriptionId,
    [string]$location,
    [string]$templateBaseUrl,
    [string]$resourceGroup,
    [string]$windowsNode,
    [string]$kubernetesDistribution,
    [string]$customLocationRPOID,
    [string]$githubAccount,
    [string]$githubBranch,
    [string]$adxClusterName,
    [string]$rdpPort
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientId', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnObjectId', $spnObjectId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('kubernetesDistribution', $kubernetesDistribution, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('windowsNode', $windowsNode, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('customLocationRPOID', $customLocationRPOID, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubAccount', $githubAccount, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adxClusterName', $adxClusterName, [System.EnvironmentVariableTarget]::Machine)

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
$ConfigurationDataFile = "C:\Temp\aioConfig.psd1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/aioConfig.psd1") -OutFile $ConfigurationDataFile

$aioConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile
$aioDirectory = $aioConfig.aioDirectories["aioDir"]
$aioToolsDir = $aioConfig.aioDirectories["aioToolsDir"]
$aioPowerShellDir = $aioConfig.aioDirectories["aioPowerShellDir"]
$aioDataExplorer = $aioConfig.aioDirectories["aioDataExplorer"]
$websiteUrls = $aioConfig.URLs
$mqttExplorerReleasesUrl = $websiteUrls["mqttExplorerReleases"]

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
# Creating aio paths
##############################################################
Write-Output "Creating aio paths"
foreach ($path in $aioConfig.aioDirectories.values) {
    Write-Output "Creating path $path"
    New-Item -ItemType Directory $path -Force
}

Start-Transcript -Path ($aioConfig.aioDirectories["aioLogsDir"] + "\Bootstrap.log")

$ErrorActionPreference = "SilentlyContinue"

##############################################################
# Get latest Grafana OSS release
##############################################################
$latestRelease = (Invoke-RestMethod -Uri $websiteUrls["grafana"]).tag_name.replace('v', '')

##############################################################
# Download artifacts
##############################################################
[System.Environment]::SetEnvironmentVariable('aioConfigPath', "$aioPowerShellDir\aioConfig.psd1", [System.EnvironmentVariableTarget]::Machine)
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/LogonScript.ps1") -OutFile "$aioPowerShellDir\LogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/aioConfig.psd1") -OutFile "$aioPowerShellDir\aioConfig.psd1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/mq_bridge_eventgrid.yml") -OutFile "$aioToolsDir\mq_bridge_eventgrid.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/mqtt_simulator.yml") -OutFile "$aioToolsDir\mqtt_simulator.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/mq_cloudConnector.yml") -OutFile "$aioToolsDir\mq_cloudConnector.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/influxdb.yml") -OutFile "$aioToolsDir\influxdb.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/influxdb_setup.yml") -OutFile "$aioToolsDir\influxdb_setup.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/influxdb-configmap.yml") -OutFile "$aioToolsDir\influxdb-configmap.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/influxdb-import-dashboard.yml") -OutFile "$aioToolsDir\influxdb-import-dashboard.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/mqtt_listener.yml") -OutFile "$aioToolsDir\mqtt_listener.yml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/mqtt_explorer_settings.json") -OutFile "$aioToolsDir\mqtt_explorer_settings.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/Settings/Bookmarks") -OutFile "$aioToolsDir\Bookmarks"
Invoke-WebRequest ($templateBaseUrl + "artifacts/adx_dashboard/dashboard.json") -OutFile "$aioDataExplorer\dashboard.json"

#Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "$aioDirectory\wallpaper.png"

Invoke-WebRequest "https://raw.githubusercontent.com/azure/arc_jumpstart_docs/canary/img/wallpaper/jumpstart_title_wallpaper_dark.png" -OutFile "$aioDirectory\wallpaper.png"

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
# Install Chocolatey packages
##############################################################
$maxRetries = 3
$retryDelay = 30  # seconds

$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        Write-Host "Installing Chocolatey packages"
        try {
            choco config get cacheLocation
        }
        catch {
            Write-Output "Chocolatey not detected, trying to install now"
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($aioConfig.URLs.chocoInstallScript))
        }

        Write-Host "Chocolatey packages specified"

        foreach ($app in $aioConfig.ChocolateyPackagesList) {
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

# Enable VirtualMachinePlatform feature, the vm reboot will be done in DSC extension
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HubsSidebarEnabled'
$Value = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HideFirstRunExperience'
$Value = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Creating scheduled task for LogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$aioPowerShellDir\LogonScript.ps1"
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content ($aioConfig.aioDirectories["aioLogsDir"] + "\Bootstrap.log") | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content ($aioConfig.aioDirectories["aioLogsDir"] + "\Bootstrap.log") -Force