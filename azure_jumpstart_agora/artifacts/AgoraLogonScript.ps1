$Env:AgoraDir = "C:\Agora"
$Env:AgoraLogsDir = "C:\Agora\Logs"
$Env:AgoraVMDir = "$Env:AgoraDir\Virtual Machines"
$Env:AgoraIconDir = "C:\Agora\Icons"

Start-Transcript -Path $Env:AgoraLogsDir\AgoraLogonScript.log

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

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

<#

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

# Installing tools
Write-Header "Installing WinGet Apps"
$winGetAppList = 'azure-cli,kubectl,Microsoft.VCRedist.2015+.x64,Microsoft.Azure.AZCopy.10,Microsoft.VisualStudioCode,Git.Git,7zip,kubectx,Hashicorp.Terraform,PuTTY.PuTTY,Helm.Helm,Microsoft.DotNet.AspNetCore.3_1,ShiningLight.OpenSSL.Light,thomasnordquist.MQTT-Explorer'

Write-Host "Winget Apps Specified"

$appsToInstall = $winGetAppList -split "," | foreach { "$($_.Trim())" }

foreach ($app in $appsToInstall) {
    Write-Host "Installing $app"
    & winget install $app --force --silent --accept-source-agreements --accept-package-agreements | Write-Output

}

# Cleanup
Push-Location $HOME
Remove-Item $downloadDir -Recurse -Force
#>

$cliDir = New-Item -Path "$Env:AgoraDir\.cli\" -Name ".agora" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for azcopy
Write-Header "Az PowerShell Login"
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
az extension add --name arcdata --system
az -v

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksProdClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksDevClusterName --admin

kubectx aksProd = "$Env:aksProdClusterName-admin"
kubectx aksDev = "$Env:aksDevClusterName-admin"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "AgoraLogonScript" -Confirm:$false
Start-Sleep -Seconds 5


