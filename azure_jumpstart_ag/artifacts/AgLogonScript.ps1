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
$acrName = $Env:acrName
$cosmosDBName = $Env:cosmosDBName
$cosmosDBEndpoint = $Env:cosmosDBEndpoint
$templateBaseUrl = $env:templateBaseUrl
$appClonedRepo = "https://github.com/$githubUser/jumpstart-agora-apps"
$adxClusterName = $env:adxClusterName

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
Write-Header "Executing AgLogonScript.ps1"

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

##############################################################
# Setup Azure CLI
##############################################################
Write-Host "INFO: Configuring Azure CLI" -ForegroundColor Gray
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
if ($AgConfig.AzCLIExtensions.Count -ne 0) {
    Write-Host "INFO: Installing Azure CLI extensions: " ($AgConfig.AzCLIExtensions -join ', ') -ForegroundColor Gray
    az config set extension.use_dynamic_install=yes_without_prompt
    # Installing Azure CLI extensions
    foreach ($extension in $AgConfig.AzCLIExtensions) {
        az extension add --name $extension --system
    }
}
az -v

Write-Host "INFO: Az CLI configuration complete!" -ForegroundColor Green

##############################################################
# Setup Azure PowerShell and register providers
##############################################################
Write-Host "INFO: Logging into Azure PowerShell using the service principal and secret provided at deployment." -ForegroundColor Gray
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal
$subscriptionId = (Get-AzSubscription).Id

# Install PowerShell modules
if ($AgConfig.PowerShellModules.Count -ne 0) {
    Write-Host "INFO: Installing PowerShell modules: " ($AgConfig.PowerShellModules -join ', ') -ForegroundColor Gray
    foreach ($module in $AgConfig.PowerShellModules) {
        Install-Module -Name $module -Force
    }
}

# Register Azure providers
if ($Agconfig.AzureProviders.Count -ne 0) {
    Write-Host "INFO: Registering Azure providers in the current subscription: " ($AgConfig.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AgConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}
Write-Host "INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green

##############################################################
# Configure Jumpstart AG Apps repository
##############################################################
Write-Host "INFO: Forking and prepareing Apps repository locally" -ForegroundColor Gray
Set-Location $AgAppsRepo
if ($githubUser -ne "microsoft") {
    git clone "https://$githubPat@github.com/$githubUser/jumpstart-agora-apps.git" $AgAppsRepo\jumpstart-agora-apps
    Set-Location $AgAppsRepo\jumpstart-agora-apps
    Write-Host "INFO: Getting Cosmos DB access key" -ForegroundColor Gray
    Write-Host "INFO: Adding GitHub secrets to apps fork" -ForegroundColor Gray
    gh api -X PUT /repos/$githubUser/jumpstart-agora-apps/actions/permissions/workflow -F can_approve_pull_request_reviews=true
    gh secret set "SPN_CLIENT_ID" -b $spnClientID
    gh secret set "SPN_CLIENT_SECRET" -b $spnClientSecret
    gh secret set "ACR_NAME" -b $acrName
    gh secret set "PAT_GITHUB" -b $githubPat
    gh secret set "COSMOS_DB_ENDPOINT" -b $cosmosDBEndpoint
    Write-Host "INFO: Creating GitHub branches to apps fork" -ForegroundColor Gray
    $branches = $AgConfig.GitBranches
    foreach ($branch in $branches) {
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$githubUser/jumpstart-agora-apps/branches/$branch"
            if ($response) {
                Write-Host "INFO: $branch branch already exists! Deleting and recreating the branch" -ForegroundColor Gray
                git push origin --delete $branch
                git checkout -b $branch
                git push origin $branch
            }
        }
        catch {
            Write-Host "INFO: Creating $branch branch" -ForegroundColor Gray
            git checkout -b $branch
            git push origin $branch
        }
    }
    Write-Host "INFO: Switching to main branch" -ForegroundColor Gray
    git checkout main
    Write-Host "INFO: GitHub repo configuration complete!" -ForegroundColor Green
}
else {
    Write-Host "ERROR: You have to fork the jumpstart-agora-apps repository!" -ForegroundColor Red
}

