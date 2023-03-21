# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"

#############################################################
# Initialize the environment
#############################################################
$AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

#############################################################
# Install Windows Terminal
#############################################################
Write-Header "Installing Windows Terminal"
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

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Add-AppxPackage -Path $framworkPkgPath
Add-AppxPackage -Path $msiPath

# Cleanup
Remove-Item $downloadDir -Recurse -Force


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
New-SmbShare -Name "kube" -Path "$env:USERPROFILE\.kube" -FullAccess "Everyone"

# Enable Enhanced Session Mode on Host
Write-Host "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal
$ifIndex = (Get-NetAdapter -Name "vEthernet ($AgConfig.L1SwitchName)").ifIndex
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
        -Count 8 `
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

    # Start logging
    Start-Transcript -Path $logsFolder\AKSEEBootstrap.log

    ##########################################
    # Deploying AKS Edge Essentials clusters #
    ##########################################

    if ($env:COMPUTERNAME -eq "Seattle") {

        $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
        $logsFolder = "$deploymentFolder\Logs"
        $kubeFolder = "$env:USERPROFILE\.kube"

        # Assigning network adapter IP address
        $NetIPAddress = "172.20.1.2"
        $DefaultGateway = "172.20.1.1"
        $PrefixLength = "24"
        $DNSClientServerAddress = "168.63.129.16"

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

        ################################################################################################
        # Internal comment: Need to optimize the GitHub artifcats download to support $templateBaseUrl #
        ################################################################################################

        # Fetching required GitHub artifacts from Jumpstart repository
        Write-Host "Fetching GitHub artifacts"
        $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
        $githubApiUrl = "https://api.github.com/repos/$env:githubAccount/$repoName/contents/azure_jumpstart_ag/artifacts/L1Files?ref=$githubBranch"
        $response = Invoke-RestMethod -Uri $githubApiUrl 
        $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
            
        $fileUrls | ForEach-Object {
            $fileName = $_.Substring($_.LastIndexOf("/") + 1)
            $outputFile = Join-Path $deploymentFolder $fileName
            Invoke-WebRequest -Uri $_ -OutFile $outputFile
        }
    }
    elseif ($env:COMPUTERNAME -eq "Chicago") {

        $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
        $logsFolder = "$deploymentFolder\Logs"
        $kubeFolder = "$env:USERPROFILE\.kube"

        # Assigning network adapter IP address            
        $NetIPAddress = "172.20.1.3"
        $DefaultGateway = "172.20.1.1"
        $PrefixLength = "24"
        $DNSClientServerAddress = "168.63.129.16"

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

        ################################################################################################
        # Internal comment: Need to optimize the GitHub artifcats download to support $templateBaseUrl #
        ################################################################################################

        # Fetching required GitHub artifacts from Jumpstart repository
        Write-Host "Fetching GitHub artifacts"
        $repoOwner = "likamrat" # While testing, change to your GitHub user account
        $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
        $branchName = "aksee_bootstrap" # While testing, change to your GitHub fork's repository branch name
        $githubApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents/azure_jumpstart_ag/artifacts/L1Files?ref=$branchName"
        $response = Invoke-RestMethod -Uri $githubApiUrl 
        $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
            
        $fileUrls | ForEach-Object {
            $fileName = $_.Substring($_.LastIndexOf("/") + 1)
            $outputFile = Join-Path $deploymentFolder $fileName
            Invoke-WebRequest -Uri $_ -OutFile $outputFile
        }
    }
    elseif ($env:COMPUTERNAME -eq "AKSEEDev") {

        $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
        $logsFolder = "$deploymentFolder\Logs"
        $kubeFolder = "$env:USERPROFILE\.kube"

        # Assigning network adapter IP address
        $NetIPAddress = "172.20.1.4"
        $DefaultGateway = "172.20.1.1"
        $PrefixLength = "24"
        $DNSClientServerAddress = "168.63.129.16"

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

        ################################################################################################
        # Internal comment: Need to optimize the GitHub artifcats download to support $templateBaseUrl #
        ################################################################################################

        # Fetching required GitHub artifacts from Jumpstart repository
        Write-Host "Fetching GitHub artifacts"
        $repoOwner = $env:githubAccount # While testing, change to your GitHub user account
        $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
        $branchName = $env:githubBranch # While testing, change to your GitHub fork's repository branch name
        $githubApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents/azure_jumpstart_ag/artifacts/L1Files?ref=$branchName"
        $response = Invoke-RestMethod -Uri $githubApiUrl 
        $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
            
        $fileUrls | ForEach-Object {
            $fileName = $_.Substring($_.LastIndexOf("/") + 1)
            $outputFile = Join-Path $deploymentFolder $fileName
            Invoke-WebRequest -Uri $_ -OutFile $outputFile
        }
    }
} 


# Rebooting all L1 virtual machines
foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Invoke-Command -Session $Session -ScriptBlock { Restart-Computer -Force -Confirm:$false }
    Remove-PSSession $Session
}

# Set the names of the kubeconfig files you're looking for on the L0 virtual machine
$kubeconfig1 = "config-seattle"
$kubeconfig2 = "config-chicago"
$kubeconfig3 = "config-akseedev"

$fileNames = @($kubeconfig1, $kubeconfig2, $kubeconfig3)

# Start monitoring the .kube folder for the files on the L0 virtual machine
$elapsedTime = Measure-Command {
    while ($true) {
        $files = Get-ChildItem $kubeFolder -ErrorAction SilentlyContinue | Where-Object { $fileNames -contains $_.Name }

        if ($files.Count -eq 3) {
            Write-Host "Found all 3 kubeconfig files!" -ForegroundColor Green
            break
        }
        # Wait before checking again
        Start-Sleep -Seconds 30
        Write-Host "Waiting for kubeconfig files. Checking every 30 seconds..." -ForegroundColor Yellow
    }
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "Waiting on files took $($elapsedTime.TotalSeconds) seconds" -ForegroundColor Blue

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

##############################################################
# Setup Azure Container registry on cloud AKS environments
##############################################################
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksProdClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksDevClusterName --admin

kubectx aksProd="$Env:aksProdClusterName-admin"
kubectx aksDev="$Env:aksDevClusterName-admin"

# Attach ACRs to AKS clusters
Write-Header "Attaching ACRs to AKS clusters"
az aks update -n $Env:aksProdClusterName -g $Env:resourceGroup --attach-acr $Env:acrNameProd
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
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:AgLogsDir\LogsBundle-"$RandomString".zip $Env:HCIBoxLogsDir\*.log
}'

Write-Header "Changing Wallpaper"
$imgPath=$AgConfig.AgDirectories["AgDir"] + "\wallpaper.png"
Add-Type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

Stop-Transcript