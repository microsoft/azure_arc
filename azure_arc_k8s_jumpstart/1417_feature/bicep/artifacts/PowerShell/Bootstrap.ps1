param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$location,
    [string]$templateBaseUrl,
    [string]$resourceGroup,
    [string]$windowsNode,
    [string]$kubernetesDistribution
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientId', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('kubernetesDistribution', $kubernetesDistribution, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('windowsNode', $windowsNode, [System.EnvironmentVariableTarget]::Machine)


##############################################################
# Download configuration data file and declaring directories
##############################################################
$ConfigurationDataFile = "C:\Temp\Ft1Config.psd1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Ft1Config.psd1") -OutFile $ConfigurationDataFile

$Ft1Config = Import-PowerShellDataFile -Path $ConfigurationDataFile
$Ft1Directory = $Ft1Config.Ft1Directories["Ft1Dir"]
$Ft1ToolsDir = $Ft1Config.Ft1Directories["Ft1ToolsDir"]
$websiteUrls = $Ft1Config.URLs

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
# Creating Ft1 paths
##############################################################
Write-Output "Creating Ft1 paths"
foreach ($path in $Ft1Config.Ft1Directories.values) {
    Write-Output "Creating path $path"
    New-Item -ItemType Directory $path -Force
}

Start-Transcript -Path ($Ft1Config.Ft1Directories["Ft1LogsDir"] + "\Bootstrap.log")

$ErrorActionPreference = "SilentlyContinue"

##############################################################
# Get latest Grafana OSS release
##############################################################
$latestRelease = (Invoke-RestMethod -Uri $websiteUrls["grafana"]).tag_name.replace('v', '')

##############################################################
# Download artifacts
##############################################################
[System.Environment]::SetEnvironmentVariable('Ft1ConfigPath', "$Ft1Directory\Ft1Config.psd1", [System.EnvironmentVariableTarget]::Machine)
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/LogonScript.ps1") -OutFile "$Ft1Directory\PowerShell\LogonScript.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "$Ft1Directory\wallpaper.png"

BITSRequest -Params @{'Uri' = "https://dl.grafana.com/oss/release/grafana-$latestRelease.windows-amd64.msi"; 'Filename' = "$Ft1ToolsDir\grafana-$latestRelease.windows-amd64.msi" }

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
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($Ft1Config.URLs.chocoInstallScript))
        }

        Write-Host "Chocolatey packages specified"

        foreach ($app in $Ft1Config.ChocolateyPackagesList) {
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
            write-Host "Failed app: $app"
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
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Ft1Directory\PowerShell\LogonScript.ps1"
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content ($Ft1Config.Ft1Directories["Ft1LogsDir"] + "\Bootstrap.log") | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content ($Ft1Config.Ft1Directories["Ft1LogsDir"] + "\Bootstrap.log") -Force