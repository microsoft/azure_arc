# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$AgConfig            = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgToolsDir          = $AgConfig.AgDirectories["AgToolsDir"]
$AgIconsDir          = $AgConfig.AgDirectories["AgIconDir"]
$websiteUrls         = $AgConfig.URLs
$githubAccount       = $Env:githubAccount
$githubBranch        = $Env:githubBranch
$githubUser          = $Env:githubUser
$resourceGroup       = $Env:resourceGroup
$subscription        = $Env:subscriptionId
$azureLocation       = $Env:azureLocation
$spnClientId         = $Env:spnClientId
$spnClientSecret     = $Env:spnClientSecret
$spnTenantId         = $Env:spnTenantId
$adminUsername       = $Env:adminUsername
$customLocationRPOID = $Env:customLocationRPOID
$acrName             = $Env:acrName.ToLower()
$templateBaseUrl     = $Env:templateBaseUrl
$appClonedRepo       = "https://github.com/$githubUser/jumpstart-agora-apps"
$namingGuid          = $Env:namingGuid
$adminPassword       = $Env:adminPassword
$aioNamespace        = "azure-iot-operations"

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Force TLS 1.2 for connections to prevent TLS/SSL errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#####################################################################
# Setup Azure CLI
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/17)" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
az account set -s $subscription | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")

