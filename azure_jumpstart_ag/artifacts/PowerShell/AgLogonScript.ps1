# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"

#############################################################
# Initialize the environment
#############################################################
$AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
$AgIconsDir = $AgConfig.AgDirectories["AgIconDir"]
$AgAppsRepo = $AgConfig.AgDirectories["AgAppsRepo"]
$githubAccount = $env:githubAccount
$githubBranch = $env:githubBranch
$githubUser = $env:githubUser
$githubPat = $env:GITHUB_TOKEN
$resourceGroup = $env:resourceGroup
$azureLocation = $env:azureLocation
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$adminUsername = $env:adminUsername
$acrName = $Env:acrName.ToLower()
$cosmosDBName = $Env:cosmosDBName
$cosmosDBEndpoint = $Env:cosmosDBEndpoint
$templateBaseUrl = $env:templateBaseUrl
$appClonedRepo = "https://github.com/$githubUser/jumpstart-agora-apps"
$adxClusterName = $env:adxClusterName

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

##############################################################
# Setup Azure CLI
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/13)" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")

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

##############################################################
# Setup Azure PowerShell and register providers
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell. (Step 2/13)" -ForegroundColor DarkGreen
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
if ($Agconfig.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($AgConfig.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AgConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

##############################################################
# Configure Jumpstart AG Apps repository
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Forking and prepareing Apps repository locally (Step 3/13)" -ForegroundColor DarkGreen
Set-Location $AgAppsRepo
if ($githubUser -ne "microsoft") {
    git clone "https://$githubPat@github.com/$githubUser/jumpstart-agora-apps.git" $AgAppsRepo\jumpstart-agora-apps | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    Set-Location $AgAppsRepo\jumpstart-agora-apps
    Write-Host "[$(Get-Date -Format t)] INFO: Getting Cosmos DB access key" -ForegroundColor Gray 
    Write-Host "[$(Get-Date -Format t)] INFO: Adding GitHub secrets to apps fork" -ForegroundColor Gray
    gh api -X PUT /repos/$githubUser/jumpstart-agora-apps/actions/permissions/workflow -F can_approve_pull_request_reviews=true #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    gh secret set "SPN_CLIENT_ID" -b $spnClientID #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    gh secret set "SPN_CLIENT_SECRET" -b $spnClientSecret #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    gh secret set "ACR_NAME" -b $acrName #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    gh secret set "PAT_GITHUB" -b $githubPat #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    gh secret set "COSMOS_DB_ENDPOINT" -b $cosmosDBEndpoint #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    Write-Host "[$(Get-Date -Format t)] INFO: Creating GitHub branches to apps fork" -ForegroundColor Gray
    $branches = $AgConfig.GitBranches
    foreach ($branch in $branches) {
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$githubUser/jumpstart-agora-apps/branches/$branch"
            if ($response) {
                Write-Host "[$(Get-Date -Format t)] INFO: $branch branch already exists! Deleting and recreating the branch" -ForegroundColor Gray
                git push origin --delete $branch #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
                git checkout -b $branch #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
                git push origin $branch #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
            }
        }
        catch {
            Write-Host "[$(Get-Date -Format t)] INFO: Creating $branch branch" -ForegroundColor Gray
            git checkout -b $branch #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
            git push origin $branch #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
        }
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Switching to main branch" -ForegroundColor Gray
    git checkout dev #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Git.log")
    Write-Host "[$(Get-Date -Format t)] INFO: GitHub repo configuration complete!" -ForegroundColor Green
    Write-Host
}
else {
    Write-Host "[$(Get-Date -Format t)] ERROR: You have to fork the jumpstart-agora-apps repository!" -ForegroundColor Red
}

#####################################################################
# IotHub resources preperation
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating IoT resources (Step 4/13)" -ForegroundColor DarkGreen
if ($env:githubUser -ne "microsoft") {
    $IoTHubHostName = $env:iotHubHostName
    $IoTHubName = $IoTHubHostName.replace(".azure-devices.net", "")
    gh secret set "IOTHUB_HOSTNAME" -b $IoTHubHostName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\IoT.log")
    $sites = $AgConfig.SiteConfig.Values
    Write-Host "[$(Get-Date -Format t)] INFO: Create an IoT device for each site" -ForegroundColor Gray
    foreach ($site in $sites) {
        $deviceId = $site.FriendlyName
        az iot hub device-identity create --device-id $deviceId --edge-enabled --hub-name $IoTHubName --resource-group $resourceGroup | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\IoT.log")
        $deviceSASToken = $(az iot hub generate-sas-token --device-id $deviceId --hub-name $IoTHubName --resource-group $resourceGroup --duration (60 * 60 * 24 * 30) --query sas -o tsv) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\IoT.log")
        gh secret set "sas_token_$deviceId" -b $deviceSASToken #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\IoT.log")
    }
    Write-Host "[$(Get-Date -Format t)] INFO: IoT Hub configuration complete!" -ForegroundColor Green
    Write-Host
}
else {
    Write-Host "[$(Get-Date -Format t)] ERROR: You have to fork the jumpstart-agora-apps repository!" -ForegroundColor Red
}

<# THIS CODE IS TEMPORARY COMMENTED DUE TO IMPORT ISSUES WITH SPN.
#####################################################################
# Import dashboard reports into Azure Data Explorer
#####################################################################
# Get Azure Data Explorer URI
$adxEndPoint = (az kusto cluster show --name $adxClusterName --resource-group $resourceGroup --query "uri" -o tsv)

# Get access token to make REST API call to Azure Data Exploer Dashabord API. Replace double quotes surrounding acces token
$token = (az account get-access-token --scope "https://rtd-metadata.azurewebsites.net/user_impersonation openid profile offline_access" --query "accessToken") -replace "`"", ""

# Prepare authorization header with access token
$httpHeaders = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

# Make REST API call to the dashbord endpoint.
$restApi = "https://dashboards.kusto.windows.net/dashboards"

# Import orders dashboard report
$ordersDashboardBody = (Get-Content -Path .\adx-dashboard-orders-payload.json) -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint
$httpResponse = Invoke-WebRequest -Method Post -Uri $restApi -Body $ordersDashboardBody -Headers $httpHeaders
if ($httpResponse.StatusCode -ne 200){
    Write-Host "ERROR: Failed import orders dashboard report into Azure Data Explorer"
    Exit-PSSession
}

# Import IoT Sensor dashboard report
$iotSensorsDashboardBody = (Get-Content -Path .\adx-dashboard-iotsensor-payload.json) -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint
$httpResponse = Invoke-WebRequest -Method Post -Uri $restApi -Body $iotSensorsDashboardBody -Headers $httpHeaders
if ($httpResponse.StatusCode -ne 200){
    Write-Host "ERROR: Failed import IoT Sensor dashboard report into Azure Data Explorer"
    Exit-PSSession
}
#>

### BELOW IS AN ALTERNATIVE APPROACH TO IMPORT DASHBOARD USING README INSTRUCTIONS

$agDir = $AgConfig.AgDirectories["AgDir"]
$adxEndPoint = (az kusto cluster show --name $adxClusterName --resource-group $resourceGroup --query "uri" -o tsv --only-show-errors)
if ($null -ne $adxEndPoint -and $adxEndPoint -ne "") {
    $ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx-dashboard-orders-payload.json").Content -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
    Set-Content -Path "$agDir\adx-dashboard-orders-payload.json" -Value $ordersDashboardBody -Force -ErrorAction Ignore
    $iotSensorsDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx-dashboard-iotsensor-payload.json") -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
    Set-Content -Path "$agDir\adx-dashboard-iotsensor-payload.json" -Value $iotSensorsDashboardBody -Force -ErrorAction Ignore
}
else {
    Write-Host "[$(Get-Date -Format t)] ERROR: Unable to find Azure Data Explorer endpoint from the cluser resource in the resource group."
}

##############################################################
# Configure L1 virtualization infrastructure
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure (Step 5/13)" -ForegroundColor DarkGreen
$password = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($AgConfig.L1Username, $password)

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
$kubeFolder = "$env:USERPROFILE\.kube"
New-Item -ItemType Directory $kubeFolder -Force | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-SmbShare -Name "kube" -Path "$env:USERPROFILE\.kube" -FullAccess "Everyone" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Enable Enhanced Session Mode on Host
Write-Host "[$(Get-Date -Format t)] INFO: Enabling Enhanced Session Mode on Hyper-V host" -ForegroundColor Gray
Set-VMHost -EnableEnhancedSessionMode $true | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + $AgConfig.L1SwitchName + ")")).ifIndex
New-NetIPAddress -IPAddress $AgConfig.L1DefaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-NetNat -Name $AgConfig.L1SwitchName -InternalIPInterfaceAddressPrefix $AgConfig.L1NatSubnetPrefix | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

