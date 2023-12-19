# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"

#############################################################
# Initialize the environment
#############################################################
Start-Transcript -Path "C:\Temp\LogonScript.log"

$githubAccount = $env:githubAccount
$githubBranch = $env:githubBranch
$resourceGroup = $env:resourceGroup
$azureLocation = $env:azureLocation
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$vhdxUri = "https://jsvhds.blob.core.windows.net/scenarios/prod/JSW11IoTBase.vhdx?sp=r&st=2023-05-09T12:36:32Z&se=2033-05-09T20:36:32Z&spr=https&sv=2022-11-02&sr=b&sig=xFROrqGkKDIdrXqiAMLZGLEwTMToOWoNNDMVz1zvPMc%3D"
$hypervVMUser = "Administrator"
$hypervVMPassword = "JS123!!"
$kubernetesDistribution = $env:kubernetesDistribution
$aksEEReleasesUrl = "https://api.github.com/repos/Azure/AKS-Edge/releases"
$L1VMMemoryStartupInMB = $env:L1VMMemoryStartupInMB
$AKSEEMemoryInMB = $env:AKSEEMemoryInMB

Write-Header "Executing LogonScript.ps1"

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

##############################################################
# Setup Azure CLI
##############################################################
Write-Host "INFO: Configuring Azure CLI" -ForegroundColor Gray
$cliDir = New-Item -Path "C:\Logs\.cli\" -Name ".aks-ee-full" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

$AzCLIExtensions = @(
    'k8s-extension',
    'k8s-configuration'
)