# Making extension install dynamic
if ($AgConfig.AzCLIExtensions.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing Azure CLI extensions: " ($AgConfig.AzCLIExtensions -join ', ') -ForegroundColor Gray
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    # Installing Azure CLI extensions
    foreach ($extension in $AgConfig.AzCLIExtensions) {
        az extension add --name $extension --system --only-show-errors
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Az CLI configuration complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Setup Azure PowerShell and register providers
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell (Step 2/17)" -ForegroundColor DarkGreen
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
$subscriptionId = (Get-AzSubscription).Id

# Install PowerShell modules
if ($AgConfig.PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($AgConfig.PowerShellModules -join ', ') -ForegroundColor Gray
    foreach ($module in $AgConfig.PowerShellModules) {
        Install-Module -Name $module -Force | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}

# Register Azure providers
if ($AgConfig.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($AgConfig.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AgConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

#############################################################
# Install Windows Terminal, WSL2, and Ubuntu
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing dev tools (Step 3/17)" -ForegroundColor DarkGreen

$DevToolsInstallationJob = Invoke-Command -ScriptBlock {

$AgConfig = $using:AgConfig
$websiteUrls = $using:websiteUrls
$AgToolsDir         = $using:AgToolsDir
$adminUsername = $using:adminUsername


If ($PSVersionTable.PSVersion.Major -ge 7) { Write-Error "This script needs be run by version of PowerShell prior to 7.0" }
$downloadDir = "C:\WinTerminal"
$frameworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$WindowsTerminalKitPath = "$downloadDir\Microsoft.WindowsTerminal.PreinstallKit.zip"
$windowsTerminalPath = "$downloadDir\WindowsTerminal"
$filenamePattern = "*PreinstallKit.zip"
$terminalDownloadUri = ((Invoke-RestMethod -Method GET -Uri $websiteUrls["windowsTerminal"]).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -First 1

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Write-Host "[$(Get-Date -Format t)] INFO: Downloading binaries." -ForegroundColor Gray

$ProgressPreference = 'SilentlyContinue'

Invoke-WebRequest -Uri $websiteUrls["vcLibs"] -OutFile ( New-Item -Path $frameworkPkgPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
Invoke-WebRequest -Uri $terminalDownloadUri -OutFile ( New-Item -Path $windowsTerminalKitPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

$ProgressPreference = 'Continue'

# Extract Windows Terminal PreinstallKit
Write-Host "[$(Get-Date -Format t)] INFO: Expanding Windows Terminal PreinstallKit." -ForegroundColor Gray
Expand-Archive $WindowsTerminalKitPath $windowsTerminalPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install WSL latest kernel update
Write-Host "[$(Get-Date -Format t)] INFO: Installing WSL." -ForegroundColor Gray
msiexec /i "$AgToolsDir\wsl_update_x64.msi" /qn | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Write-Host "[$(Get-Date -Format t)] INFO: Installing Windows Terminal" -ForegroundColor Gray
Add-AppxPackage -Path $frameworkPkgPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install the Windows Terminal prereqs
foreach ($file in Get-ChildItem $windowsTerminalPath -Filter *x64*.appx) {
    Add-AppxPackage -Path $file.FullName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

# Install Windows Terminal
foreach ($file in Get-ChildItem $windowsTerminalPath -Filter *.msixbundle) {
    Add-AppxPackage -Path $file.FullName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

# Configure Windows Terminal
Set-Location $Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState

# Launch Windows Terminal for default settings.json to be created
$action = New-ScheduledTaskAction -Execute $((Get-Command wt.exe).Source)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(1)
$null = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName WindowsTerminalInit

# Give process time to initiate and create settings file
Start-Sleep 10

# Stop Windows Terminal process
Get-Process WindowsTerminal | Stop-Process

Unregister-ScheduledTask -TaskName WindowsTerminalInit -Confirm:$false

$settings = Get-Content .\settings.json | ConvertFrom-Json
$settings.profiles.defaults.elevate

# Configure the default profile setting "Run this profile as Administrator" to "true"
$settings.profiles.defaults | Add-Member -Name elevate -MemberType NoteProperty -Value $true -Force

$settings | ConvertTo-Json -Depth 8 | Set-Content .\settings.json

# Install Ubuntu
Write-Host "[$(Get-Date -Format t)] INFO: Installing Ubuntu" -ForegroundColor Gray
Add-AppxPackage -Path "$AgToolsDir\Ubuntu.appx" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Setting WSL environment variables
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + ";C:\Users\$adminUsername\Ubuntu", "User")

# Initializing the wsl ubuntu app without requiring user input
$ubuntu_path = "c:/users/$adminUsername/AppData/Local/Microsoft/WindowsApps/ubuntu"
Invoke-Expression -Command "$ubuntu_path install --root" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Create Windows Terminal shortcut
$WshShell = New-Object -comObject WScript.Shell
$WinTerminalPath = (Get-ChildItem "C:\Program Files\WindowsApps" -Recurse | Where-Object { $_.name -eq "wt.exe" }).FullName
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Windows Terminal.lnk")
$Shortcut.TargetPath = $WinTerminalPath
$shortcut.WindowStyle = 3
$shortcut.Save()

#############################################################
# Install VSCode extensions
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($AgConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
# Install VSCode extensions
foreach ($extension in $AgConfig.VSCodeExtensions) {
    code --install-extension $extension 2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

#############################################################
# Install Docker Desktop
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing Docker Desktop." -ForegroundColor DarkGreen
# Download and Install Docker Desktop
$arguments = 'install --quiet --accept-license'
Start-Process "$AgToolsDir\DockerDesktopInstaller.exe" -Wait -ArgumentList $arguments
Get-ChildItem "$Env:USERPROFILE\Desktop\Docker Desktop.lnk" | Remove-Item -Confirm:$false
Copy-Item "$AgToolsDir\settings.json" -Destination "$Env:USERPROFILE\AppData\Roaming\Docker\settings.json" -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep -Seconds 15
Get-Process | Where-Object { $_.name -like "Docker Desktop" } | Stop-Process -Force
# Cleanup
Remove-Item $downloadDir -Recurse -Force

} -JobName step3 -ThrottleLimit 16 -AsJob -ComputerName .

Write-Host "[$(Get-Date -Format t)] INFO: Dev Tools installation initiated in background job." -ForegroundColor Green

$DevToolsInstallationJob

Write-Host


#####################################################################
# Configure L1 virtualization infrastructure
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure (Step 6/17)" -ForegroundColor DarkGreen
$password = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($AgConfig.L1Username, $password)

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
$kubeFolder = "$Env:USERPROFILE\.kube"
New-Item -ItemType Directory $kubeFolder -Force | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-SmbShare -Name "kube" -Path "$Env:USERPROFILE\.kube" -FullAccess "Everyone" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Enable Enhanced Session Mode on Host
Write-Host "[$(Get-Date -Format t)] INFO: Enabling Enhanced Session Mode on Hyper-V host" -ForegroundColor Gray
Set-VMHost -EnableEnhancedSessionMode $true | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + $AgConfig.L1SwitchName + ")")).ifIndex
New-NetIPAddress -IPAddress $AgConfig.L1DefaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-NetNat -Name $AgConfig.L1SwitchName -InternalIPInterfaceAddressPrefix $AgConfig.L1NatSubnetPrefix | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

#####################################################################
# Deploying the nested L1 virtual machines
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Fetching Windows 11 IoT Enterprise VM image from Azure storage. This may take a few minutes." -ForegroundColor Yellow
# azcopy cp $AgConfig.PreProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
azcopy cp $AgConfig.ProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create three virtual machines from the base VHDX image
$vhdxPath = Get-ChildItem $AgConfig.AgDirectories["AgVHDXDir"] -Filter *.vhdx | Select-Object -ExpandProperty FullName
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        # Create disks for each site host
        Write-Host "[$(Get-Date -Format t)] INFO: Creating $($site.Name) disk." -ForegroundColor Gray
        $destVhdxPath = "$($AgConfig.AgDirectories["AgVHDXDir"])\$($site.Name)Disk.vhdx"
        $destPath = $AgConfig.AgDirectories["AgVHDXDir"]
        New-VHD -ParentPath $vhdxPath -Path $destVhdxPath -Differencing | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

        # Create a new virtual machine and attach the existing virtual hard disk
        Write-Host "[$(Get-Date -Format t)] INFO: Creating and configuring $($site.Name) virtual machine." -ForegroundColor Gray

            New-VM -Name $site.Name `
            -Path $destPath `
            -MemoryStartupBytes $AgConfig.L1VMMemory `
            -BootDevice VHD `
            -VHDPath $destVhdxPath `
            -Generation 2 `
            -Switch $AgConfig.L1SwitchName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

        # Set up the virtual machine before coping all AKS Edge Essentials automation files
        Set-VMProcessor -VMName $site.Name `
            -Count $AgConfig.L1VMNumVCPU `
            -ExposeVirtualizationExtensions $true | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

        Get-VMNetworkAdapter -VMName $site.Name | Set-VMNetworkAdapter -MacAddressSpoofing On | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
        Enable-VMIntegrationService -VMName $site.Name -Name "Guest Service Interface" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

        # Start the virtual machine
        Start-VM -Name $site.Name | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
    }
}

Start-Sleep -Seconds 20
# Create an array with VM names
$VMnames = (Get-VM).Name

$sourcePath = "$PsHome\Profile.ps1"
$destinationPath = "C:\Deployment\Profile.ps1"
$maxRetries = 3

foreach ($VM in $VMNames) {
    $retryCount = 0
    $copySucceeded = $false

    while (-not $copySucceeded -and $retryCount -lt $maxRetries) {
        try {
            Copy-VMFile $VM -SourcePath $sourcePath -DestinationPath $destinationPath -CreateFullPath -FileSource Host -Force -ErrorAction Stop
            $copySucceeded = $true
            Write-Host "File copied to $VM successfully."
        } catch {
            $retryCount++
            Write-Host "Attempt $retryCount : File copy to $VM failed. Retrying..."
            Start-Sleep -Seconds 30  # Wait for 30 seconds before retrying
        }
    }

    if (-not $copySucceeded) {
        Write-Host "File copy to $VM failed after $maxRetries attempts."
    }
}

########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap
########################################################################
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        Write-Host "[$(Get-Date -Format t)] INFO: Renaming computer name of $($site.Name)" -ForegroundColor Gray
        $ErrorActionPreference = "SilentlyContinue"
        Invoke-Command -VMName $site.Name -Credential $Credentials -ScriptBlock {
            $site = $using:site
            (gwmi win32_computersystem).Rename($site.Name)
        } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
        $ErrorActionPreference = "Continue"
        Stop-VM -Name $site.Name -Force -Confirm:$false
        Start-VM -Name $site.Name
    }
}

foreach ($VM in $VMNames) {
    $VMStatus = Get-VMIntegrationService -VMName $VM -Name Heartbeat
    while ($VMStatus.PrimaryStatusDescription -ne "OK") {
        $VMStatus = Get-VMIntegrationService -VMName $VM -Name Heartbeat
        write-host "[$(Get-Date -Format t)] INFO: Waiting for $VM to finish booting." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Fetching the latest two AKS Edge Essentials releases." -ForegroundColor Gray
$latestReleaseTag = (Invoke-WebRequest $websiteUrls["aksEEReleases"] | ConvertFrom-Json)[0].tag_name
$beforeLatestReleaseTag = (Invoke-WebRequest $websiteUrls["aksEEReleases"] | ConvertFrom-Json)[1].tag_name
$AKSEEReleasesTags = ($latestReleaseTag,$beforeLatestReleaseTag)
$AKSEESchemaVersions = @()

for ($i = 0; $i -lt $AKSEEReleasesTags.Count; $i++) {
    $releaseTag = (Invoke-WebRequest $websiteUrls["aksEEReleases"] | ConvertFrom-Json)[$i].tag_name
    $AKSEEReleaseDownloadUrl = "https://github.com/Azure/AKS-Edge/archive/refs/tags/$releaseTag.zip"
    $output = Join-Path $AgToolsDir "$releaseTag.zip"
    Invoke-WebRequest $AKSEEReleaseDownloadUrl -OutFile $output
    Expand-Archive $output -DestinationPath $AgToolsDir -Force
    $AKSEEReleaseConfigFilePath = "$AgToolsDir\AKS-Edge-$releaseTag\tools\aksedge-config.json"
    $jsonContent = Get-Content -Raw -Path $AKSEEReleaseConfigFilePath | ConvertFrom-Json
    $schemaVersion = $jsonContent.SchemaVersion
    $AKSEESchemaVersions += $schemaVersion
    # Clean up the downloaded release files
    Remove-Item -Path $output -Force
    Remove-Item -Path "$AgToolsDir\AKS-Edge-$releaseTag" -Force -Recurse
}

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure
    ###########################################
    Write-Host "[$(Get-Date -Format t)] INFO: Preparing folder structure on $hostname." -ForegroundColor Gray
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    $kubeFolder = "$Env:USERPROFILE\.kube"

    # Set up an array of folders
    $folders = @($logsFolder, $kubeFolder)

    # Loop through each folder and create it
    foreach ($Folder in $folders) {
        New-Item -ItemType Directory $Folder -Force
    }
} | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

$subscriptionId = (Get-AzSubscription).Id
Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Start logging
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    Start-Transcript -Path $logsFolder\AKSEEBootstrap.log
    $AgConfig = $using:AgConfig
    $AgToolsDir = $using:AgToolsDir
    $websiteUrls = $using:websiteUrls

    ##########################################
    # Deploying AKS Edge Essentials clusters
    ##########################################
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"

    # Assigning network adapter IP address
    $NetIPAddress = $AgConfig.SiteConfig[$Env:COMPUTERNAME].NetIPAddress
    $DefaultGateway = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DefaultGateway
    $PrefixLength = $AgConfig.SiteConfig[$Env:COMPUTERNAME].PrefixLength
    $DNSClientServerAddress = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DNSClientServerAddress
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring networking interface on $hostname with IP address $NetIPAddress." -ForegroundColor Gray
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex | Out-Null
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress | Out-Null

    ###########################################
    # Validating internet connectivity
    ###########################################
    $timeElapsed = 0
    do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for internet connection to be healthy on $hostname." -ForegroundColor Gray
        Start-Sleep -Seconds 5
        $timeElapsed = $timeElapsed + 10
    } until ((Test-Connection bing.com -Count 1 -ErrorAction SilentlyContinue) -or ($timeElapsed -eq 60))

    # Fetching latest AKS Edge Essentials msi file
    Write-Host "[$(Get-Date -Format t)] INFO: Fetching latest AKS Edge Essentials install file on $hostname." -ForegroundColor Gray
    Invoke-WebRequest $websiteUrls["aksEEk3s"] -OutFile $deploymentFolder\AKSEEK3s.msi

    # Fetching required GitHub artifacts from Jumpstart repository
    Write-Host "[$(Get-Date -Format t)] INFO: Fetching GitHub artifacts" -ForegroundColor Gray
    $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
    $githubApiUrl = "https://api.github.com/repos/$using:githubAccount/$repoName/contents/azure_jumpstart_ag/manufacturing/artifacts/L1Files?ref=$using:githubBranch"
    $response = Invoke-RestMethod -Uri $githubApiUrl
    $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
    $fileUrls | ForEach-Object {
        $fileName = $_.Substring($_.LastIndexOf("/") + 1)
        $outputFile = Join-Path $deploymentFolder $fileName
        Invoke-RestMethod -Uri $_ -OutFile $outputFile
    }

    ###############################################################################
    # Setting up replacement parameters for AKS Edge Essentials config json file
    ###############################################################################
    Write-Host "[$(Get-Date -Format t)] INFO: Building AKS Edge Essentials config json file on $hostname." -ForegroundColor Gray
    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $namingGuid = $using:namingGuid
    $arcClusterName = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ArcClusterName + "-$namingGuid"

    # Fetch schemaVersion release from the AgConfig file
    $AKSEESchemaVersionUseLatest = $AgConfig.SiteConfig[$Env:COMPUTERNAME].AKSEEReleaseUseLatest
    if($AKSEESchemaVersionUseLatest){
        $SchemaVersion = $using:AKSEESchemaVersions[0]
    }
    else {
        $SchemaVersion = $using:AKSEESchemaVersions[1]
    }

    $replacementParams = @{
        "SchemaVersion-null"          = $SchemaVersion
        "ServiceIPRangeStart-null"    = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ServiceIPRangeStart
        "1000"                        = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DefaultGateway
        "2000"                        = $AgConfig.SiteConfig[$Env:COMPUTERNAME].PrefixLength
        "DnsServer-null"              = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $AgConfig.SiteConfig[$Env:COMPUTERNAME].LinuxNodeIp4Address
        "ClusterName-null"            = $arcClusterName
        "Location-null"               = $using:azureLocation
        "ResourceGroupName-null"      = $using:resourceGroup
        "SubscriptionId-null"         = $using:subscriptionId
        "TenantId-null"               = $using:spnTenantId
        "ClientId-null"               = $using:spnClientId
        "ClientSecret-null"           = $using:spnClientSecret
    }

    ###################################################
    # Preparing AKS Edge Essentials config json file
    ###################################################
    $content = Get-Content $AKSEEConfigFilePath
    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }
    Set-Content "$deploymentFolder\Config.json" -Value $content
}
Write-Host "[$(Get-Date -Format t)] INFO: Initial L1 virtualization infrastructure configuration complete." -ForegroundColor Green
Write-Host

Write-Host "[$(Get-Date -Format t)] INFO: Installing AKS Edge Essentials (Step 7/17)" -ForegroundColor DarkGreen
foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Write-Host "[$(Get-Date -Format t)] INFO: Rebooting $VMName." -ForegroundColor Gray
    Invoke-Command -Session $Session -ScriptBlock {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $Env:USERNAME -Password 'Agora123!!' -RunLevel Highest | Out-Null
        Restart-Computer -Force -Confirm:$false
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
    Remove-PSSession $Session | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
}

Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.

#####################################################################
# Monitor until the kubeconfig files are detected and copied over
#####################################################################
$elapsedTime = Measure-Command {
    foreach ($VMName in $VMNames) {
        $path = "C:\Users\Administrator\.kube\config-" + $VMName.ToLower()
        $user = $AgConfig.L1Username
        [securestring]$secStringPassword = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($user, $secStringPassword)
        Start-Sleep 5
        while (!(Invoke-Command -VMName $VMName -Credential $credential -ScriptBlock { Test-Path $using:path })) {
            Start-Sleep 30
            Write-Host "[$(Get-Date -Format t)] INFO: Waiting for AKS Edge Essentials kubeconfig to be available on $VMName." -ForegroundColor Gray
        }

        Write-Host "[$(Get-Date -Format t)] INFO: $VMName's kubeconfig is ready - copying over config-$VMName" -ForegroundColor DarkGreen
        $destinationPath = $Env:USERPROFILE + "\.kube\config-" + $VMName
        $s = New-PSSession -VMName $VMName -Credential $credential
        Copy-Item -FromSession $s -Path $path -Destination $destinationPath
        $file = Get-Item $destinationPath
        if ($file.Length -eq 0) {
            Write-Host "[$(Get-Date -Format t)] ERROR: Kubeconfig on $VMName is corrupt. This error is unrecoverable. Exiting." -ForegroundColor White -BackgroundColor Red
            exit 1
        }
    }
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "[$(Get-Date -Format t)] INFO: Waiting on kubeconfig files took $($elapsedTime.ToString("g"))." -ForegroundColor Gray

#####################################################################
# Merging kubeconfig files on the L0 virtual machine
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files are present. Merging kubeconfig files for use with kubectx." -ForegroundColor Gray
$kubeconfigpath = ""
foreach ($VMName in $VMNames) {
    $kubeconfigpath = $kubeconfigpath + "$Env:USERPROFILE\.kube\config-" + $VMName.ToLower() + ";"
}
$Env:KUBECONFIG = $kubeconfigpath
kubectl config view --merge --flatten > "$Env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
kubectl config get-clusters --kubeconfig="$Env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
Rename-Item -Path "$Env:USERPROFILE\.kube\config-raw" -NewName "$Env:USERPROFILE\.kube\config"
$Env:KUBECONFIG = "$Env:USERPROFILE\.kube\config"

# Print a message indicating that the merge is complete
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files merged successfully." -ForegroundColor Gray

# Validate context switching using kubectx & kubectl
foreach ($cluster in $VMNames) {
    Write-Host "[$(Get-Date -Format t)] INFO: Testing connectivity to kube api on $cluster cluster." -ForegroundColor Gray
    kubectx $cluster.ToLower()
    kubectl get nodes -o wide
}
Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials installs are complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Creating Kubernetes namespaces on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating namespaces on clusters (Step 8/17)" -ForegroundColor DarkGreen
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    foreach ($namespace in $AgConfig.Namespaces) {
        Write-Host "[$(Get-Date -Format t)] INFO: Creating namespace $namespace on $clusterName" -ForegroundColor Gray
        kubectl create namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    }
}

#####################################################################
# Setup Azure Container registry pull secret on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 9/17)" -ForegroundColor DarkGreen
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    foreach ($namespace in $AgConfig.Namespaces) {
        if ($namespace -eq "contoso-supermarket" -or $namespace -eq "images-cache"){
            Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure Container registry on $clusterName"
            kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
            kubectl create secret docker-registry acr-secret `
                --namespace $namespace `
                --docker-server="$acrName.azurecr.io" `
                --docker-username="$Env:spnClientId" `
                --docker-password="$Env:spnClientSecret" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
        }
    }
}

#####################################################################
# Connect the AKS Edge Essentials clusters and hosts to Azure Arc
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Connecting AKS Edge clusters to Azure with Azure Arc (Step 10/17)" -ForegroundColor DarkGreen

# Running pre-checks to ensure that the aksedge ConfigMap is present on all clusters
$maxRetries = 5
$retryInterval = 30 # seconds
$retryCount = 0
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    if ($clusterName -ne "staging") {
        while ($retryCount -lt $maxRetries) {
            kubectx $clusterName
            $configMap = kubectl get configmap -n aksedge aksedge
            if ($null -eq $configMap) {
                $retryCount++
                Write-Host "Retry ${retryCount}/${maxRetries}: aksedge ConfigMap not found on $clusterName. Retrying in $retryInterval seconds..." | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
                Start-Sleep -Seconds $retryInterval
            }
            else {
                # ConfigMap found, continue with the rest of the script
                Write-Host "aksedge ConfigMap found on $clusterName. Continuing with the script..." | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
                break # Exit the loop
            }
        }

        if ($retryCount -eq $maxRetries) {
            Write-Host "[$(Get-Date -Format t)] ERROR: aksedge ConfigMap not found on $clusterName. Exiting..." -ForegroundColor White -BackgroundColor Red | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
            exit 1 # Exit the script
        }
    }
}

foreach ($VM in $VMNames) {
    $secret = $Env:spnClientSecret
    $clientId = $Env:spnClientId
    $tenantId = $Env:spnTenantId
    $location = $Env:azureLocation
    $resourceGroup = $Env:resourceGroup

    Invoke-Command -VMName $VM -Credential $Credentials -ScriptBlock {
        # Install prerequisites
        . C:\Deployment\Profile.ps1
        $hostname = hostname
        $ProgressPreference = "SilentlyContinue"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Install-Module Az.ConnectedKubernetes -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Install-Module Az.ConnectedMachine -Force -AllowClobber -ErrorAction Stop

        # Connect servers to Arc
        $azurePassword = ConvertTo-SecureString $using:secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($using:clientId, $azurePassword)
        Connect-AzAccount -Credential $psCred -TenantId $using:tenantId -ServicePrincipal
        Write-Host "[$(Get-Date -Format t)] INFO: Arc-enabling $hostname server." -ForegroundColor Gray
        Redo-Command -ScriptBlock { Connect-AzConnectedMachine -ResourceGroupName $using:resourceGroup -Name "Ag-$hostname-Host" -Location $using:location }

        # Connect clusters to Arc
        $deploymentPath = "C:\Deployment\config.json"
        Write-Host "[$(Get-Date -Format t)] INFO: Arc-enabling $hostname AKS Edge Essentials cluster." -ForegroundColor Gray

        kubectl get svc

        $retryCount = 5  # Number of times to retry the operation
        $retryDelay = 30  # Delay in seconds between retries

        for ($retry = 1; $retry -le $retryCount; $retry++) {
            $return = Connect-AksEdgeArc -JsonConfigFilePath $deploymentPath
            if ($return -ne "OK") {
                Write-Output "Failed to onboard AKS Edge Essentials cluster to Azure Arc. Retrying (Attempt $retry of $retryCount)..."
                if ($retry -lt $retryCount) {
                    Start-Sleep -Seconds $retryDelay  # Wait before retrying
                }
                else {
                    Write-Output "Exceeded maximum retry attempts. Exiting."
                    break  # Exit the loop after the maximum number of retries
                }
            } else {
                Write-Output "Successfully onboarded AKS Edge Essentials cluster to Azure Arc."
                break  # Exit the loop if the connection is successful
            }
        }


    } 2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
}

#####################################################################
# Tag Azure Arc resources
#####################################################################
$arcResourceTypes = $AgConfig.ArcServerResourceType, $AgConfig.ArcK8sResourceType
$Tag = @{$AgConfig.TagName = $AgConfig.TagValue }

# Iterate over the Arc resources and tag it
foreach ($arcResourceType in $arcResourceTypes) {
    $arcResources = Get-AzResource -ResourceType $arcResourceType -ResourceGroupName $Env:resourceGroup
    foreach ($arcResource in $arcResources) {
        Update-AzTag -ResourceId $arcResource.Id -Tag $Tag -Operation Merge | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials clusters and hosts have been registered with Azure Arc!" -ForegroundColor Green
Write-Host


##############################################################
# Preparing clusters for aio
##############################################################

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure
    ###########################################
    Write-Host "[$(Get-Date -Format t)] INFO: Preparing AKSEE clusters for AIO" -ForegroundColor DarkGray
    try {
        $localPathProvisionerYaml = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml"
        & kubectl apply -f $localPathProvisionerYaml
        $pvcYaml = @"
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: local-path-pvc
          namespace: default
        spec:
          accessModes:
            - ReadWriteOnce
          storageClassName: local-path
          resources:
            requests:
              storage: 15Gi
"@
    
        $pvcYaml | kubectl apply -f -
    
        Write-Host "Successfully deployment the local path provisioner"
    }
    catch {
        Write-Host "Error: local path provisioner deployment failed" -ForegroundColor Red
    }

    Write-Host "Configuring firewall specific to AIO"
    Write-Host "Add firewall rule for AIO MQTT Broker"
    New-NetFirewallRule -DisplayName "AIO MQTT Broker" -Direction Inbound  -Action Allow | Out-Null
    try {
        $deploymentInfo = Get-AksEdgeDeploymentInfo
        # Get the service ip address start to determine the connect address
        $connectAddress = $deploymentInfo.LinuxNodeConfig.ServiceIpRange.split("-")[0]
        $portProxyRulExists = netsh interface portproxy show v4tov4 | findstr /C:"1883" | findstr /C:"$connectAddress"
        if ( $null -eq $portProxyRulExists ) {
            Write-Host "Configure port proxy for AIO"
            netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$connectAddress | Out-Null
            netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=18883 connectaddress=$connectAddress | Out-Null
            netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=8883 connectaddress=$connectAddress | Out-Null
        }
        else {
            Write-Host "Port proxy rule for AIO exists, skip configuring port proxy..."
        }
    }
    catch {
        Write-Host "Error: port proxy update for aio failed" -ForegroundColor Red
    }
    Write-Host "Update the iptables rules"
    try {
        $iptableRulesExist = Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables-save | grep -- '-m tcp --dport 9110 -j ACCEPT'" -ignoreError
        if ( $null -eq $iptableRulesExist ) {
            Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 9110 -j ACCEPT"
            Write-Host "Updated runtime iptable rules for node exporter"
            Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo sed -i '/-A OUTPUT -j ACCEPT/i-A INPUT -p tcp -m tcp --dport 9110 -j ACCEPT' /etc/systemd/scripts/ip4save"
            Write-Host "Persisted iptable rules for node exporter"
        }
        else {
            Write-Host "iptable rule exists, skip configuring iptable rules..."
        }
    }
    catch {
        Write-Host "Error: iptable rule update failed" -ForegroundColor Red
    }

} | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

#############################################################
# Deploying AIO on the clusters
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Deploying AIO to the clusters" -ForegroundColor DarkGray
Write-Host "`n"
az extension add --upgrade --source ([System.Net.HttpWebRequest]::Create('https://aka.ms/aziotopscli-edge').GetResponse().ResponseUri.AbsoluteUri) -y
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    kubectx $clusterName
    $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
    $keyVaultId = (az keyvault list -g $resourceGroup --resource-type vault --query "[0].id" -o tsv)
    $retryCount = 0
    $maxRetries = 5
    $aioStatus = "notDeployed"

    # Enable custom locations on the Arc-enabled cluster
    Write-Host "[$(Get-Date -Format t)] INFO: Enabling custom locations on the Arc-enabled cluster" -ForegroundColor DarkGray
    az connectedk8s enable-features --name $arcClusterName `
        --resource-group $resourceGroup `
        --features cluster-connect custom-locations `
        --custom-locations-oid $customLocationRPOID `
        --only-show-errors


    do {
        az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientID --sp-secret $spnClientSecret --mq-service-type loadBalancer --mq-insecure true --simulate-plc true --only-show-errors
        if ($? -eq $false) {
            $aioStatus = "notDeployed"
            Write-Host "`n"
            Write-Host "[$(Get-Date -Format t)] Error: An error occured while deploying AIO on the cluster...Retrying" -ForegroundColor DarkRed
            Write-Host "`n"
            $retryCount++
        }else{
            $aioStatus = "deployed"
        }
    } until ($aioStatus -eq "deployed" -or $retryCount -eq $maxRetries)

    $retryCount = 0
    $maxRetries = 5

    do {
        $output = az iot ops check --as-object
        $output = $output | ConvertFrom-Json
        $mqServiceStatus = ($output.postDeployment | Where-Object { $_.name -eq "evalBrokerListeners" }).status
        if ($mqServiceStatus -ne "Success") {
            az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientID --sp-secret $spnClientSecret --mq-service-type loadBalancer --mq-insecure true --simulate-plc true --only-show-errors
            $retryCount++
        }
    } until ($mqServiceStatus -eq "Success" -or $retryCount -eq $maxRetries)

    if ($retryCount -eq $maxRetries) {
        Write-Host "[$(Get-Date -Format t)] ERROR: AIO deployment failed. Exiting..." -ForegroundColor White -BackgroundColor Red
        exit 1 # Exit the script
    }

    Write-Host "[$(Get-Date -Format t)] INFO: Started Event Grid role assignment process" -ForegroundColor DarkGray
    $extensionPrincipalId = (az k8s-extension show --cluster-name $arcClusterName --name "mq" --resource-group $resourceGroup --cluster-type "connectedClusters" --output json | ConvertFrom-Json).identity.principalId
    $eventGridTopicId = (az eventgrid topic list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)
    $eventGridNamespaceName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].name" -o tsv --only-show-errors)
    $eventGridNamespaceId = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)

    az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
    az role assignment create --assignee-object-id $spnObjectId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
    az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid TopicSpaces Subscriber" --scope $eventGridNamespaceId --assignee-principal-type ServicePrincipal --only-show-errors
    az role assignment create --assignee-object-id $extensionPrincipalId --role 'EventGrid TopicSpaces Publisher' --scope $eventGridNamespaceId --assignee-principal-type ServicePrincipal --only-show-errors
    az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid TopicSpaces Subscriber" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
    az role assignment create --assignee-object-id $extensionPrincipalId --role 'EventGrid TopicSpaces Publisher' --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors


    Write-Host "[$(Get-Date -Format t)] INFO: Configuring routing to use system-managed identity" -ForegroundColor DarkGray
    $eventGridConfig = "{routing-identity-info:{type:'SystemAssigned'}}"
    az eventgrid namespace update -g $resourceGroup -n $eventGridNamespaceName --topic-spaces-configuration $eventGridConfig --only-show-errors

    Start-Sleep -Seconds 60

    ## Adding MQTT load balancer
    $mqconfigfile = "$aioToolsDir\mq_cloudConnector.yml"
    $mqListenerService = "aio-mq-dmqtt-frontend"
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring the MQ Event Grid bridge" -ForegroundColor DarkGray
    $eventGridHostName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].topicSpacesConfiguration.hostname" -o tsv --only-show-errors)
    (Get-Content -Path $mqconfigfile) -replace 'eventGridPlaceholder', $eventGridHostName | Set-Content -Path $mqconfigfile
    kubectl apply -f $mqconfigfile -n $aioNamespace
}