#####################################################################
# IotHub resources preperation
#####################################################################
Write-Host "INFO: Creating IoT resources" -ForegroundColor Gray
if ($env:githubUser -ne "microsoft") {
    $IoTHubHostName = $env:iotHubHostName
    $IoTHubName = $IoTHubHostName.replace(".azure-devices.net", "")
    gh secret set "IOTHUB_HOSTNAME" -b $IoTHubHostName
    $sites = $AgConfig.SiteConfig.Values
    Write-Host "INFO: Create an IoT device for each site" -ForegroundColor Gray
    foreach ($site in $sites) {
        $deviceId = $site.FriendlyName
        az iot hub device-identity create --device-id $deviceId --edge-enabled --hub-name $IoTHubName --resource-group $resourceGroup
        $deviceSASToken = $(az iot hub generate-sas-token --device-id $deviceId --hub-name $IoTHubName --resource-group $resourceGroup --duration (60 * 60 * 24 * 30) --query sas -o tsv)
        gh secret set "sas_token_$deviceId" -b $deviceSASToken
    }
    Write-Host "INFO: IoT Hub configuration complete!" -ForegroundColor Green
}
else {
    Write-Host "ERROR: You have to fork the jumpstart-agora-apps repository!" -ForegroundColor Red
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
$adxEndPoint = (az kusto cluster show --name $adxClusterName --resource-group $resourceGroup --query "uri" -o tsv)
if ($null -ne $adxEndPoint -and $adxEndPoint -ne ""){
    $ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx-dashboard-orders-payload.json").Content -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
    Set-Content -Path "$agDir\adx-dashboard-orders-payload.json" -Value $ordersDashboardBody -Force -ErrorAction Ignore
    $iotSensorsDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx-dashboard-iotsensor-payload.json") -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
    Set-Content -Path "$agDir\adx-dashboard-iotsensor-payload.json" -Value $iotSensorsDashboardBody -Force -ErrorAction Ignore
}
else{
    Write-Host "ERROR: Unable to find Azure Data Explorer endpoint from the cluser resource in the resource group."
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
Write-Host "INFO: Enabling Enhanced Session Mode on Hyper-V host" -ForegroundColor Gray
Set-VMHost -EnableEnhancedSessionMode $true

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + $AgConfig.L1SwitchName + ")")).ifIndex
New-NetIPAddress -IPAddress $AgConfig.L1DefaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex
New-NetNat -Name $AgConfig.L1SwitchName -InternalIPInterfaceAddressPrefix $AgConfig.L1NatSubnetPrefix

############################################
# Deploying the nested L1 virtual machines 
############################################
Write-Host "INFO: Fetching Windows 11 IoT Enterprise VM images from Azure storage. This may take a few minutes." -ForegroundColor Green
azcopy cp $AgConfig.ProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR

