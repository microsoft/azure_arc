# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"

#############################################################
# Initialize the environment
#############################################################
$AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
$githubAccount = $env:githubAccount
$githubBranch = $env:githubBranch
$resourceGroup = $env:resourceGroup
$azureLocation = $env:azureLocation
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$adminUsername = $env:adminUsername

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

#############################################################
# Install Windows Terminal, WSL2, and Ubuntu
#############################################################
Write-Header "Installing Windows Terminal, WSL2 and Ubuntu"
If ($PSVersionTable.PSVersion.Major -ge 7){ Write-Error "This script needs be run by version of PowerShell prior to 7.0" }
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

# Install WSL latest kernel update
msiexec /i "$AgToolsDir\wsl_update_x64.msi" /qn

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Add-AppxPackage -Path $framworkPkgPath
Add-AppxPackage -Path $msiPath
Add-AppxPackage -Path "$AgToolsDir\Ubuntu.appx"

# Setting WSL environment variables
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + ";C:\Users\$adminUsername\Ubuntu", "User")

# Initializing the wsl ubuntu app without requiring user input
$ubuntu_path="c:/users/$adminUsername/AppData/Local/Microsoft/WindowsApps/ubuntu"
Invoke-Expression -Command "$ubuntu_path install --root"

# Cleanup
Remove-Item $downloadDir -Recurse -Force

#############################################################
# Install Docker Desktop
#############################################################
Write-Header "Installing Docker Dekstop"
# Download and Install Docker Desktop
$arguments = 'install --quiet --accept-license'
Start-Process "$AgToolsDir\DockerDesktopInstaller.exe" -Wait -ArgumentList $arguments
Get-ChildItem "$env:USERPROFILE\Desktop\Docker Desktop.lnk" | Remove-Item -Confirm:$false
Start-Service com.docker.service

##############################################################
# Setup Azure CLI
##############################################################
Write-Header "Set up Az CLI"
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Output "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
Write-Output "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
foreach ($extension in $AgConfig.AzCLIExtensions) {
    az extension add --name $extension --system
}
az -v

##############################################################
# Setup Azure PowerShell and register providers
##############################################################
Write-Header "Az PowerShell Login"
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal
$subscriptionId = (Get-AzSubscription).Id

# Install PowerShell modules
Write-Header "Installing PowerShell modules"
foreach ($module in $AgConfig.PowerShellModules) {
    Install-Module -Name $module -Force
}

# Register Azure providers
Write-Header "Registering Providers"
foreach ($provider in $AgConfig.AzureProviders) {
    Register-AzResourceProvider -ProviderNamespace $provider
}

##############################################################
# Configure L1 virtualization infrastructure
##############################################################
$password = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($AgConfig.L1Username, $password)

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
$kubeFolder = "$env:USERPROFILE\.kube"
New-Item -ItemType Directory $kubeFolder -Force
New-SmbShare -Name "kube" -Path "$env:USERPROFILE\.kube" -FullAccess "Everyone"

# Enable Enhanced Session Mode on Host
Write-Host "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + $AgConfig.L1SwitchName + ")")).ifIndex
New-NetIPAddress -IPAddress $AgConfig.L1DefaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex
New-NetNat -Name $AgConfig.L1SwitchName -InternalIPInterfaceAddressPrefix $AgConfig.L1NatSubnetPrefix

############################################
# Deploying the nested L1 virtual machines 
############################################
Write-Host "Fetching VM images" -ForegroundColor Yellow
$sasUrl = 'https://jsvhds.blob.core.windows.net/agora/contoso-supermarket-w11/*?si=Agora-RL&spr=https&sv=2021-12-02&sr=c&sig=Afl5LPMp5EsQWrFU1bh7ktTsxhtk0QcurW0NVU%2FD76k%3D'
Write-Host "Downloading nested VMs VHDX files. This can take some time, hold tight..." -ForegroundColor Yellow
azcopy cp $sasUrl $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR

# Create an array of VHDX file paths in the the VHDX target folder
$vhdxPaths = Get-ChildItem $AgConfig.AgDirectories["AgVHDXDir"] -Filter *.vhdx | Select-Object -ExpandProperty FullName