############################################
# Deploying the nested L1 virtual machines 
############################################
Write-Host "[$(Get-Date -Format t)] INFO: Fetching Windows 11 IoT Enterprise VM images from Azure storage. This may take a few minutes." -ForegroundColor Yellow
azcopy cp $AgConfig.ProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create three virtual machines from the base VHDX image
$vhdxPath = Get-ChildItem $AgConfig.AgDirectories["AgVHDXDir"] -Filter *.vhdx | Select-Object -ExpandProperty FullName
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        # Create diff disks for each site host
        Write-Host "[$(Get-Date -Format t)] INFO: Creating differencing disk for $($site.Name) site" -ForegroundColor Gray
        $vhd = New-VHD -ParentPath $vhdxPath -Path "$($AgConfig.AgDirectories["AgVHDXDir"])\$($site.Name)DiffDisk.vhdx" -Differencing
        
        # Create a new virtual machine and attach the existing virtual hard disk
        Write-Host "[$(Get-Date -Format t)] INFO: Creating and configuring $($site.Name) virtual machine." -ForegroundColor Gray
        New-VM -Name $site.Name `
            -MemoryStartupBytes $AgConfig.L1VMMemory `
            -BootDevice VHD `
            -VHDPath $vhd.Path `
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

########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap 
########################################################################
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        Write-Host "[$(Get-Date -Format t)] INFO: Renaming computer name of $($site.Name)" -ForegroundColor Gray
        Invoke-Command -VMName $site.Name -Credential $Credentials -ScriptBlock {
            $site = $using:site
            (gwmi win32_computersystem).Rename($site.Name)
            Restart-Computer
        } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
    }
}
# Create an array with VM names    
$VMnames = (Get-VM).Name

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    # Set time zone to UTC
    Set-TimeZone -Id "UTC"
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure 
    ###########################################
    Write-Host "[$(Get-Date -Format t)] INFO: Preparing folder structure on $hostname." -ForegroundColor Gray
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    $kubeFolder = "$env:USERPROFILE\.kube"

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

    ##########################################
    # Deploying AKS Edge Essentials clusters 
    ##########################################
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"

    # Assigning network adapter IP address
    $NetIPAddress = $AgConfig.SiteConfig[$env:COMPUTERNAME].NetIPAddress
    $DefaultGateway = $AgConfig.SiteConfig[$env:COMPUTERNAME].DefaultGateway
    $PrefixLength = $AgConfig.SiteConfig[$env:COMPUTERNAME].PrefixLength
    $DNSClientServerAddress = $AgConfig.SiteConfig[$env:COMPUTERNAME].DNSClientServerAddress
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring networking interface on $hostname with IP address $NetIPAddress." -ForegroundColor Gray
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex | Out-Null
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress | Out-Null

    # Validating internet connectivity
    $timeElapsed = 0
    do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for internet connection to be healthy on $hostname." -ForegroundColor Gray
        Start-Sleep -Seconds 5
        $timeElapsed = $timeElapsed + 10
    } until ((Test-Connection bing.com -Count 1 -ErrorAction SilentlyContinue) -or ($timeElapsed -eq 60))
    
    # Fetching latest AKS Edge Essentials msi file
    Write-Host "[$(Get-Date -Format t)] INFO: Fetching latest AKS Edge Essentials install file on $hostname." -ForegroundColor Gray
    Invoke-WebRequest 'https://aka.ms/aks-edge/k3s-msi' -OutFile $deploymentFolder\AKSEEK3s.msi

    # Fetching required GitHub artifacts from Jumpstart repository
    Write-Host "[$(Get-Date -Format t)] INFO: Fetching GitHub artifacts" -ForegroundColor Gray
    $repoName = "azure_arc" # While testing, change to your GitHub fork's repository name
    $githubApiUrl = "https://api.github.com/repos/$using:githubAccount/$repoName/contents/azure_jumpstart_ag/artifacts/L1Files?ref=$using:githubBranch"
    $response = Invoke-RestMethod -Uri $githubApiUrl
    $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
    $fileUrls | ForEach-Object {
        $fileName = $_.Substring($_.LastIndexOf("/") + 1)
        $outputFile = Join-Path $deploymentFolder $fileName
        Invoke-RestMethod -Uri $_ -OutFile $outputFile
    }

    # Setting up replacment parameters for AKS Edge Essentials config json file
    Write-Host "[$(Get-Date -Format t)] INFO: Building AKS Edge Essentials config json file on $hostname." -ForegroundColor Gray
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
Write-Host "[$(Get-Date -Format t)] INFO: Initial L1 virtualization infrastructure configuration complete." -ForegroundColor Green
Write-Host

