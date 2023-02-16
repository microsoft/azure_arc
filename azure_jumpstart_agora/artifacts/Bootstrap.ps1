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
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AgoraDir', "C:\Agora", [System.EnvironmentVariableTarget]::Machine)


# Creating Agora path
Write-Output "Creating Agora path"
$Env:AgoraDir = "C:\Agora"
$Env:AgoraLogsDir = "$Env:AgoraDir\Logs"
$Env:AgoraVMDir = "$Env:AgoraDir\Virtual Machines"
$Env:AgoraKVDir = "$Env:AgoraDir\KeyVault"
$Env:AgoraGitOpsDir = "$Env:AgoraDir\GitOps"
$Env:AgoraIconDir = "$Env:AgoraDir\Icons"
$Env:agentScript = "$Env:AgoraDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:AgoraRetailDir = "$Env:AgoraDir\Retail"

New-Item -Path $Env:AgoraDir -ItemType directory -Force
New-Item -Path $Env:AgoraLogsDir -ItemType directory -Force
New-Item -Path $Env:AgoraVMDir -ItemType directory -Force
New-Item -Path $Env:AgoraKVDir -ItemType directory -Force
New-Item -Path $Env:AgoraGitOpsDir -ItemType directory -Force
New-Item -Path $Env:AgoraIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force
New-Item -Path $Env:AgoraRetailDir -ItemType directory -Force

Start-Transcript -Path $Env:AgoraLogsDir\Bootstrap.log

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

# Install Windows Terminal
Write-Header "Installing Windows Terminal"
If ($PSVersionTable.PSVersion.Major -ge 7){ Write-Error "This script needs be run by version of PowerShell prior to 7.0" }

# Define environment variables
$downloadDir = "C:\WinTerminal"
$gitRepo = "microsoft/terminal"
$filenamePattern = "*.msixbundle"
$framworkPkgUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$framworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$msiPath = "$downloadDir\Microsoft.WindowsTerminal.msixbundle"
$releasesUri = "https://api.github.com/repos/$gitRepo/releases/latest"
$downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -SkipLast 1

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release msixbundle
Invoke-WebRequest -Uri $framworkPkgUrl -OutFile ( New-Item -Path $framworkPkgPath -Force )
Invoke-WebRequest -Uri $downloadUri -OutFile ( New-Item -Path $msiPath -Force )

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Add-AppxPackage -Path $framworkPkgPath
Add-AppxPackage -Path $msiPath

# Cleanup
Remove-Item $downloadDir -Recurse -Force

# Install Winget
Write-Header "Installing Winget"

If ($PSVersionTable.PSVersion.Major -ge 7){ Write-Error "This script needs be run by version of PowerShell prior to 7.0" }

# Define environment variables
$downloadDir = "C:\WinGet"
$gitRepo = "microsoft/winget-cli"
$msiFilenamePattern = "*.msixbundle"
$licenseFilenamePattern = "*.xml"
$releasesUri = "https://api.github.com/repos/$gitRepo/releases/latest"

# Preparing working directory
New-Item -Path $downloadDir -ItemType Directory
Push-Location $downloadDir

# Downloaing artifacts
function Install-Package {
    param (
        [string]$PackageFamilyName
    )

    Write-Host "Querying latest $PackageFamilyName version and its dependencies..."
    $response = Invoke-WebRequest `
        -Uri "https://store.rg-adguard.net/api/GetFiles" `
        -Method "POST" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "type=PackageFamilyName&url=$PackageFamilyName&ring=RP&lang=en-US" -UseBasicParsing

    Write-Host "Parsing response..."
    $regex = '<td><a href=\"([^\"]*)\"[^\>]*\>([^\<]*)<\/a>'
    $packages = (Select-String $regex -InputObject $response -AllMatches).Matches.Groups

    $result = $true
    for ($i = $packages.Count - 1; $i -ge 0; $i -= 3) {
        $url = $packages[$i - 1].Value;
        $name = $packages[$i].Value;
        $extCheck = @(".appx", ".appxbundle", ".msix", ".msixbundle") | % { $x = $false } { $x = $x -or $name.EndsWith($_) } { $x }
        $archCheck = @("x64", "neutral") | % { $x = $false } { $x = $x -or $name.Contains("_$($_)_") } { $x }

        if ($extCheck -and $archCheck) {
            # Skip if package already exists on system
            $currentPackageFamilyName = (Select-String "^[^_]+" -InputObject $name).Matches.Value
            $installedVersion = (Get-AppxPackage "$currentPackageFamilyName*").Version
            $latestVersion = (Select-String "_(\d+\.\d+.\d+.\d+)_" -InputObject $name).Matches.Value
            if ($installedVersion -and ($installedVersion -ge $latestVersion)) {
                Write-Host "${currentPackageFamilyName} is already installed, skipping..." -ForegroundColor "Yellow"
                continue
            }

            try {
                Write-Host "Downloading package: $name"
                $tempPath = "$(Get-Location)\$name"
                Invoke-WebRequest -Uri $url -Method Get -OutFile $tempPath
                Add-AppxPackage -Path $tempPath
                Write-Host "Successfully installed:" $name
            } catch {
                $result = $false
            }
        }
    }

    return $result
}

Write-Host "`n"

function Install-Package-With-Retry {
    param (
        [string]$PackageFamilyName,
        [int]$RetryCount
    )

    for ($t = 0; $t -le $RetryCount; $t++) {
        Write-Host "Attempt $($t + 1) out of $RetryCount..." -ForegroundColor "Cyan"
        if (Install-Package $PackageFamilyName) {
            return $true
        }
    }

    return $false
}

$licenseDownloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $licenseFilenamePattern ).browser_download_url
$licenseFilename = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $licenseFilenamePattern ).name
$licenseJoinPath = Join-Path -Path $downloadDir -ChildPath $licenseFilename
Invoke-WebRequest -Uri $licenseDownloadUri -OutFile ( New-Item -Path $licenseJoinPath -Force )

$result = @("Microsoft.DesktopAppInstaller_8wekyb3d8bbwe") | ForEach-Object { $x = $true } { $x = $x -and (Install-Package-With-Retry $_ 3) } { $x }

$msiFilename = ((Get-ChildItem -Path $downloadDir) | Where-Object name -like $msiFilenamePattern ).name
$msiJoinPath = Join-Path -Path $downloadDir -ChildPath $msiFilename

# Installing winget
Add-ProvisionedAppPackage -Online -PackagePath $msiJoinPath -LicensePath $licenseJoinPath -Verbose

Write-Host "`n"

# Test if winget has been successfully installed
if ($result -and (Test-Path -Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe")) {
    Write-Host "Congratulations! Windows Package Manager (winget) $(winget --version) installed successfully" -ForegroundColor "Green"
} else {
    Write-Host "Oops... Failed to install Windows Package Manager (winget)" -ForegroundColor "Red"
}

# Cleanup
Push-Location $HOME
Remove-Item $downloadDir -Recurse -Force


Stop-Transcript