# Making extension install dynamic
if ($AzCLIExtensions.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing Azure CLI extensions: " ($AzCLIExtensions -join ', ') -ForegroundColor Gray
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    # Installing Azure CLI extensions
    foreach ($extension in $AzCLIExtensions) {
        az extension add --name $extension --system --only-show-errors
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Az CLI configuration complete!" -ForegroundColor Green
Write-Host

##############################################################
# Setup Azure PowerShell and register providers
##############################################################
Write-Host "INFO: Logging into Azure PowerShell using the service principal and secret provided at deployment." -ForegroundColor Gray
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal
$subscriptionId = (Get-AzSubscription).Id
# Install PowerShell modules
$PowerShellModules = @(
    'Az.ConnectedKubernetes'
)
if ($PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($PowerShellModules -join ', ') -ForegroundColor Gray
    foreach ($module in $AgConfig.PowerShellModules) {
        Install-Module -Name $module -Force
    }
}

# Register Azure providers
$AzureProviders = @(
    "Microsoft.Kubernetes",
    "Microsoft.KubernetesConfiguration",
    "Microsoft.ExtendedLocation"
)
if ($AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

##############################################################
# Configure L1 virtualization infrastructure
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure" -ForegroundColor DarkGreen
$password = ConvertTo-SecureString $hypervVMPassword -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($hypervVMUser, $password)

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
$kubeFolder = "$env:USERPROFILE\.kube"
New-Item -ItemType Directory $kubeFolder -Force
New-SmbShare -Name "kube" -Path "$env:USERPROFILE\.kube" -FullAccess "Everyone"

# Enable Enhanced Session Mode on Host
Write-Host "INFO: Enabling Enhanced Session Mode on Hyper-V host" -ForegroundColor Gray
Set-VMHost -EnableEnhancedSessionMode $true

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name "AKS-Int" -SwitchType Internal
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + "AKS-Int" + ")")).ifIndex
New-NetIPAddress -IPAddress "172.20.1.1" -PrefixLength 24 -InterfaceIndex $ifIndex
New-NetNat -Name "AKS-Int" -InternalIPInterfaceAddressPrefix "172.20.1.0/24"

############################################
# Deploying the nested L1 virtual machines 
############################################
Write-Host "INFO: Fetching Windows 11 IoT Enterprise VM images from Azure storage. This may take a few minutes." -ForegroundColor Green
azcopy cp $vhdxUri "C:\VHDX\base.vhdx" --recursive=true --check-length=false --log-level=ERROR

if ($env:kubernetesDistribution -eq "k8s") {
    $networkplugin = "calico"
} else {
    $networkplugin = "flannel"
}

# Random guid
$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$arcResourceName = "$env:resourceGroup-$guid"

# AKS EE configuration
$SiteConfig = @{
    Node1 = @{
        Networkplugin = "$networkplugin"
        ArcClusterName = "$arcResourceName"
        NetIPAddress = "172.20.1.2"
        DefaultGateway = "172.20.1.1"
        PrefixLength = "24"
        DNSClientServerAddress = "168.63.129.16"
        ServiceIPRangeStart = "172.20.1.31"
        ServiceIPRangeSize = "10"
        ControlPlaneEndpointIp = "172.20.1.21"
        LinuxNodeIp4Address = "172.20.1.11"
        Subnet = "172.20.1.0/24"
        FriendlyName = "Node1"
        IsProduction = $true
        Type = "AKSEE"
    }
    Node2 = @{
        Networkplugin = "$networkplugin"
        NetIPAddress = "172.20.1.3"
        DefaultGateway = "172.20.1.1"
        PrefixLength = "24"
        DNSClientServerAddress = "168.63.129.16"
        ServiceIPRangeStart = "172.20.1.71"
        ServiceIPRangeSize = "10"
        ControlPlaneEndpointIp = "172.20.1.21"
        LinuxNodeIp4Address = "172.20.1.51"
        Subnet = "172.20.1.0/24"
        FriendlyName = "Node2"
        IsProduction = $true
        Type = "AKSEE"
    }
}

# Create two VMs from the base VHDX image
$vhdxPath = Get-ChildItem "C:\VHDX" -Filter *.vhdx | Select-Object -ExpandProperty FullName
foreach ($site in $SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        # Create diff disks for each site host
        Write-Host "INFO: Creating differencing disk for site $($site.Name)" -ForegroundColor Gray
        $vhd = New-VHD -ParentPath $vhdxPath -Path "C:\VHDX\$($site.Name)DiffDisk.vhdx" -Differencing
        
        # Create a new virtual machine and attach the existing virtual hard disk
        Write-Host "INFO: Creating and configuring $($site.Name) virtual machine." -ForegroundColor Gray
        New-VM -Name $site.Name `
            -MemoryStartupBytes  (([uint64]($L1VMMemoryStartupInMB))*1024*1024) `
            -BootDevice VHD `
            -VHDPath $vhd.Path `
            -Generation 2 `
            -Switch "AKS-Int"
        
        # Set up the virtual machine before coping all AKS Edge Essentials automation files
        Set-VMProcessor -VMName $site.Name `
            -Count 4 `
            -ExposeVirtualizationExtensions $true

        Get-VMNetworkAdapter -VMName $site.Name | Set-VMNetworkAdapter -MacAddressSpoofing On
        Enable-VMIntegrationService -VMName $site.Name -Name "Guest Service Interface"
  
        # Start the virtual machine
        Start-VM -Name $site.Name
    }
}

Start-Sleep -Seconds 20

########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap 
########################################################################
foreach ($site in $SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        Write-Host "INFO: Renaming computer name of $($site.Name)" -ForegroundColor Gray
        Invoke-Command -VMName $site.Name -Credential $Credentials -ScriptBlock {
            $site = $using:site
            (gwmi win32_computersystem).Rename($site.Name)
            Restart-Computer
        }
    }
}
# Create an array with VM names    
$VMnames = (Get-VM).Name

Start-Sleep -Seconds 60 # Give some time after restart

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Set time zone to UTC
    Set-TimeZone -Id "UTC"
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure 
    ###########################################
    Write-Host "INFO: Preparing folder structure on $hostname." -ForegroundColor Gray
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

$subscriptionId = (Get-AzSubscription).Id
Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Start logging
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    Start-Transcript -Path $logsFolder\AKSEEBootstrap.log
    $SiteConfig = $using:SiteConfig

    ##########################################
    # Deploying AKS Edge Essentials clusters 
    ##########################################
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"

    # Assigning network adapter IP address
    $NetIPAddress = $SiteConfig[$env:COMPUTERNAME].NetIPAddress
    $DefaultGateway = $SiteConfig[$env:COMPUTERNAME].DefaultGateway
    $PrefixLength = $SiteConfig[$env:COMPUTERNAME].PrefixLength
    $DNSClientServerAddress = $SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
    Write-Host "INFO: Configuring networking interface on $hostname with IP address $NetIPAddress." -ForegroundColor Gray
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress

    ###########################################
    # Validating internet connectivity
    ###########################################
    $timeElapsed = 0
    do {
        Write-Host "INFO: Waiting for internet connection to be healthy on $hostname."
        Start-Sleep -Seconds 5
        $timeElapsed = $timeElapsed + 10
    } until ((Test-Connection bing.com -Count 1 -ErrorAction SilentlyContinue) -or ($timeElapsed -eq 60))
      
    # Fetching latest AKS Edge Essentials msi file
    Write-Host "INFO: Fetching latest AKS Edge Essentials install file on $hostname." -ForegroundColor Gray

    if ($using:kubernetesDistribution -eq "k8s") {
        Invoke-WebRequest "https://aka.ms/aks-edge/${using:kubernetesDistribution}-msi" -OutFile $deploymentFolder\AKSEEK8s.msi
    } else {
        Invoke-WebRequest "https://aka.ms/aks-edge/${using:kubernetesDistribution}-msi" -OutFile $deploymentFolder\AKSEEK3s.msi
    }

    # Fetching required GitHub artifacts from Jumpstart repository
    Write-Host "Fetching GitHub artifacts"
    $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
    $githubApiUrl = "https://api.github.com/repos/$using:githubAccount/$repoName/contents/azure_arc_k8s_jumpstart/aks_hybrid/aks_edge_essentials_full/bicep_template/artifacts/L1Files?ref=$using:githubBranch"
    $response = Invoke-RestMethod -Uri $githubApiUrl
    $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
    $fileUrls | ForEach-Object {
        $fileName = $_.Substring($_.LastIndexOf("/") + 1)
        $outputFile = Join-Path $deploymentFolder $fileName
        Invoke-RestMethod -Uri $_ -OutFile $outputFile
    }
}

Write-Host "Fetching the latest AKS Edge Essentials release."
$latestReleaseTag = (Invoke-WebRequest $aksEEReleasesUrl | ConvertFrom-Json)[0].tag_name

$AKSEEReleaseDownloadUrl = "https://github.com/Azure/AKS-Edge/archive/refs/tags/$latestReleaseTag.zip"
$output = Join-Path "C:\temp" "$latestReleaseTag.zip"
Invoke-WebRequest $AKSEEReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath "C:\temp" -Force
$AKSEEReleaseConfigFilePath = "C:\temp\AKS-Edge-$latestReleaseTag\tools\aksedge-config.json"
$jsonContent = Get-Content -Raw -Path $AKSEEReleaseConfigFilePath | ConvertFrom-Json
$schemaVersion = $jsonContent.SchemaVersion
# Clean up the downloaded release files
Remove-Item -Path $output -Force
Remove-Item -Path "C:\temp\AKS-Edge-$latestReleaseTag" -Force -Recurse

###############################################################################
# Setting up replacment parameters for AKS Edge Essentials config json file
###############################################################################
Invoke-Command -VMName "Node1" -Credential $Credentials -ScriptBlock {
    Write-Host "INFO: Building AKS Edge Essentials config json file on Node1."
    $SiteConfig = $using:SiteConfig
    $deploymentFolder = "C:\Deployment"
    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $replacementParams = @{
        "SchemaVersion-null"          = $using:schemaVersion
        "NetworkPlugin-null"          = $SiteConfig[$env:COMPUTERNAME].Networkplugin
        "ServiceIPRangeStart-null"    = $SiteConfig[$env:COMPUTERNAME].ServiceIPRangeStart
        "1000"                        = $SiteConfig[$env:COMPUTERNAME].ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $SiteConfig[$env:COMPUTERNAME].ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $SiteConfig[$env:COMPUTERNAME].DefaultGateway
        "2000"                        = $SiteConfig[$env:COMPUTERNAME].PrefixLength
        "DnsServer-null"              = $SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $SiteConfig[$env:COMPUTERNAME].LinuxNodeIp4Address
        "ClusterName-null"            = $SiteConfig[$env:COMPUTERNAME].ArcClusterName
        "Location-null"               = $using:azureLocation
        "ResourceGroupName-null"      = $using:resourceGroup
        "SubscriptionId-null"         = $using:subscriptionId
        "TenantId-null"               = $using:spnTenantId
        "ClientId-null"               = $using:spnClientId
        "ClientSecret-null"           = $using:spnClientSecret
        "MemoryInMB-null"             = $using:AKSEEMemoryInMB
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

Write-Host "[$(Get-Date -Format t)] INFO: Installing AKS Edge Essentials" -ForegroundColor DarkGreen
$Session = New-PSSession -VMName Node1 -Credential $Credentials
Write-Host "INFO: Rebooting Node1." -ForegroundColor Gray
Invoke-Command -Session $Session -ScriptBlock { 
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $env:USERNAME -Password $using:hypervVMPassword -RunLevel Highest
    Restart-Computer -Force -Confirm:$false
}
Remove-PSSession $Session

Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete (Node1)." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.

#####################################################################
# Monitor until the kubeconfig files are detected and copied over
#####################################################################
$elapsedTime = Measure-Command {
    $path = "C:\Users\Administrator\.kube\config-node1"
    $user = "Administrator"
    [securestring]$secStringPassword = ConvertTo-SecureString 'JS123!!' -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($user, $secStringPassword)
    while (!(Invoke-Command -VMName "Node1" -Credential $Credential -ScriptBlock { Test-Path $using:path })) { 
        Start-Sleep 30
        Write-Host "INFO: Waiting for AKS Edge Essentials kubeconfig to be available on Node1." -ForegroundColor Gray
    }
    Write-Host "INFO: Node1's kubeconfig is ready - copying over config-node1" -ForegroundColor DarkGreen
    Start-Sleep -Seconds 60
    $destinationPath = $env:USERPROFILE + "\.kube\config"
    $s = New-PSSession -VMName Node1 -Credential $Credential
    Copy-Item -FromSession $s -Path $path -Destination $destinationPath
    Remove-PSSession $s
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "INFO: Waiting on kubeconfig files took $($elapsedTime.TotalSeconds) seconds." -ForegroundColor Gray

# Retrieve join
Invoke-Command -VMName "Node1" -Credential $Credentials -ScriptBlock {
    $path = "C:\Deployment\ScaleConfigJoin.json"
    New-AksEdgeScaleConfig -NodeType Linux -ScaleType AddMachine -LinuxNodeIp "172.20.1.51" -outFile $path
    Start-Sleep 5
    Write-Host "INFO: Node1's ScaleConfigJoin.json is ready" -ForegroundColor DarkGreen
}

$path = "C:\Deployment\ScaleConfigJoin.json"
$destinationPath = "C:\Temp\ScaleConfigJoin.json"
$s = New-PSSession -VMName Node1 -Credential $Credential
Copy-Item -FromSession $s -Path $path -Destination $destinationPath
Remove-PSSession $s

$parsed_json = Get-Content -Path "C:\Temp\ScaleConfigJoin.json" | ConvertFrom-Json
$ClusterJoinToken = $parsed_json.Join.ClusterJoinToken
$DiscoveryTokenHash = $parsed_json.Join.DiscoveryTokenHash
$ClusterId = $parsed_json.Join.ClusterId

Invoke-Command -VMName "Node2" -Credential $Credentials -ScriptBlock {
    # Setting up replacment parameters for AKS Edge Essentials config json file
    Write-Host "INFO: Building AKS Edge Essentials config json file on $hostname."
    $SiteConfig = $using:SiteConfig
    $deploymentFolder = "C:\Deployment"
    $AKSEEConfigFilePath = "$deploymentFolder\ScalableClusterAdd-${using:kubernetesDistribution}.json"
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    if ($using:kubernetesDistribution -eq "k8s") {
        $replacementParams = @{
            "SchemaVersion-null"          = $using:schemaVersion
            "NetworkPlugin-null"          = $SiteConfig[$env:COMPUTERNAME].Networkplugin
            "ClusterJoinToken-null"       = $using:ClusterJoinToken
            "DiscoveryTokenHash-null"     = $using:DiscoveryTokenHash
            "ClusterId-null"              = $using:ClusterId
            "1000"                        = $SiteConfig[$env:COMPUTERNAME].ServiceIPRangeSize
            "ControlPlaneEndpointIp-null" = $SiteConfig[$env:COMPUTERNAME].ControlPlaneEndpointIp
            "Ip4GatewayAddress-null"      = $SiteConfig[$env:COMPUTERNAME].DefaultGateway
            "2000"                        = $SiteConfig[$env:COMPUTERNAME].PrefixLength
            "DnsServer-null"              = $SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
            "Ethernet-Null"               = $AdapterName
            "Ip4Address-null"             = $SiteConfig[$env:COMPUTERNAME].LinuxNodeIp4Address
        }
    } else {
        $replacementParams = @{
            "SchemaVersion-null"          = $using:schemaVersion
            "NetworkPlugin-null"          = $SiteConfig[$env:COMPUTERNAME].Networkplugin
            "ClusterJoinToken-null"       = $using:ClusterJoinToken
            "ClusterId-null"              = $using:ClusterId
            "1000"                        = $SiteConfig[$env:COMPUTERNAME].ServiceIPRangeSize
            "ControlPlaneEndpointIp-null" = $SiteConfig[$env:COMPUTERNAME].ControlPlaneEndpointIp
            "Ip4GatewayAddress-null"      = $SiteConfig[$env:COMPUTERNAME].DefaultGateway
            "2000"                        = $SiteConfig[$env:COMPUTERNAME].PrefixLength
            "DnsServer-null"              = $SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
            "Ethernet-Null"               = $AdapterName
            "Ip4Address-null"             = $SiteConfig[$env:COMPUTERNAME].LinuxNodeIp4Address
        }
    }

    # Preparing AKS Edge Essentials config json file
    $content = Get-Content $AKSEEConfigFilePath
    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }
    Set-Content "$deploymentFolder\Config.json" -Value $content
}

$Session = New-PSSession -VMName Node2 -Credential $Credentials
Write-Host "INFO: Rebooting Node2." -ForegroundColor Gray
Invoke-Command -Session $Session -ScriptBlock { 
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $env:USERNAME -Password $using:hypervVMPassword -RunLevel Highest
    Restart-Computer -Force -Confirm:$false
}
Remove-PSSession $Session

Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete (Node2)." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.

#####################################################################
### Connect the AKS Edge Essentials clusters to Azure Arc
#####################################################################

Write-Header "Connecting AKS Edge cluster to Azure with Azure Arc"

$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -A; Start-Sleep -Seconds 5; Clear-Host } }

Invoke-Command -VMName "Node1" -Credential $Credentials -ScriptBlock {
    # Install prerequisites
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop  
    Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop 
    Install-Module Az.ConnectedKubernetes -Repository PSGallery -Force -AllowClobber -ErrorAction Stop

    # Connect to Arc
    $deploymentPath = "C:\Deployment\config.json"
    Write-Host "INFO: Arc-enabling $hostname AKS Edge Essentials cluster." -ForegroundColor Gray
    kubectl get svc
    Connect-AksEdgeArc -JsonConfigFilePath $deploymentPath
}
Write-Host "INFO: AKS Edge Essentials clusters have been registered with Azure Arc!" -ForegroundColor Green

# Get all the Azure Arc-enabled Kubernetes clusters in the resource group
$clusters = az resource list --resource-group $env:resourceGroup --resource-type "Microsoft.Kubernetes/connectedClusters" --query "[].id" --output tsv

# Loop through each cluster and tag it
$TagName = 'Project'
$TagValue = 'AKS_EE_Full'
foreach ($cluster in $clusters) {
    az resource tag --tags $TagName=$TagValue --ids $cluster
}

Write-Host "`n"
Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
Write-Host "`n"

# Deploying Azure log-analytics workspace
$arcClusterName = $SiteConfig["Node1"].ArcClusterName
$workspaceName = ($arcClusterName).ToLower()
$workspaceResourceId = az monitor log-analytics workspace create `
    --resource-group $resourceGroup `
    --workspace-name "$workspaceName-law" `
    --query id -o tsv

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "`n"
az k8s-extension create --name "azuremonitor-containers" `
    --cluster-name $arcClusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --extension-type Microsoft.AzureMonitor.Containers `
    --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId

#####################################################################
### Connect the Hyper-V VMs to Azure Arc
#####################################################################

## Azure Arc agent Installation
Write-Host "`n"
Write-Host "Onboarding the Hyper-V $VMnames to Azure Arc..."

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {

    # Download the package
    function download1() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi }
    download1

    # Install the package
    msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

    #Tag
    $clusterName = "$env:COMPUTERNAME-$using:kubernetesDistribution"

    # Run connect command
    & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --service-principal-id $using:spnClientId `
        --service-principal-secret $using:spnClientSecret `
        --resource-group $using:resourceGroup `
        --tenant-id $using:spnTenantId `
        --location $using:azureLocation `
        --subscription-id $using:subscriptionId `
        --tags "Project=jumpstart_azure_arc_servers" "AKSEE=$clusterName"`
        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
}

# Changing to Client VM wallpaper
$imgPath = "C:\Temp\wallpaper.png"
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

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5

Stop-Process -Name powershell -Force

Stop-Transcript