# Create three VMs from the base VHDX image
$vhdxPath = Get-ChildItem $AgConfig.AgDirectories["AgVHDXDir"] -Filter *.vhdx | Select-Object -ExpandProperty FullName
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        # Create diff disks for each site host
        Write-Host "INFO: Creating differencing disk for site $($site.Name)" -ForegroundColor Gray
        $vhd = New-VHD -ParentPath $vhdxPath -Path "$($AgConfig.AgDirectories["AgVHDXDir"])\$($site.Name)DiffDisk.vhdx" -Differencing
        
        # Create a new virtual machine and attach the existing virtual hard disk
        Write-Host "INFO: Creating and configuring $($site.Name) virtual machine." -ForegroundColor Gray
        New-VM -Name $site.Name `
            -MemoryStartupBytes $AgConfig.L1VMMemory `
            -BootDevice VHD `
            -VHDPath $vhd.Path `
            -Generation 2 `
            -Switch $AgConfig.L1SwitchName
        
        # Set up the virtual machine before coping all AKS Edge Essentials automation files
        Set-VMProcessor -VMName $site.Name `
            -Count $AgConfig.L1VMNumVCPU `
            -ExposeVirtualizationExtensions $true

        Get-VMNetworkAdapter -VMName $site.Name | Set-VMNetworkAdapter -MacAddressSpoofing On
        Enable-VMIntegrationService -VMName $site.Name -Name "Guest Service Interface"
  
        # Create virtual machine snapshot and start the virtual machine
        Checkpoint-VM -Name $site.Name -SnapshotName "Base"
        Start-Sleep -Seconds 5
        Start-VM -Name $site.Name
    }
}

Start-Sleep -Seconds 20

########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap 
########################################################################
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
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
    Write-Host "INFO: Configuring networking interface on $hostname with IP address $NetIPAddress." -ForegroundColor Gray
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress

    # Validating internet connectivity
    $timeElapsed = 0
    do {
        Write-Host "INFO: Waiting for internet connection to be healthy on $hostname."
        Start-Sleep -Seconds 5
        $timeElapsed = $timeElapsed + 10
    } until ((Test-Connection bing.com -Count 1 -ErrorAction SilentlyContinue) -or ($timeElapsed -eq 60))
    
    # Fetching latest AKS Edge Essentials msi file
    Write-Host "INFO: Fetching latest AKS Edge Essentials install file on $hostname." -ForegroundColor Gray
    Invoke-WebRequest 'https://aka.ms/aks-edge/k3s-msi' -OutFile $deploymentFolder\AKSEEK3s.msi

    # Fetching required GitHub artifacts from Jumpstart repository
    Write-Host "Fetching GitHub artifacts"
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
    Write-Host "INFO: Building AKS Edge Essentials config json file on $hostname."
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
Write-Host "INFO: L1 virtualization infrastructure configuration complete. Now rebooting hosts and starting AKS Edge Essentials install. This may take some time while VMs reboot and installation proceeds." -ForegroundColor Green

foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Write-Host "INFO: Rebooting $VMName." -ForegroundColor Gray
    Invoke-Command -Session $Session -ScriptBlock { 
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $env:USERNAME -Password 'Agora123!!' -RunLevel Highest
        Restart-Computer -Force -Confirm:$false
    }
    Remove-PSSession $Session
}

Start-Sleep -Seconds 120 # Give some time for the AKS EE installs to complete. This will take a few minutes.

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
            Write-Host "INFO: Waiting for AKS Edge Essentials kubeconfig to be available on $VMName." -ForegroundColor Gray
        }
        
        Write-Host "INFO: $VMName's kubeconfig is ready - copying over config-$VMName" -ForegroundColor DarkGreen
        $destinationPath = $env:USERPROFILE + "\.kube\config-" + $VMName
        $s = New-PSSession -VMName $VMName -Credential $credential
        Copy-Item -FromSession $s -Path $path -Destination $destinationPath
    }
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "INFO: Waiting on kubeconfig files took $($elapsedTime.TotalSeconds) seconds." -ForegroundColor Gray

# Merging kubeconfig files on the L0 vistual machine
Write-Host "INFO: All three kubeconfig files are present. Merging kubeconfig files for use with kubectx." -ForegroundColor Gray
$kubeconfigpath = ""
foreach ($VMName in $VMNames) {
    $kubeconfigpath = $kubeconfigpath + "$env:USERPROFILE\.kube\config-" + $VMName.ToLower() + ";"
}
$env:KUBECONFIG = $kubeconfigpath
kubectl config view --merge --flatten > "$env:USERPROFILE\.kube\config-raw"
kubectl config get-clusters --kubeconfig="$env:USERPROFILE\.kube\config-raw"
Rename-Item -Path "$env:USERPROFILE\.kube\config-raw" -NewName "$env:USERPROFILE\.kube\config"
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config"

# Print a message indicating that the merge is complete
Write-Host "INFO: All three kubeconfig files merged successfully." -ForegroundColor Gray

# Validate context switching using kubectx & kubectl
foreach ($cluster in $VMNames) {
    Write-Host "INFO: Testing connectivity to kube api on $cluster cluster." -ForegroundColor Gray
    kubectx $cluster.ToLower()
    kubectl get nodes -o wide
}
Write-Host "INFO: AKS Edge Essentials installs are complete!" -ForegroundColor Green

#####################################################################
### Connect the AKS Edge Essentials clusters to Azure Arc
#####################################################################

Write-Header "Connecting AKS Edge clusters to Azure with Azure Arc"
foreach ($VM in $VMNames) {
    Invoke-Command -VMName $VM -Credential $Credentials -ScriptBlock {
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
}
Write-Host "INFO: AKS Edge Essentials clusters have been registered with Azure Arc!" -ForegroundColor Green

# Get all the Azure Arc-enabled Kubernetes clusters in the resource group
$clusters = az resource list --resource-group $env:resourceGroup --resource-type $AgConfig.ArcK8sResourceType --query "[].id" --output tsv

# Loop through each cluster and tag it
$TagName = $AgConfig.TagName
$TagValue = $AgConfig.TagValue
foreach ($cluster in $clusters) {
    az resource tag --tags $TagName=$TagValue --ids $cluster
}

#####################################################################
# Setup Azure Container registry on AKS Edge Essentials clusters
#####################################################################
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($cluster.Value.Type -eq "AKSEE") {
        Write-Host "INFO: Configuring Azure Container registry on ${cluster.Name}"
        kubectx $cluster.Name.ToLower()
        kubectl create secret docker-registry acr-secret `
            --namespace default `
            --docker-server="${Env:acrName}.azurecr.io" `
            --docker-username="$env:spnClientId" `
            --docker-password="$env:spnClientSecret"
    }
}

#####################################################################
# Setup Azure Container registry on cloud AKS staging environment
#####################################################################
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksStagingClusterName --admin
kubectx staging="$Env:aksStagingClusterName-admin"

# Attach ACR to staging cluster
Write-Host "INFO: Attaching Azure Container Registry to AKS staging cluster." -ForegroundColor Gray
az aks update -n $Env:aksStagingClusterName -g $Env:resourceGroup --attach-acr $Env:acrName


#####################################################################
# Cosmos DB preperation
#####################################################################
Write-Host "INFO: Creating Cosmos DB Kubernetes secrets" -ForegroundColor Gray
$cosmosDBKey = $(az cosmosdb keys list --name $cosmosDBName --resource-group $resourceGroup --query primaryMasterKey --output tsv)
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    Write-Host "INFO: Creating Cosmos DB Kubernetes secrets on ${cluster.Name}" -ForegroundColor Gray
    kubectx $cluster.Name.ToLower()
    kubectl create namespace $cluster.value.Namespace
    kubectl create secret generic postgrespw --from-literal=POSTGRES_PASSWORD='Agora123!!' --namespace $cluster.value.Namespace
    kubectl create secret generic cosmoskey --from-literal=COSMOS_KEY=$cosmosDBKey --namespace $cluster.value.Namespace

}

#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
foreach ($app in $AgConfig.AppConfig.GetEnumerator()) {
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        Write-Host "INFO: Creating GitOps config for pos application on $cluster.Name" -ForegroundColor Gray
        $store = $cluster.value.Branch.ToLower()
        $configName = $cluster.value.FriendlyName.ToLower()
        $clusterName= $cluster.value.ArcClusterName
        $branch =$cluster.value.Branch
        if($cluster.value.ArcClusterName -eq "Staging"){
            $clusterType = "managedClusters"
        }else{
            $clusterType = "connectedClusters"
        }
        az k8s-configuration flux create `
            --cluster-name $clusterName `
            --resource-group $Env:resourceGroup `
            --name config-supermarket-$configName `
            --cluster-type $clusterType `
            --url $appClonedRepo `
            --branch $Branch --sync-interval 3s `
            --kustomization name=pos path=./contoso_supermarket/operations/contoso_supermarket/release/$store

    }
}

    # foreach ($app in $AgConfig.AppConfig.GetEnumerator()) {
    #     foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    #         Write-Host "INFO: Creating GitOps config for NGINX Ingress Controller on $cluster.Name" -ForegroundColor Gray
    #         az k8s-configuration flux create `
    #             --cluster-name $cluster.ArcClusterName `
    #             --resource-group $Env:resourceGroup `
    #             --name config-supermarket `
    #             --cluster-type connectedClusters `
    #             --url $appClonedRepo `
    #             --branch main --sync-interval 3s `
    #             --kustomization name=bookstore path=./bookstore/yaml