Write-Host "[$(Get-Date -Format t)] INFO: Installing AKS Edge Essentials (Step 6/13)" -ForegroundColor DarkGreen
foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Write-Host "[$(Get-Date -Format t)] INFO: Rebooting $VMName." -ForegroundColor Gray
    Invoke-Command -Session $Session -ScriptBlock { 
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $env:USERNAME -Password 'Agora123!!' -RunLevel Highest | Out-Null
        Restart-Computer -Force -Confirm:$false
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSEEInstall.log")
    Remove-PSSession $Session | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSEEInstall.log")
}

Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.

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
            Write-Host "[$(Get-Date -Format t)] INFO: Waiting for AKS Edge Essentials kubeconfig to be available on $VMName." -ForegroundColor Gray
        }
        
        Write-Host "[$(Get-Date -Format t)] INFO: $VMName's kubeconfig is ready - copying over config-$VMName" -ForegroundColor DarkGreen
        $destinationPath = $env:USERPROFILE + "\.kube\config-" + $VMName
        $s = New-PSSession -VMName $VMName -Credential $credential
        Copy-Item -FromSession $s -Path $path -Destination $destinationPath
    }
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "[$(Get-Date -Format t)] INFO: Waiting on kubeconfig files took $($elapsedTime.ToString("g"))." -ForegroundColor Gray