# consider diff disks here and answer files
# Loop through each VHDX file and create a VM
foreach ($vhdxPath in $vhdxPaths) {
    # Extract the VM name from the file name
    $VMName = [System.IO.Path]::GetFileNameWithoutExtension($vhdxPath)

    # Get the virtual hard disk object from the VHDX file
    $vhd = Get-VHD -Path $vhdxPath

    # Create new diff disks
    # Add this tomorrow

    # Create a new virtual machine and attach the existing virtual hard disk
    Write-Host "Create $VMName virtual machine" -ForegroundColor Green
    New-VM -Name $VMName `
        -MemoryStartupBytes $AgConfig.L1VMMemory `
        -BootDevice VHD `
        -VHDPath $vhd.Path `
        -Generation 2 `
        -Switch $AgConfig.L1SwitchName
    
    # Set up the virtual machine before coping all AKS Edge Essentials automation files
    Set-VMProcessor -VMName $VMName `
        -Count $AgConfig.L1VMNumVCPU `
        -ExposeVirtualizationExtensions $true
    
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing On
    Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
      
    # Create virtual machine snapshot and start the virtual machine
    Checkpoint-VM -Name $VMName -SnapshotName "Base"
    Start-Sleep -Seconds 5
    Start-VM -Name $VMName
}

Start-Sleep -Seconds 15

########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap #
########################################################################

# Create an array with VM names    
$VMnames = (Get-VM).Name

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Set time zone to UTC
    Set-TimeZone -Id "UTC"
    
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure #
    ###########################################

    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    $kubeFolder = "$env:USERPROFILE\.kube"

    # Set up an array of folders
    $folders = @($logsFolder, $kubeFolder)

    # Loop through each folder and create it
    foreach ($Folder in $folders) {
        New-Item -ItemType Directory $Folder -Force
    }
}

$githubAccount = $env:githubAccount
$githubBranch = $env:githubBranch
$resourceGroup = $env:resourceGroup
$azureLocation = $env:azureLocation
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$subscriptionId = (Get-AzSubscription).Id
Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Start logging
    $ProgressPreference = "SilentlyContinue"
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    Start-Transcript -Path $logsFolder\AKSEEBootstrap.log
    $AgConfig = $using:AgConfig

    ##########################################
    # Deploying AKS Edge Essentials clusters #
    ##########################################
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"

    # Assigning network adapter IP address
    $NetIPAddress = $AgConfig.SiteConfig[$env:COMPUTERNAME].NetIPAddress
    $DefaultGateway = $AgConfig.SiteConfig[$env:COMPUTERNAME].DefaultGateway
    $PrefixLength = $AgConfig.SiteConfig[$env:COMPUTERNAME].PrefixLength
    $DNSClientServerAddress = $AgConfig.SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress

    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress

    # Validating internet connectivity
    $pingResult = Test-Connection google.com -Count 1 -ErrorAction SilentlyContinue
    if ($pingResult) {
        # Internet connection is available
        Write-Host "Internet connection is available" -ForegroundColor Green
    }
    else {
        # Wait 5 seconds and try again
        Start-Sleep -Seconds 5
        $pingResult = Test-Connection google.com -Count 1 -ErrorAction SilentlyContinue
        if ($pingResult) {
            # Internet connection is available after waiting
            Write-Host "Internet connection is available after waiting" -ForegroundColor Green
        }
        else {
            # Wait another 5 seconds and try again
            Start-Sleep -Seconds 5
            $pingResult = Test-Connection google.com -Count 1 -ErrorAction SilentlyContinue
            if ($pingResult) {
                # Internet connection is available after waiting again
                Write-Host "Internet connection is available after waiting again" -ForegroundColor Green
            }
            else {
                # Internet connection is still not available
                Write-Host "Error: No internet connection" -ForegroundColor Red
            }
        }
    }
    Write-Host

    # Fetching latest AKS Edge Essentials msi file
    Write-Host "Fetching latest AKS Edge Essentials msi file" -ForegroundColor Yellow
    Invoke-WebRequest 'https://aka.ms/aks-edge/k3s-msi' -OutFile $deploymentFolder\AKSEEK3s.msi
    Write-Host

    # Fetching required GitHub artifacts from Jumpstart repository
    Write-Host "Fetching GitHub artifacts"
    $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
    $githubApiUrl = "https://api.github.com/repos/$using:githubAccount/$repoName/contents/azure_jumpstart_ag/artifacts/L1Files?ref=$using:githubBranch"
    $response = Invoke-RestMethod -Uri $githubApiUrl 
    $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
        
    $fileUrls | ForEach-Object {
        $fileName = $_.Substring($_.LastIndexOf("/") + 1)
        $outputFile = Join-Path $deploymentFolder $fileName
        Invoke-WebRequest -Uri $_ -OutFile $outputFile
    }

    # Setting up replacment parameters for AKS Edge Essentials config json file
    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $replacementParams = @{
        "ServiceIPRangeStart-null"    = $AgConfig.SiteConfig[$env:COMPUTERNAME].ServiceIPRangeStart
        "1000"                        = $AgConfig.SiteConfig[$env:COMPUTERNAME].ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $AgConfig.SiteConfig[$env:COMPUTERNAME].ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $AgConfig.SiteConfig[$env:COMPUTERNAME].DefaultGateway
        "2000"                        = $AgConfig.SiteConfig[$env:COMPUTERNAME].PrefixLength
        "DnsServer-null"              = $AgConfig.SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $AgConfig.SiteConfig[$env:COMPUTERNAME].LinuxNodeIp4Address
        "ClusterName-null"            = $AgConfig.SiteConfig[$env:COMPUTERNAME].ArcClusterName
        "Location-null"               = $using:azureLocation
        "ResourceGroupName-null"      = $using:resourceGroup
        "SubscriptionId-null"         = $using:subscriptionId
        "TenantId-null"               = $using:spnTenantId
        "ClientId-null"               = $using:spnClientId
        "ClientSecret-null"           = $using:spnClientSecret
    }

    # Preparing AKS Edge Essentials config json file
    $content = Get-Content $AKSEEConfigFilePath
    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }
    Set-Content "$deploymentFolder\Config.json" -Value $content
}

# Rebooting all L1 virtual machines
foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Invoke-Command -Session $Session -ScriptBlock { Restart-Computer -Force -Confirm:$false }
    Remove-PSSession $Session
}

# Monitor until the kubeconfig files are detected and copied over
$elapsedTime = Measure-Command {
    foreach ($VMName in $VMNames) {
        $path = "C:\Users\Administrator\.kube\config-" + $VMName.ToLower()
        $user = $AgConfig.L1Username
        [securestring]$secStringPassword = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($user, $secStringPassword)
        Start-Sleep 5
        while (!(Invoke-Command -VMName $VMName -Credential $credential -ScriptBlock { Test-Path $using:path })) { 
            Start-Sleep 30
            Write-Host "Waiting for kubeconfig files" 
        }
        
        Write-Host "Got a kubeconfig - copying over config-$VMName" -ForegroundColor DarkGreen
        $destinationPath = $env:USERPROFILE + "\.kube\config-" + $VMName
        $s = New-PSSession -VMName $VMName -Credential $credential
        Copy-Item -FromSession $s -Path $path -Destination $destinationPath
    }
}
# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "Waiting on files took $($elapsedTime.TotalSeconds) seconds" -ForegroundColor Blue

# Set the names of the kubeconfig files you're looking for on the L0 virtual machine
$kubeconfig1 = "config-seattle"
$kubeconfig2 = "config-chicago"
$kubeconfig3 = "config-akseedev"

# Merging kubeconfig files on the L0 vistual machine
Write-Host "All three files are present. Merging kubeconfig files." -ForegroundColor Green
$env:KUBECONFIG = "$env:USERPROFILE\.kube\$kubeconfig1;$env:USERPROFILE\.kube\$kubeconfig2;$env:USERPROFILE\.kube\$kubeconfig3"
kubectl config view --merge --flatten > "$env:USERPROFILE\.kube\config-raw"
kubectl config get-clusters --kubeconfig="$env:USERPROFILE\.kube\config-raw"
Rename-Item -Path "$env:USERPROFILE\.kube\config-raw" -NewName "$env:USERPROFILE\.kube\config"
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config"

# Print a message indicating that the merge is complete
Write-Host
Write-Host "kubeconfig files merged successfully." -ForegroundColor Green

# Validate context switching using kubectx & kubectl
Write-Host
kubectx seattle
kubectl get nodes -o wide

Write-Host
kubectx chicago
kubectl get nodes -o wide

Write-Host
kubectx akseedev
kubectl get nodes -o wide

#####################################################################
### INTERNAL NOTE: Add Logic for Arc-enabling the clusters
#####################################################################

Write-Header "Connect AKS Edge clusters to Azure with Azure Arc"
Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Install prerequisites
    $ProgressPreference = "SilentlyContinue"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop  
    Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop 
    Install-Module Az.ConnectedKubernetes -Repository PSGallery -Force -AllowClobber -ErrorAction Stop

    Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.6.3-windows-amd64.zip" -OutFile ".\helm-v3.6.3-windows-amd64.zip"
    Expand-Archive "helm-v3.6.3-windows-amd64.zip" C:\helm
    $env:Path = "C:\helm\windows-amd64;$env:Path"
    [Environment]::SetEnvironmentVariable('Path', $env:Path)

    # Connect to Arc
    $deploymentPath = "C:\Deployment\config.json"
    Connect-AksEdgeArc -JsonConfigFilePath $deploymentPath
}

##############################################################
# Setup Azure Container registry on cloud AKS environments
##############################################################
# az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksProdClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksDevClusterName --admin

# kubectx aksProd="$Env:aksProdClusterName-admin"
kubectx aksDev="$Env:aksDevClusterName-admin"

# Attach ACRs to AKS clusters
Write-Header "Attaching ACRs to AKS clusters"
# az aks update -n $Env:aksProdClusterName -g $Env:resourceGroup --attach-acr $Env:acrNameProd
az aks update -n $Env:aksDevClusterName -g $Env:resourceGroup --attach-acr $Env:acrNameDev

##############################################################
# Cleanup
##############################################################
# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
$Env:AgLogsDir = $AgConfig.AgDirectories["AgLogsDir"]
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:AgLogsDir\LogsBundle-"$RandomString".zip $Env:AgLogsDir\*.log
}'

# Write-Header "Changing Wallpaper"
# $imgPath=$AgConfig.AgDirectories["AgDir"] + "\wallpaper.png"
# Add-Type $code 
# [Win32.Wallpaper]::SetWallpaper($imgPath)

Stop-Transcript