### Deploy Kube Prometheus Stack for Observability
#####################################################################

    #         az k8s-configuration create `
    #             --name $app.Name `
    #             --cluster-name $cluster.ArcClusterName `
    #             --resource-group $Env:resourceGroup `
    #             --operator-instance-name flux `
    #             --operator-namespace arc-k8s-demo `
    #             --operator-params='--git-readonly --git-path=releases' `
    #             --enable-helm-operator `
    #             --helm-operator-chart-version='1.2.0' `
    #             --helm-operator-params='--set helm.versions=v3' `
    #             --repository-url https://github.com/Azure/arc-helm-demo.git `
    #             --scope namespace `
    #             --cluster-type connectedClusters
    #     }
    # }

    #####################################################################
    ### Deploy Kube Prometheus Stack for Observability
    #####################################################################

    # Installing Grafana
    Write-Header "Installing and Configuring Observability components"
    Write-Host "INFO: Installing Grafana." -ForegroundColor Gray
    $latestRelease = (Invoke-WebRequest -Uri "https://api.github.com/repos/grafana/grafana/releases/latest" | ConvertFrom-Json).tag_name.replace('v', '')
    Start-Process msiexec.exe -Wait -ArgumentList "/I $AgToolsDir\grafana-$latestRelease.windows-amd64.msi /quiet"

    # Update Prometheus Helm charts
    $observabilityNamespace = $AgConfig.Monitoring["Namespace"]
    $observabilityPassword = $AgConfig.Monitoring["Password"]
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

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
    grafana-cli --homepath "C:\Program Files\GrafanaLabs\grafana" admin reset-admin-password $observabilityPassword

    # Get Grafana credentials
    $credentials = $AgConfig.Monitoring["UserName"] + ':' + $observabilityPassword
    $encodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credentials))

    $headers = @{    
        "Authorization" = ("Basic " + $encodedcredentials)    
        "Content-Type"  = "application/json"
    }

    # Grafana API endpoint
    $grafanaDS = $AgConfig.Monitoring["ProdURL"] + "/api/datasources"