#####################################################################
# Installing flux extension on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on clusters (Step 11/17)" -ForegroundColor DarkGreen

$resourceTypes = @($AgConfig.ArcK8sResourceType, $AgConfig.AksResourceType)
$resources = Get-AzResource -ResourceGroupName $Env:resourceGroup | Where-Object { $_.ResourceType -in $resourceTypes }

$jobs = @()

foreach ($resource in $resources) {

    $resourceName = $resource.Name
    $resourceType = $resource.Type

    Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on $resourceName" -ForegroundColor Gray

        $job = Start-Job -Name $resourceName -ScriptBlock {
            param($resourceName, $resourceType)

            $retryCount = 10
            $retryDelaySeconds = 60

            switch ($resourceType)
            {
                'Microsoft.Kubernetes/connectedClusters' {$ClusterType = 'ConnectedClusters'}
                'Microsoft.ContainerService/managedClusters' {$ClusterType = 'ManagedClusters'}
            }

            if($clusterType -eq 'ConnectedClusters'){
                # Check if cluster is connected to Azure Arc control plane
                $ConnectivityStatus = (Get-AzConnectedKubernetes -ResourceGroupName $Env:resourceGroup -ClusterName $resourceName).ConnectivityStatus

                if (-not ($ConnectivityStatus -eq 'Connected')) {

                for ($attempt = 1; $attempt -le $retryCount; $attempt++) {


                    $ConnectivityStatus = (Get-AzConnectedKubernetes -ResourceGroupName $Env:resourceGroup -ClusterName $resourceName).ConnectivityStatus

                    # Check the condition
                    if ($ConnectivityStatus -eq 'Connected') {
                        # Condition is true, break out of the loop
                        break
                    }

                    # Wait for a specific duration before re-evaluating the condition
                    Start-Sleep -Seconds $retryDelaySeconds


                        if ($attempt -lt $retryCount) {
                            Write-Host "Retrying in $retryDelaySeconds seconds..."
                            Start-Sleep -Seconds $retryDelaySeconds
                        }
                        else {
                        $ProvisioningState = "Timed out after $($retryDelaySeconds * $retryCount) seconds while waiting for cluster to become connected to Azure Arc control plane. Current status: $ConnectivityStatus"
                            break # Max retry attempts reached, exit the loop
                        }

                    }
                }
            }

            $extension = az k8s-extension list --cluster-name $resourceName --resource-group $Env:resourceGroup --cluster-type $ClusterType --output json | ConvertFrom-Json
            $extension = $extension | Where-Object extensionType -eq 'microsoft.flux'

            if ($extension.ProvisioningState -ne 'Succeeded' -and ($ConnectivityStatus -eq 'Connected' -or $clusterType -eq "ManagedClusters")) {

            for ($attempt = 1; $attempt -le $retryCount; $attempt++) {

                try {

                    if ($extension) {

                        az k8s-extension delete --name "flux" --cluster-name $resourceName --resource-group $Env:resourceGroup --cluster-type $ClusterType --force --yes

                     }

                    az k8s-extension create --name "flux" --extension-type "microsoft.flux" --cluster-name $resourceName --resource-group $Env:resourceGroup --cluster-type $ClusterType --output json | ConvertFrom-Json -OutVariable extension

                    break # Command succeeded, exit the loop
                }

                catch {
                    Write-Warning "An error occurred: $($_.Exception.Message)"

                    if ($attempt -lt $retryCount) {
                        Write-Host "Retrying in $retryDelaySeconds seconds..."
                        Start-Sleep -Seconds $retryDelaySeconds
                    }
                    else {
                        Write-Error "Failed to execute the command after $retryCount attempts."
                        $ProvisioningState = $($_.Exception.Message)
                        break # Max retry attempts reached, exit the loop
                    }

                 }

              }

            }

            $ProvisioningState = $extension.ProvisioningState

            [PSCustomObject]@{
                ResourceName = $resourceName
                ResourceType = $resourceType
                ProvisioningState = $ProvisioningState
            }

        } -ArgumentList $resourceName, $resourceType

        $jobs += $job
}