# Merging kubeconfig files on the L0 vistual machine
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files are present. Merging kubeconfig files for use with kubectx." -ForegroundColor Gray
$kubeconfigpath = ""
foreach ($VMName in $VMNames) {
    $kubeconfigpath = $kubeconfigpath + "$env:USERPROFILE\.kube\config-" + $VMName.ToLower() + ";"
}
$env:KUBECONFIG = $kubeconfigpath
kubectl config view --merge --flatten > "$env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSEEInstall.log")
kubectl config get-clusters --kubeconfig="$env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSEEInstall.log")
Rename-Item -Path "$env:USERPROFILE\.kube\config-raw" -NewName "$env:USERPROFILE\.kube\config"
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config"

# Print a message indicating that the merge is complete
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files merged successfully." -ForegroundColor Gray

# Validate context switching using kubectx & kubectl
foreach ($cluster in $VMNames) {
    Write-Host "[$(Get-Date -Format t)] INFO: Testing connectivity to kube api on $cluster cluster." -ForegroundColor Gray
    kubectx $cluster.ToLower()
    kubectl get nodes -o wide
}
Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials installs are complete!" -ForegroundColor Green

#####################################################################
### Connect the AKS Edge Essentials clusters and hosts to Azure Arc
#####################################################################

Write-Host "[$(Get-Date -Format t)] INFO: Connecting AKS Edge clusters to Azure with Azure Arc (Step 7/13)" -ForegroundColor DarkGreen
foreach ($VM in $VMNames) {
    $secret = $Env:spnClientSecret
    $clientId = $Env:spnClientId
    $tenantId = $Env:spnTenantId
    $location = $Env:azureLocation
    $resourceGroup = $env:resourceGroup

    Invoke-Command -VMName $VM -Credential $Credentials -ScriptBlock {
        # Install prerequisites
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
        Connect-AzConnectedMachine -ResourceGroupName $using:resourceGroup -Name "Ag-$hostname-Host" -Location $using:location

        # Connect clusters to Arc
        $deploymentPath = "C:\Deployment\config.json"
        Write-Host "[$(Get-Date -Format t)] INFO: Arc-enabling $hostname AKS Edge Essentials cluster." -ForegroundColor Gray
        kubectl get svc
        Connect-AksEdgeArc -JsonConfigFilePath $deploymentPath
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
}
# Get all the Azure Arc-enabled Kubernetes clusters in the resource group
#$clusters = az resource list --resource-group $env:resourceGroup --resource-type $AgConfig.ArcK8sResourceType --query "[].id" --output tsv
$clusters = Get-AzResource -ResourceGroup $env:resourceGroup -ResourceType $AgConfig.ArcK8sResourceType

# Loop through each cluster and tag it
$TagName = $AgConfig.TagName
$TagValue = $AgConfig.TagValue
foreach ($cluster in $clusters) {
    #az resource tag --tags $TagName=$TagValue --ids $cluster | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
    New-AzTag -ResourceId $cluster.ResourceId -Name $TagName -Value $TagValue | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
}
Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials clusters and hosts have been registered with Azure Arc!" -ForegroundColor Green
Write-Host

#####################################################################
# Setup Azure Container registry on AKS Edge Essentials clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 8/13)" -ForegroundColor DarkGreen
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($cluster.Value.Type -eq "AKSEE") {
        Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure Container registry on ${cluster.Name}"
        kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
        kubectl create secret docker-registry acr-secret `
            --namespace default `
            --docker-server="$acrName.azurecr.io" `
            --docker-username="$env:spnClientId" `
            --docker-password="$env:spnClientSecret" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    }
}