# Deploying Kube Prometheus Stack for Prod stores
$AgConfig.SiteConfig.GetEnumerator() | ForEach-Object {
    if ($_.Value.IsProduction) {
        Write-Host "INFO: Deploying Kube Prometheus Stack for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
        kubectx $_.Value.FriendlyName.ToLower()
        # Install Prometheus Operator
        $helmSetValue = 'alertmanager.enabled=false,grafana.enabled=false,prometheus.service.type=LoadBalancer'
        helm install prometheus prometheus-community/kube-prometheus-stack --set $helmSetValue --namespace $observabilityNamespace --create-namespace

        Do {
            Write-Host "INFO: Waiting for $($_.Value.FriendlyName) Prometheus service to provision.." -ForegroundColor Gray
            Start-Sleep -Seconds 45
            $prometheusIP = $(if (kubectl get service/prometheus-kube-prometheus-prometheus --namespace $observabilityNamespace --output=jsonpath='{.status.loadBalancer}' | Select-String "ingress" -Quiet) { "Ready!" }Else { "Nope" })
        } while ($prometheusIP -eq "Nope" )
        # Get Load Balancer IP
        $prometheusLBIP = kubectl --namespace $observabilityNamespace get service/prometheus-kube-prometheus-prometheus --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'
        Write-Host "INFO: $($_.Value.FriendlyName) Prometheus service IP is $prometheusLBIP" -ForegroundColor DarkGreen

        Write-Host "INFO: Add $($_.Value.FriendlyName) Data Source to Grafana"
        # Request body with information about the data source to add
        $dsBody = @{    
            name      = $_.Value.FriendlyName  
            type      = 'prometheus'    
            url       = ("http://" + $prometheusLBIP + ":9090")
            access    = 'proxy'    
            basicAuth = $false    
            isDefault = $true
        } | ConvertTo-Json
        
        # Make HTTP request to the API
        Invoke-RestMethod -Method Post -Uri $grafanaDS -Headers $headers -Body $dsBody
    }
}