# Wait for all jobs to complete
$FluxExtensionJobs = $jobs | Wait-Job | Receive-Job -Keep

$jobs | Format-Table Name,PSBeginTime,PSEndTime -AutoSize

# Clean up jobs
$jobs | Remove-Job

# Abort if Flux-extension fails on any cluster
if ($FluxExtensionJobs | Where-Object ProvisioningState -ne 'Succeeded') {

    throw "One or more Flux-extension deployments failed - aborting"

}

#####################################################################
# Deploy Kubernetes Prometheus Stack for Observability
#####################################################################
$AgMonitoringDir = $AgConfig.AgDirectories["AgMonitoringDir"]
$observabilityNamespace = $AgConfig.Monitoring["Namespace"]
$observabilityDashboards = $AgConfig.Monitoring["Dashboards"]
$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

# Set Prod Grafana API endpoint
$grafanaDS = $AgConfig.Monitoring["ProdURL"] + "/api/datasources"

# Installing Grafana
Write-Host "[$(Get-Date -Format t)] INFO: Installing and Configuring Observability components (Step 14/17)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Installing Grafana." -ForegroundColor Gray
$latestRelease = (Invoke-WebRequest -Uri $websiteUrls["grafana"] | ConvertFrom-Json).tag_name.replace('v', '')
Start-Process msiexec.exe -Wait -ArgumentList "/I $AgToolsDir\grafana-$latestRelease.windows-amd64.msi /quiet" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Prometheus Helm charts
helm repo add prometheus-community $websiteUrls["prometheus"] | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Grafana Icons
Copy-Item -Path $AgIconsDir\contoso.png -Destination "C:\Program Files\GrafanaLabs\grafana\public\img"
Copy-Item -Path $AgIconsDir\contoso.svg -Destination "C:\Program Files\GrafanaLabs\grafana\public\img\grafana_icon.svg"

Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object {
(Get-Content $_.FullName) -replace 'className:u,src:"public/img/grafana_icon.svg"', 'className:u,src:"public/img/contoso.png"' | Set-Content $_.FullName
}