#####################################################################
# Setup Azure Container registry on cloud AKS staging environment
#####################################################################
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksStagingClusterName --admin | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
kubectx staging="$Env:aksStagingClusterName-admin" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")

# Attach ACR to staging cluster
Write-Host "[$(Get-Date -Format t)] INFO: Attaching Azure Container Registry to AKS staging cluster." -ForegroundColor Gray
az aks update -n $Env:aksStagingClusterName -g $Env:resourceGroup --attach-acr $acrName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")

#####################################################################
# Cosmos DB preparation
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Cosmos DB Kubernetes secrets" -ForegroundColor Gray
$cosmosDBKey = $(az cosmosdb keys list --name $cosmosDBName --resource-group $resourceGroup --query primaryMasterKey --output tsv)
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    Write-Host "[$(Get-Date -Format t)] INFO: Creating Cosmos DB Kubernetes secrets on ${cluster.Name}" -ForegroundColor Gray
    kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    kubectl create namespace $cluster.value.Namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    kubectl create secret generic postgrespw --from-literal=POSTGRES_PASSWORD='Agora123!!' --namespace $cluster.value.Namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    kubectl create secret generic cosmoskey --from-literal=COSMOS_KEY=$cosmosDBKey --namespace $cluster.value.Namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
}
Write-Host "[$(Get-Date -Format t)] INFO: Cluster secrets configuration complete." -ForegroundColor Green
Write-Host