# Creating Prod Grafana Icon on Desktop
Write-Host "INFO: Creating Prod Grafana Icon" -ForegroundColor Gray
$shortcutLocation = "$env:USERPROFILE\Desktop\Prod Grafana.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = $AgConfig.Monitoring["ProdURL"]
$shortcut.IconLocation = "$AgIconsDir\grafana.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

# Deploying Kube Prometheus Stack for Non-Prod stores
$AgConfig.SiteConfig.GetEnumerator() | ForEach-Object {
    if (-Not $_.Value.IsProduction) {
        Write-Host "INFO: Deploying Kube Prometheus Stack for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
        kubectx $_.Value.FriendlyName.ToLower()
        # Install Prometheus Operator
        $helmSetValue = "alertmanager.enabled=false,grafana.ingress.enabled=true,grafana.service.type=LoadBalancer,grafana.adminPassword=$observabilityPassword"
        helm install prometheus prometheus-community/kube-prometheus-stack --set $helmSetValue --namespace $observabilityNamespace --create-namespace

        Do {
            Write-Host "INFO: Waiting for ${_.FriendlyName} Prometheus service to provision.." -ForegroundColor Gray
            Start-Sleep -Seconds 45
            $grafanaIP = $(if (kubectl get service/prometheus-grafana --namespace $observabilityNamespace --output=jsonpath='{.status.loadBalancer}' | Select-String "ingress" -Quiet) { "Ready!" }Else { "Nope" })
        } while ($grafanaIP -eq "Nope" )
        # Get Load Balancer IP
        $grafanaLBIP = kubectl --namespace $observabilityNamespace get service/prometheus-grafana --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'

        # Creating Grafana Icon on Desktop
        Write-Host "INFO: Creating ${_.FriendlyName} Grafana Icon." -ForegroundColor Gray
        $shortcutLocation = "$env:USERPROFILE\Desktop\${_.FriendlyName} Grafana.lnk"
        $wScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
        $shortcut.TargetPath = "http://$grafanaLBIP"
        $shortcut.IconLocation = "$AgIconsDir\grafana.ico, 0"
        $shortcut.WindowStyle = 3
        $shortcut.Save()
    }
}
Write-Host "INFO: Observability components setup complete!" -ForegroundColor Green

    # Deploying Kube Prometheus Stack for Non-Prod stores
    $nonProdStores = @('dev', 'staging')

    foreach ($nonProdStore in $nonProdStores) {
        Write-Host "INFO: Deploying Kube Prometheus Stack for $nonProdStore environment" -ForegroundColor Gray
        kubectx $nonProdStore
        # Install Prometheus Operator
        $helmSetValue = "alertmanager.enabled=false,grafana.ingress.enabled=true,grafana.service.type=LoadBalancer,grafana.adminPassword=$observabilityPassword"
        helm install prometheus prometheus-community/kube-prometheus-stack --set $helmSetValue --namespace $observabilityNamespace --create-namespace

        Do {
            Write-Host "INFO: Waiting for $nonProdStore Prometheus service to provision.." -ForegroundColor Gray
            Start-Sleep -Seconds 45
            $grafanaIP = $(if (kubectl get service/prometheus-grafana --namespace $observabilityNamespace --output=jsonpath='{.status.loadBalancer}' | Select-String "ingress" -Quiet) { "Ready!" }Else { "Nope" })
        } while ($grafanaIP -eq "Nope" )
        # Get Load Balancer IP
        $grafanaLBIP = kubectl --namespace $observabilityNamespace get service/prometheus-grafana --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'

        # Creating Grafana Icon on Desktop
        Write-Host "INFO: Creating $nonProdStore Grafana Icon." -ForegroundColor Gray
        $shortcutLocation = "$env:USERPROFILE\Desktop\$nonProdStore Grafana.lnk"
        $wScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
        $shortcut.TargetPath = "http://$grafanaLBIP"
        $shortcut.IconLocation = "$AgIconsDir\grafana.ico, 0"
        $shortcut.WindowStyle = 3
        $shortcut.Save()
    }

    #############################################################
    # Install Windows Terminal, WSL2, and Ubuntu
    #############################################################
    Write-Header "Installing Windows Terminal, WSL2 and Ubuntu, Docker Desktop"
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
    Write-Host "INFO: Downloading binaries." -ForegroundColor Gray
    Invoke-WebRequest -Uri $framworkPkgUrl -OutFile ( New-Item -Path $framworkPkgPath -Force )
    Invoke-WebRequest -Uri $downloadUri -OutFile ( New-Item -Path $msiPath -Force )

    # Install WSL latest kernel update
    Write-Host "INFO: Installing WSL." -ForegroundColor Gray
    msiexec /i "$AgToolsDir\wsl_update_x64.msi" /qn

    # Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
    Write-Host "INFO: Installing Windows Terminal" -ForegroundColor Gray
    Add-AppxPackage -Path $framworkPkgPath
    Add-AppxPackage -Path $msiPath
    Add-AppxPackage -Path "$AgToolsDir\Ubuntu.appx"

    # Setting WSL environment variables
    $userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
    [System.Environment]::SetEnvironmentVariable("PATH", $userenv + ";C:\Users\$adminUsername\Ubuntu", "User")

    # Initializing the wsl ubuntu app without requiring user input
    Write-Host "INFO: Installing Ubuntu." -ForegroundColor Gray
    $ubuntu_path = "c:/users/$adminUsername/AppData/Local/Microsoft/WindowsApps/ubuntu"
    Invoke-Expression -Command "$ubuntu_path install --root"

    # Create Windows Terminal shortcut
    $WshShell = New-Object -comObject WScript.Shell
    $WinTerminalPath = (Get-ChildItem "C:\Program Files\WindowsApps" -Recurse | where { $_.name -eq "wt.exe" }).FullName
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\WindowsTerminal.lnk")
    $Shortcut.TargetPath = $WinTerminalPath
    $shortcut.WindowStyle = 3
    $shortcut.Save()

    # Cleanup
    Remove-Item $downloadDir -Recurse -Force

    #############################################################
    # Install Docker Desktop
    #############################################################
    Write-Host "INFO: Installing Docker Dekstop." -ForegroundColor Gray
    # Download and Install Docker Desktop
    $arguments = 'install --quiet --accept-license'
    Start-Process "$AgToolsDir\DockerDesktopInstaller.exe" -Wait -ArgumentList $arguments
    Get-ChildItem "$env:USERPROFILE\Desktop\Docker Desktop.lnk" | Remove-Item -Confirm:$false
    Move-Item "$AgToolsDir\settings.json" -Destination "$env:USERPROFILE\AppData\Roaming\Docker\settings.json" -Force
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Start-Sleep -Seconds 10
    Get-Process | Where-Object { $_.name -like "Docker Desktop" } | Stop-Process -Force
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"


#############################################################
# Install VSCode extensions
#############################################################
Write-Host "INFO: Installing VSCode extensions: " + ($AgConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
# Install VSCode extensions
foreach ($extension in $AgConfig.VSCodeExtensions) {
    code --install-extension $extension
}
Write-Host "INFO: Developer tools installation complete!" -ForegroundColor Green

    ##############################################################
    # Cleanup
    ##############################################################

    # Creating Hyper-V Manager desktop shortcut
    Write-Host "INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

    # Removing the LogonScript Scheduled Task
    Write-Host "INFO: Removing scheduled logon task so it won't run on next login." -ForegroundColor Gray
    Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false
    Start-Sleep -Seconds 5

    # Executing the deployment logs bundle PowerShell script in a new window
    Write-Host "INFO: Uploading Log Bundle." -ForegroundColor Gray
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

Write-Host "INFO: Deployment is complete. Please enjoy the Agora experience!" -ForegroundColor Green

    Stop-Transcript