# Reset Grafana UI
Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object {
(Get-Content $_.FullName) -replace 'Welcome to Grafana', 'Welcome to Grafana for Contoso Supermarket Production' | Set-Content $_.FullName
}

# Reset Grafana Password
$Env:Path += ';C:\Program Files\GrafanaLabs\grafana\bin'
grafana-cli --homepath "C:\Program Files\GrafanaLabs\grafana" admin reset-admin-password $adminPassword | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Get Grafana Admin credentials
$adminCredentials = $AgConfig.Monitoring["AdminUser"] + ':' + $adminPassword
$adminEncodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($adminCredentials))

$adminHeaders = @{
    "Authorization" = ("Basic " + $adminEncodedcredentials)
    "Content-Type"  = "application/json"
}

# Get Contoso User credentials
$userCredentials = $adminUsername + ':' + $adminPassword
$userEncodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userCredentials))

$userHeaders = @{
    "Authorization" = ("Basic " + $userEncodedcredentials)
    "Content-Type"  = "application/json"
}

# Download dashboards
foreach ($dashboard in $observabilityDashboards.'grafana.com') {
    $grafanaDBPath = "$AgMonitoringDir\grafana-$dashboard.json"
    $dashboardmetadata = Invoke-RestMethod -Uri https://grafana.com/api/dashboards/$dashboard/revisions
    $dashboardversion = $dashboardmetadata.items | Sort-Object revision | Select-Object -Last 1 | Select-Object -ExpandProperty revision
    Invoke-WebRequest https://grafana.com/api/dashboards/$dashboard/revisions/$dashboardversion/download -OutFile $grafanaDBPath
}