#####################################################################
### Deploy Kube Prometheus Stack for Observability
#####################################################################

$AgTempDir = $AgConfig.AgDirectories["AgTempDir"]
$observabilityNamespace = $AgConfig.Monitoring["Namespace"]
$observabilityPassword = $AgConfig.Monitoring["Password"]
$observabilityDashboards = $AgConfig.Monitoring["Dashboards"]

# Set Prod Grafana API endpoint
$grafanaDS = $AgConfig.Monitoring["ProdURL"] + "/api/datasources"

# Installing Grafana
Write-Host "[$(Get-Date -Format t)] INFO: Installing and Configuring Observability components (Step 9/13)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Installing Grafana." -ForegroundColor Gray
$latestRelease = (Invoke-WebRequest -Uri "https://api.github.com/repos/grafana/grafana/releases/latest" | ConvertFrom-Json).tag_name.replace('v', '')
Start-Process msiexec.exe -Wait -ArgumentList "/I $AgToolsDir\grafana-$latestRelease.windows-amd64.msi /quiet" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Prometheus Helm charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Grafana Icons
Copy-Item -Path $AgIconsDir\contoso.png -Destination "C:\Program Files\GrafanaLabs\grafana\public\img"
Copy-Item -Path $AgIconsDir\contoso.png -Destination "C:\Program Files\GrafanaLabs\grafana\public\img\fav32.png"
Copy-Item -Path $AgIconsDir\contoso.svg -Destination "C:\Program Files\GrafanaLabs\grafana\public\img\grafana_icon.svg"

Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object { 
    (Get-Content $_.FullName) -replace 'className:u,src:"public/img/grafana_icon.svg"', 'className:u,src:"public/img/contoso.png"' | Set-Content $_.FullName
}

# Reset Grafana UI
Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object {
    (Get-Content $_.FullName) -replace 'Welcome to Grafana', 'Welcome to Grafana for Contoso Supermarket Production' | Set-Content $_.FullName
}

# Reset Grafana Password
$env:Path += ';C:\Program Files\GrafanaLabs\grafana\bin'
grafana-cli --homepath "C:\Program Files\GrafanaLabs\grafana" admin reset-admin-password $observabilityPassword | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Get Grafana credentials
$credentials = $AgConfig.Monitoring["UserName"] + ':' + $observabilityPassword
$encodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credentials))

$headers = @{    
    "Authorization" = ("Basic " + $encodedcredentials)    
    "Content-Type"  = "application/json"
}

# Download dashboards
foreach ($dashboard in $observabilityDashboards) {
    $grafanaDBPath = "$AgTempDir\grafana_dashboard_$dashboard.json"
    $dashboardmetadata = Invoke-RestMethod -Uri https://grafana.com/api/dashboards/$dashboard/revisions
    $dashboardversion = $dashboardmetadata.items | Sort-Object revision | Select-Object -Last 1 | Select-Object -ExpandProperty revision
    Invoke-WebRequest https://grafana.com/api/dashboards/$dashboard/revisions/$dashboardversion/download -OutFile $grafanaDBPath
}

