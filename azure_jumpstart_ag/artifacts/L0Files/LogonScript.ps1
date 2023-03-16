# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

###########################################
# Preparing environment folders structure #
###########################################

$ProgressPreference = "SilentlyContinue"

# Folders to be created
$deploymentFolder = "C:\Deployment"
$logsFolder = "$deploymentFolder\Logs"
$vhdxFolder = "$deploymentFolder\VHDX"
$L1FilesFolder = "$deploymentFolder\L1Files"
$kubeFolder = "$env:USERPROFILE\.kube"

# Set up an array of folders
$folders = @($deploymentFolder, $logsFolder, $vhdxFolder, $L1FilesFolder, $kubeFolder)

# Loop through each folder and create it
foreach ($Folder in $folders) {
    New-Item -ItemType Directory $Folder -Force
}

# Parameterizing the L1 nested virtual machine username and password required for the invoke commands (Invoke-Command)
$HVVMUsername = "Administrator"
$HVVMPassword = ConvertTo-SecureString "Agora123!!" -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($HVVMUsername, $HVVMPassword)

# Parameterizing Network-related
$defaultGateway = "172.20.1.1"
$switchName = "AKS-Int"

# Start logging
Start-Transcript -Path "$logsFolder\LogonScript.log"

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
New-SmbShare -Name "kube" -Path $kubeFolder -FullAccess "Everyone"

# Enable Enhanced Session Mode on Host
Write-Host "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $switchName -SwitchType Internal
$ifIndex = (Get-NetAdapter -Name "vEthernet ($switchName)").ifIndex
New-NetIPAddress -IPAddress $defaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex
New-NetNat -Name $switchName -InternalIPInterfaceAddressPrefix "172.20.1.0/24"

############################################
# Deploying the nested L1 virtual machines #
############################################

Write-Host "Fetching VM images" -ForegroundColor Yellow
$sasUrl = 'https://jsvhds.blob.core.windows.net/agora/contoso-supermarket-w11/*?si=Agora-RL&spr=https&sv=2021-12-02&sr=c&sig=Afl5LPMp5EsQWrFU1bh7ktTsxhtk0QcurW0NVU%2FD76k%3D'

Write-Host "Downloading nested VMs VHDX files. This can take some time, hold tight..." -ForegroundColor Yellow
azcopy cp $sasUrl $vhdxFolder --recursive=true --check-length=false --log-level=ERROR

# Create an array of VHDX file paths in the the VHDX target folder
$vhdxPaths = Get-ChildItem $vhdxFolder -Filter *.vhdx | Select-Object -ExpandProperty FullName

# Loop through each VHDX file and create a VM
foreach ($vhdxPath in $vhdxPaths) {
    # Extract the VM name from the file name
    $VMName = [System.IO.Path]::GetFileNameWithoutExtension($vhdxPath)

    # Get the virtual hard disk object from the VHDX file
    $vhd = Get-VHD -Path $vhdxPath

    # Create a new virtual machine and attach the existing virtual hard disk
    Write-Host "Create $VMName virtual machine" -ForegroundColor Green
    New-VM -Name $VMName `
        -MemoryStartupBytes 24GB `
        -BootDevice VHD `
        -VHDPath $vhd.Path `
        -Generation 2 `
        -Switch $switchName
    
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

foreach ($VMName in $VMNames) {
    Invoke-Command -VMName $VMName -ScriptBlock {
                
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

        # Parameterizing the host, L0 username and password Required for the shared drive functionality (New-PSDrive)
        $HVHostUsername = "arcdemo"
        $HVHostPassword = ConvertTo-SecureString "ArcPassword123!!" -AsPlainText -Force

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
    } -Credential $Credentials
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