$observabilityDashboardstoImport = @()
$observabilityDashboardstoImport += $observabilityDashboards.'grafana.com'
$observabilityDashboardstoImport += $observabilityDashboards.'custom'

Write-Host "[$(Get-Date -Format t)] INFO: Creating Prod Grafana User" -ForegroundColor Gray
# Add Contoso Operator User
$grafanaUserBody = @{
    name     = $AgConfig.Monitoring["User"] # Display Name
    email    = $AgConfig.Monitoring["Email"]
    login    = $adminUsername
    password = $adminPassword
} | ConvertTo-Json

# Make HTTP request to the API to create user
$retryCount = 10
$retryDelay = 30
do {
    try {
        Invoke-RestMethod -Method Post -Uri "$($AgConfig.Monitoring["ProdURL"])/api/admin/users" -Headers $adminHeaders -Body $grafanaUserBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
        $retryCount = 0
    }
    catch {
        $retryCount--
        if ($retryCount -gt 0) {
            Write-Host "[$(Get-Date -Format t)] INFO: Retrying in $retryDelay seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds $retryDelay
        }
    }
} while ($retryCount -gt 0)

# Deploying Kube Prometheus Stack for stores
$AgConfig.SiteConfig.GetEnumerator() | ForEach-Object {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying Kube Prometheus Stack for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    kubectx $_.Value.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    # Wait for Kubernetes API server to become available
    $apiServer = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
    $apiServerAddress = $apiServer -replace '.*https://| .*$'
    $apiServerFqdn = ($apiServerAddress -split ":")[0]
    $apiServerPort = ($apiServerAddress -split ":")[1]

    do {
        $result = Test-NetConnection -ComputerName $apiServerFqdn -Port $apiServerPort -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Host "[$(Get-Date -Format t)] INFO: Kubernetes API server $apiServer is available" -ForegroundColor Gray
            break
        }
        else {
            Write-Host "[$(Get-Date -Format t)] INFO: Kubernetes API server $apiServer is not yet available. Retrying in 10 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    } while ($true)

    # Install Prometheus Operator
    $helmSetValue = $_.Value.HelmSetValue -replace 'adminPasswordPlaceholder', $adminPassword
    helm install prometheus prometheus-community/kube-prometheus-stack --set $helmSetValue --namespace $observabilityNamespace --create-namespace --values "$AgMonitoringDir\$($_.Value.HelmValuesFile)" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    Do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for $($_.Value.FriendlyName) monitoring service to provision.." -ForegroundColor Gray
        Start-Sleep -Seconds 45
        $monitorIP = $(if (kubectl get $_.Value.HelmService --namespace $observabilityNamespace --output=jsonpath='{.status.loadBalancer}' | Select-String "ingress" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($monitorIP -eq "Nope" )
    # Get Load Balancer IP
    $monitorLBIP = kubectl --namespace $observabilityNamespace get $_.Value.HelmService --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'

    if ($_.Value.IsProduction) {
        Write-Host "[$(Get-Date -Format t)] INFO: Add $($_.Value.FriendlyName) Data Source to Grafana"
        # Request body with information about the data source to add
        $grafanaDSBody = @{
            name      = $_.Value.FriendlyName.ToLower()
            type      = 'prometheus'
            url       = ("http://" + $monitorLBIP + ":9090")
            access    = 'proxy'
            basicAuth = $false
            isDefault = $true
        } | ConvertTo-Json

        # Make HTTP request to the API
        Invoke-RestMethod -Method Post -Uri $grafanaDS -Headers $adminHeaders -Body $grafanaDSBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
    }

    # Add Contoso Operator User
    if (!$_.Value.IsProduction) {
        Write-Host "[$(Get-Date -Format t)] INFO: Creating $($_.Value.FriendlyName) Grafana User" -ForegroundColor Gray
        $grafanaUserBody = @{
            name     = $AgConfig.Monitoring["User"] # Display Name
            email    = $AgConfig.Monitoring["Email"]
            login    = $adminUsername
            password = $adminPassword
        } | ConvertTo-Json

        # Make HTTP request to the API to create user
        $retryCount = 10
        $retryDelay = 30

        do {
            try {
                Invoke-RestMethod -Method Post -Uri "http://$monitorLBIP/api/admin/users" -Headers $adminHeaders -Body $grafanaUserBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
                $retryCount = 0
            }
            catch {
                $retryCount--
                if ($retryCount -gt 0) {
                    Write-Host "[$(Get-Date -Format t)] INFO: Retrying in $retryDelay seconds..." -ForegroundColor Gray
                    Start-Sleep -Seconds $retryDelay
                }
            }
        } while ($retryCount -gt 0)
    }

    Write-Host "[$(Get-Date -Format t)] INFO: Importing dashboards for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    # Add dashboards
    foreach ($dashboard in $observabilityDashboardstoImport) {
        $grafanaDBPath = "$AgMonitoringDir\grafana-$dashboard.json"
        # Replace the datasource
        $replacementParams = @{
            "\$\{DS_PROMETHEUS}" = $_.Value.GrafanaDataSource
        }
        $content = Get-Content $grafanaDBPath
        foreach ($key in $replacementParams.Keys) {
            $content = $content -replace $key, $replacementParams[$key]
        }
        # Set dashboard JSON
        $dashboardObject = $content | ConvertFrom-Json
        # Best practice is to generate a random UID, such as a GUID
        $dashboardObject.uid = [guid]::NewGuid().ToString()

        # Need to set this to null to let Grafana generate a new ID
        $dashboardObject.id = $null
        # Set dashboard title
        $dashboardObject.title = $_.Value.FriendlyName + ' - ' + $dashboardObject.title
        # Request body with dashboard to add
        $grafanaDBBody = @{
            dashboard = $dashboardObject
            overwrite = $true
        } | ConvertTo-Json -Depth 8

        if ($_.Value.IsProduction) {
            # Set Grafana Dashboard endpoint
            $grafanaDBURI = $AgConfig.Monitoring["ProdURL"] + "/api/dashboards/db"
            $grafanaDBStarURI = $AgConfig.Monitoring["ProdURL"] + "/api/user/stars/dashboard"
        }
        else {
            # Set Grafana Dashboard endpoint
            $grafanaDBURI = "http://$monitorLBIP/api/dashboards/db"
            $grafanaDBStarURI = "http://$monitorLBIP/api/user/stars/dashboard"
        }

        # Make HTTP request to the API
        $dashboardID=(Invoke-RestMethod -Method Post -Uri $grafanaDBURI -Headers $adminHeaders -Body $grafanaDBBody).id

        Invoke-RestMethod -Method Post -Uri "$grafanaDBStarURI/$dashboardID" -Headers $userHeaders | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    }

}
Write-Host

##############################################################
# Creating bookmarks
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Edge Bookmarks in Favorites Bar (Step 15/17)" -ForegroundColor DarkGreen
$bookmarksFileName = "$AgToolsDir\Bookmarks"
$edgeBookmarksPath = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")
    $services = kubectl get services --all-namespaces -o json | ConvertFrom-Json

    # Matching url: pos - customer
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 5000 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $posIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($posIp in $posIps) {
        $output = "http://$posIp" + ':5000'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("POS-" + $cluster.Name + "-URL-Customer"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }

    # Matching url: pos - manager
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 81 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $posIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($posIp in $posIps) {
        $output = "http://$posIp" + ':81'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("POS-" + $cluster.Name + "-URL-Manager"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }

    # Matching url: prometheus-grafana
    if ($cluster.Name -eq "Staging" -or $cluster.Name -eq "Dev") {
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'prometheus-grafana'
        }
        $grafanaIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($grafanaIp in $grafanaIps) {
            $output = "http://$grafanaIp"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Grafana-" + $cluster.Name + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName

            Start-Sleep -Seconds 2
        }
    }

    # Matching url: prometheus
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 9090 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $prometheusIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($prometheusIp in $prometheusIps) {
        $output = "http://$prometheusIp" + ':9090'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("Prometheus-" + $cluster.Name + "-URL"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }
}

# Matching url: Agora apps forked repo
$output = $appClonedRepo
$output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

# Replace matching value in the Bookmarks file
$content = Get-Content -Path $bookmarksFileName
$newContent = $content -replace "Agora-Apps-Repo-Clone-URL", $output
$newContent = $newContent -replace "Agora-Apps-Repo-Your-Fork", "Agora Apps Repo - $githubUser"
$newContent | Set-Content -Path $bookmarksFileName

Start-Sleep -Seconds 2

Copy-Item -Path $bookmarksFileName -Destination $edgeBookmarksPath -Force

##############################################################
# Pinning important directories to Quick access
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Pinning important directories to Quick access (Step 16/17)" -ForegroundColor DarkGreen
$quickAccess = new-object -com shell.application
$quickAccess.Namespace($AgConfig.AgDirectories.AgDir).Self.InvokeVerb("pintohome")
$quickAccess.Namespace($AgConfig.AgDirectories.AgLogsDir).Self.InvokeVerb("pintohome")


##############################################################
# Cleanup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up scripts and uploading logs (Step 17/17)" -ForegroundColor DarkGreen
# Creating Hyper-V Manager desktop shortcut
Write-Host "[$(Get-Date -Format t)] INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force


Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache job" -ForegroundColor Gray
while ($(Get-Job -Name images-cache-cleanup).State -eq 'Running') {
  Write-Host "[$(Get-Date -Format t)] INFO: Waiting for images-cache job to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
  Receive-Job -Name images-cache-cleanup -WarningAction SilentlyContinue
  Start-Sleep -Seconds 60
}
Get-Job -name images-cache-cleanup | Remove-Job

# Removing the LogonScript Scheduled Task
Write-Host "[$(Get-Date -Format t)] INFO: Removing scheduled logon task so it won't run on next login." -ForegroundColor Gray
Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false

# Executing the deployment logs bundle PowerShell script in a new window
Write-Host "[$(Get-Date -Format t)] INFO: Uploading Log Bundle." -ForegroundColor Gray
$Env:AgLogsDir = $AgConfig.AgDirectories["AgLogsDir"]
Invoke-Expression 'cmd /c start Powershell -Command {
$RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
Start-Sleep -Seconds 5
Write-Host "`n"
Write-Host "Creating deployment logs bundle"
7z a $Env:AgLogsDir\LogsBundle-"$RandomString".zip $Env:AgLogsDir\*.log
}'

Write-Host "[$(Get-Date -Format t)] INFO: Changing Wallpaper" -ForegroundColor Gray
$imgPath = $AgConfig.AgDirectories["AgDir"] + "\wallpaper.png"
$code = @'
using System.Runtime.InteropServices;
namespace Win32{

    public class Wallpaper{
        [DllImport("user32.dll", CharSet=CharSet.Auto)]
        static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ;

        public static void SetWallpaper(string thePath){
            SystemParametersInfo(20,0,thePath,3);
        }
    }
}
'@
Add-Type $code
[Win32.Wallpaper]::SetWallpaper($imgPath)

Write-Host "[$(Get-Date -Format t)] INFO: Starting Docker Desktop" -ForegroundColor Green
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes. Enjoy the Agora experience!" -ForegroundColor Green
Write-Host

Stop-Transcript