# Deploying Kube Prometheus Stack for stores
$AgConfig.SiteConfig.GetEnumerator() | ForEach-Object {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying Kube Prometheus Stack for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    kubectx $_.Value.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    # Install Prometheus Operator
    helm install prometheus prometheus-community/kube-prometheus-stack --set $_.Value.HelmSetValue --namespace $observabilityNamespace --create-namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
        
    Do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for $($_.Value.FriendlyName) monitoring service to provision.." -ForegroundColor Gray
        Start-Sleep -Seconds 10
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
        Invoke-RestMethod -Method Post -Uri $grafanaDS -Headers $headers -Body $grafanaDSBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
    }
        
    Write-Host "[$(Get-Date -Format t)] INFO: Importing dashboards for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    # Add Infra dashboard
    foreach ($dashboard in $observabilityDashboards) {
        $grafanaDBPath = "$AgTempDir\grafana_dashboard_$dashboard.json"
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
        }
        else {
            # Set Grafana Dashboard endpoint
            $grafanaDBURI = "http://$monitorLBIP/api/dashboards/db"
        }
            
        # Make HTTP request to the API
        Invoke-RestMethod -Method Post -Uri $grafanaDBURI -Headers $headers -Body $grafanaDBBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
    }
    if (!$_.Value.IsProduction) {
        # Creating Grafana Icon on Desktop
        Write-Host "[$(Get-Date -Format t)] INFO: Creating $($_.Value.FriendlyName) Grafana Icon." -ForegroundColor Gray 
        $shortcutLocation = "$env:USERPROFILE\Desktop\$($_.Value.FriendlyName) Grafana.lnk"
        $wScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
        $shortcut.TargetPath = "http://$monitorLBIP"
        $shortcut.IconLocation = "$AgIconsDir\grafana.ico, 0"
        $shortcut.WindowStyle = 3
        $shortcut.Save()
    }
}

# Creating Prod Grafana Icon on Desktop
Write-Host "[$(Get-Date -Format t)] INFO: Creating Prod Grafana Icon" -ForegroundColor Gray
$shortcutLocation = "$env:USERPROFILE\Desktop\Prod Grafana.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = $AgConfig.Monitoring["ProdURL"]
$shortcut.IconLocation = "$AgIconsDir\grafana.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

Write-Host "[$(Get-Date -Format t)] INFO: Cluster secrets configuration complete." -ForegroundColor Green
Write-Host

#############################################################
# Install Windows Terminal, WSL2, and Ubuntu
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing dev tools (Step 10/13)" -ForegroundColor DarkGreen
If ($PSVersionTable.PSVersion.Major -ge 7) { Write-Error "This script needs be run by version of PowerShell prior to 7.0" }
$downloadDir = "C:\WinTerminal"
$gitRepo = "microsoft/terminal"
$filenamePattern = "*.msixbundle"
$framworkPkgUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$framworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$msiPath = "$downloadDir\Microsoft.WindowsTerminal.msixbundle"
$releasesUri = "https://api.github.com/repos/$gitRepo/releases/latest"
$downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -SkipLast 1

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release msixbundle
Write-Host "[$(Get-Date -Format t)] INFO: Downloading binaries." -ForegroundColor Gray
Invoke-WebRequest -Uri $framworkPkgUrl -OutFile ( New-Item -Path $framworkPkgPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
Invoke-WebRequest -Uri $downloadUri -OutFile ( New-Item -Path $msiPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install WSL latest kernel update
Write-Host "[$(Get-Date -Format t)] INFO: Installing WSL." -ForegroundColor Gray
msiexec /i "$AgToolsDir\wsl_update_x64.msi" /qn | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Write-Host "[$(Get-Date -Format t)] INFO: Installing Windows Terminal" -ForegroundColor Gray
Add-AppxPackage -Path $framworkPkgPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
Add-AppxPackage -Path $msiPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
Add-AppxPackage -Path "$AgToolsDir\Ubuntu.appx" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Setting WSL environment variables
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + ";C:\Users\$adminUsername\Ubuntu", "User")

# Initializing the wsl ubuntu app without requiring user input
Write-Host "[$(Get-Date -Format t)] INFO: Installing Ubuntu." -ForegroundColor Gray
$ubuntu_path = "c:/users/$adminUsername/AppData/Local/Microsoft/WindowsApps/ubuntu"
Invoke-Expression -Command "$ubuntu_path install --root" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Create Windows Terminal shortcut
$WshShell = New-Object -comObject WScript.Shell
$WinTerminalPath = (Get-ChildItem "C:\Program Files\WindowsApps" -Recurse | Where-Object { $_.name -eq "wt.exe" }).FullName
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Windows Terminal.lnk")
$Shortcut.TargetPath = $WinTerminalPath
$shortcut.WindowStyle = 3
$shortcut.Save()

#############################################################
# Install VSCode extensions
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($AgConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
# Install VSCode extensions
foreach ($extension in $AgConfig.VSCodeExtensions) {
    code --install-extension $extension | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

# Cleanup
Remove-Item $downloadDir -Recurse -Force
Write-Host "[$(Get-Date -Format t)] INFO: Tools setup complete." -ForegroundColor Green
Write-Host

#############################################################
# Install Docker Desktop
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing Docker Dekstop and building images. (Step 11/13)" -ForegroundColor DarkGreen
# Download and Install Docker Desktop
$arguments = 'install --quiet --accept-license'
Start-Process "$AgToolsDir\DockerDesktopInstaller.exe" -Wait -ArgumentList $arguments | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
Get-ChildItem "$env:USERPROFILE\Desktop\Docker Desktop.lnk" | Remove-Item -Confirm:$false
Move-Item "$AgToolsDir\settings.json" -Destination "$env:USERPROFILE\AppData\Roaming\Docker\settings.json" -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
Start-Sleep -Seconds 10
Get-Process | Where-Object { $_.name -like "Docker Desktop" } | Stop-Process -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep -Seconds 25


#############################################################
# Contoso super market image initial build
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Building Docker images." -ForegroundColor Gray
$env:Path += ";C:\Program Files\Docker\Docker\resources\bin"
az acr login --name $acrName --only-show-errors
Set-Location "$AgAppsRepo\jumpstart-agora-apps\contoso_supermarket\developer\pos\src"
docker build . -t "$acrName.azurecr.io/dev/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
docker push "$acrName.azurecr.io/dev/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")

docker build . -t "$acrName.azurecr.io/staging/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
docker push "$acrName.azurecr.io/staging/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")

docker build . -t "$acrName.azurecr.io/canary/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
docker push "$acrName.azurecr.io/canary/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")

docker build . -t "$acrName.azurecr.io/production/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")
docker push "$acrName.azurecr.io/production/contoso-supermarket/pos:latest" #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Docker.log")

Write-Host "[$(Get-Date -Format t)] INFO: Docker setup and image builds complete." -ForegroundColor Green
Write-Host

#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps. (Step 12/13)" -ForegroundColor DarkGreen
foreach ($app in $AgConfig.AppConfig.GetEnumerator()) {
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for pos application on $cluster.value.ArcClusterName" -ForegroundColor Gray
        $store = $cluster.value.Branch.ToLower()
        $configName = $cluster.value.FriendlyName.ToLower()
        $clusterName = $cluster.value.ArcClusterName
        $branch = $cluster.value.Branch
        if ($cluster.value.FriendlyName -eq "Staging") {
            $clusterType = "managedClusters"
        }
        else {
            $clusterType = "connectedClusters"
        }
        az k8s-configuration flux create `
            --cluster-name $clusterName `
            --resource-group $Env:resourceGroup `
            --name config-supermarket-$configName `
            --cluster-type $clusterType `
            --url $appClonedRepo `
            --branch $Branch --sync-interval 3s `
            --namespace 'contoso-supermarket' `
            --kustomization name=pos path=./contoso_supermarket/operations/contoso_supermarket/release/$store --only-show-errors #| Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps.log")

    }
}
Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
Write-Host

##############################################################
# Cleanup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up scripts and uploading logs. (Step 13/13)" -ForegroundColor DarkGreen
# Creating Hyper-V Manager desktop shortcut
Write-Host "[$(Get-Date -Format t)] INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Removing the LogonScript Scheduled Task
Write-Host "[$(Get-Date -Format t)] INFO: Removing scheduled logon task so it won't run on next login." -ForegroundColor Gray
Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Cleanup.log")
Start-Sleep -Seconds 5

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
}' | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Cleanup.log")

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
Add-Type $code | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Cleanup.log")
[Win32.Wallpaper]::SetWallpaper($imgPath) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Cleanup.log")

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes. Please enjoy the Agora experience!" -ForegroundColor Green
Write-Host

Stop-Transcript
