# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$global:AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
$global:AgToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
$global:AgIconsDir = $AgConfig.AgDirectories["AgIconDir"]
$global:AgAppsRepo = $AgConfig.AgDirectories["AgAppsRepo"]
$global:configMapDir = $agConfig.AgDirectories["AgConfigMapDir"]
$global:AgDeploymentFolder = $AgConfig.AgDirectories["AgL1Files"]
$global:AgPowerShellDir    = $AgConfig.AgDirectories["AgPowerShellDir"]
$global:AgLogsDir = $AgConfig.AgDirectories["AgLogsDir"]
$global:AgTestsDir = $AgConfig.AgDirectories["AgTestsDir"]
$global:scenario = $Env:scenario
$global:websiteUrls = $AgConfig.URLs
$global:githubAccount = $Env:githubAccount
$global:githubBranch = $Env:githubBranch
$global:resourceGroup = $Env:resourceGroup
$global:azureLocation = $Env:azureLocation
$global:spnClientId = $Env:spnClientId
$global:spnClientSecret = $Env:spnClientSecret
$global:spnTenantId = $Env:spnTenantId
$global:subscriptionId = $Env:subscriptionId
$global:adminUsername = $Env:adminUsername
$global:templateBaseUrl = $Env:templateBaseUrl
$global:adxClusterName = $Env:adxClusterName
$global:namingGuid = $Env:namingGuid
$global:adminPassword = $Env:adminPassword
$global:customLocationRPOID = $Env:customLocationRPOID
$global:acrName = $Env:acrName
$global:appsRepo = "jumpstart-agora-apps"

if ($scenario -eq "contoso_supermarket") {
    $global:appUpstreamRepo = "https://github.com/azure/jumpstart-apps"
    $global:appsRepo = "jumpstart-apps"
    $global:githubUser = $Env:githubUser
    $global:githubPat = $Env:GITHUB_TOKEN
    $global:cosmosDBName = $Env:cosmosDBName
    $global:cosmosDBEndpoint = $Env:cosmosDBEndpoint
    $global:gitHubAPIBaseUri = $websiteUrls["githubAPI"]
    $global:workflowStatus = ""
    $global:appClonedRepo = "https://github.com/$githubUser/jumpstart-apps"
}elseif ($scenario -eq "contoso_motors") {
    $global:appUpstreamRepo = "https://github.com/azure/jumpstart-apps"
    $global:aioNamespace = "azure-iot-operations"
    $global:mqListenerService = "aio-broker-insecure"
    $global:mqttExplorerReleasesUrl = $websiteUrls["mqttExplorerReleases"]
    $global:stagingStorageAccountName = $Env:stagingStorageAccountName
    $global:aioStorageAccountName = $Env:aioStorageAccountName
    $global:spnObjectId = $Env:spnObjectId
    $global:k3sArcDataClusterName = $Env:k3sArcDataClusterName
    $global:k3sArcClusterName = $Env:k3sArcClusterName
    $global:tenantId = $Env:tenantId
}elseif ($scenario -eq "contoso_hypermarket"){
    $global:appUpstreamRepo = "https://github.com/Azure/jumpstart-apps"
    $global:tenantId = $Env:tenantId
    $global:aioNamespace = "azure-iot-operations"
    $global:mqListenerService = "aio-broker-insecure"
    $global:mqttExplorerReleasesUrl = $websiteUrls["mqttExplorerReleases"]
    $global:stagingStorageAccountName = $Env:stagingStorageAccountName
    $global:aioStorageAccountName = $Env:aioStorageAccountName
    $global:k3sArcDataClusterName = $Env:k3sArcDataClusterName
    $global:k3sArcClusterName = $Env:k3sArcClusterName
    $global:azureOpenAIModel = $Env:azureOpenAIModel
    $global:openAIEndpoint = $Env:openAIEndpoint
    $global:speachToTextEndpoint = $Env:speachToTextEndpoint
    $global:openAIDeploymentName = $Env:openAIDeploymentName
}

#####################################################################
# Importing fuctions
#####################################################################
Import-Module "$AgPowerShellDir\common.psm1" -Force -DisableNameChecking
Import-Module "$AgPowerShellDir\contoso_supermarket.psm1" -Force -DisableNameChecking
Import-Module "$AgPowerShellDir\contoso_motors.psm1" -Force -DisableNameChecking
Import-Module "$AgPowerShellDir\contoso_hypermarket.psm1" -Force -DisableNameChecking

Start-Transcript -Path ($AgLogsDir + "\AgLogonScript.log")
Write-Host "Executing Jumpstart Agora automation scripts..."
Write-Host "Selected global scenario:" $global:scenario
Write-Host "Selected scenario:" $scenario
$startTime = Get-Date

# Remove registry keys that are used to automatically logon the user (only used for first-time setup)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$keys = @("AutoAdminLogon", "DefaultUserName", "DefaultPassword")

foreach ($key in $keys) {
    try {
        $property = Get-ItemProperty -Path $registryPath -Name $key -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath -Name $key
        Write-Host "Removed registry key that are used to automatically logon the user: $key"
    } catch {
        Write-Verbose "Key $key does not exist."
    }
}

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Force TLS 1.2 for connections to prevent TLS/SSL errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$global:password = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
$global:Credentials = New-Object System.Management.Automation.PSCredential($AgConfig.L1Username, $password)

#####################################################################
# Setup Azure CLI
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/17)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI" -ForegroundColor Gray
if($scenario -eq "contoso_hypermarket" -or $scenario -eq "contoso_motors"){
    az login --identity | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
}else{
    az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
}
az account set -s $subscriptionId
Deploy-AzCLI

#####################################################################
# Setup Azure PowerShell and register providers
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell (Step 2/17)" -ForegroundColor DarkGreen
Deploy-AzPowerShell

#############################################################
# Install Windows Terminal, WSL2, and Ubuntu
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing dev tools (Step 3/17)" -ForegroundColor DarkGreen
Deploy-WindowsTools


#####################################################################
# Configure Jumpstart Agora Apps repository
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Write-Host "INFO: Forking and preparing Apps repository locally (Step 4/17)" -ForegroundColor DarkGreen
    SetupSupermarketRepo
}


#####################################################################
# Azure IoT Hub resources preparation
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Write-Host "[$(Get-Date -Format t)] INFO: Creating Azure IoT resources (Step 5/17)" -ForegroundColor DarkGreen
    Deploy-AzureIoTHub
}

#####################################################################
# Configure L1 virtualization infrastructure
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure (Step 6/17)" -ForegroundColor DarkGreen
    Deploy-VirtualizationInfrastructure
}

#####################################################################
# Setup Azure Container registry on cloud AKS staging environment
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Deploy-AzContainerRegistry
}

#####################################################################
# Get clusters config files
#####################################################################
if($scenario -eq "contoso_motors"){
    Get-K3sConfigFileContosoMotors 
    Merge-K3sConfigFilesContosoMotors
    #Set-K3sClustersContosoMotors # comment this out to not use kube-vip
}

if($scenario -eq "contoso_hypermarket"){
    Get-K3sConfigFile
    Merge-K3sConfigFiles
    Set-K3sClusters
}

#####################################################################
# Creating Kubernetes namespaces on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating namespaces on clusters (Step 8/17)" -ForegroundColor DarkGreen
Deploy-ClusterNamespaces

#####################################################################
# Setup Azure Container registry pull secret on clusters
#####################################################################
if($scenario -ne "contoso_hypermarket"){
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 9/17)" -ForegroundColor DarkGreen
    Deploy-ClusterSecrets
}

#####################################################################
# Cache contoso-supermarket images on all clusters
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Deploy-K8sImagesCache
}

#####################################################################
# Connect the AKS Edge Essentials clusters and hosts to Azure Arc
#####################################################################
if($scenario -eq "contoso_supermarket"){
    Write-Host "[$(Get-Date -Format t)] INFO: Connecting AKS Edge clusters to Azure with Azure Arc (Step 10/17)" -ForegroundColor DarkGreen
    Deploy-AzArcK8sAKSEE
}

#####################################################################
# Installing flux extension on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on clusters (Step 11/17)" -ForegroundColor DarkGreen
Deploy-ClusterFluxExtension

#####################################################################
# Deploying nginx on AKS cluster
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying nginx on AKS cluster (Step 12/17)" -ForegroundColor DarkGreen
    kubectx $AgConfig.SiteConfig.Staging.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
    helm repo add $AgConfig.nginx.RepoName $AgConfig.nginx.RepoURL | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
    helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")

    helm install $AgConfig.nginx.ReleaseName $AgConfig.nginx.ChartName `
        --create-namespace `
        --namespace $AgConfig.nginx.Namespace `
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
}

##############################################################
# Deploy Kubernetes Prometheus Stack for Observability
##############################################################
Deploy-Prometheus -AgConfig $AgConfig

#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
if ($scenario -eq "contoso_supermarket") {
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps (Step 13/17)" -ForegroundColor DarkGreen
    Deploy-SupermarketConfigs
}

if ($scenario -eq "contoso_motors") {
    Deploy-AIO-M3ContosoMotors
    $mqttIpArray=Set-MQTTIpAddress
    Deploy-MQTTExplorer -mqttIpArray $mqttIpArray
    Deploy-MotorsConfigs
}elseif($scenario -eq "contoso_hypermarket"){
    Deploy-AIO-M3
    $mqttIpArray=Set-MQTTIpAddress
    Deploy-MQTTExplorer -mqttIpArray $mqttIpArray
    Set-AIServiceSecrets
    Set-EventHubSecrets
    Set-SQLSecret
    if ($Env:deployGPUNodes -eq "true") {
        Set-GPUOperator
    }
    Deploy-HypermarketConfigs
    Set-LoadBalancerBackendPools
}

#####################################################################
# Deploy Azure Workbook for Infrastructure Observability
#####################################################################
if($scenario -ne "contoso_hypermarket"){
    Deploy-Workbook "arc-inventory-workbook.bicep"
}
#####################################################################
# Deploy Azure Workbook for OS Performance
#####################################################################
if($scenario -ne "contoso_hypermarket"){
    Deploy-Workbook "arc-osperformance-workbook.bicep"
}

#####################################################################
# Deploy Azure Data Explorer Dashboard Reports
#####################################################################
if($scenario -eq "contoso_motors"){
    Deploy-ADXDashboardReports
}

#####################################################################
# Deploy Microsoft Fabric
#####################################################################
if($scenario -eq "contoso_hypermarket"){
    Set-MicrosoftFabric
}

##############################################################
# Creating bookmarks and setting merged kubeconfigs
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Edge Bookmarks in Favorites Bar (Step 15/17)" -ForegroundColor DarkGreen
if($scenario -eq "contoso_supermarket"){
    Deploy-SupermarketBookmarks
}elseif($scenario -eq "contoso_motors"){
    Deploy-MotorsBookmarks
}elseif($scenario -eq "contoso_hypermarket"){
    Deploy-HypermarketBookmarks
}

##############################################################
# Creating database connections desktop shortcuts
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating database connections desktop shortcuts (Step 16/17)" -ForegroundColor DarkGreen
if($scenario -eq "contoso_hypermarket"){
    Set-DatabaseConnectionsShortcuts
}

##############################################################
# Cleanup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up scripts and uploading logs (Step 17/17)" -ForegroundColor DarkGreen
# Creating Hyper-V Manager desktop shortcut

if($scenario -ne "contoso_hypermarket") {
    Write-Host "[$(Get-Date -Format t)] INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force
}

if($scenario -eq "contoso_supermarket"){
    Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache job" -ForegroundColor Gray
    while ($(Get-Job -Name images-cache-cleanup).State -eq 'Running') {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for images-cache job to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
        Receive-Job -Name images-cache-cleanup -WarningAction SilentlyContinue
        Start-Sleep -Seconds 60
    }
    Get-Job -name images-cache-cleanup | Remove-Job
}

# Create desktop shortcut for Logs-folder
$WshShell = New-Object -comObject WScript.Shell
$LogsPath = "C:\Ag\Logs"
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

# Configure Windows Terminal as the default terminal application
$registryPath = "HKCU:\Console\%%Startup"

if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
} else {
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
}


# Removing the LogonScript Scheduled Task
Write-Host "[$(Get-Date -Format t)] INFO: Removing scheduled logon task so it won't run on next login." -ForegroundColor Gray
Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false

Write-Host "Creating deployment logs bundle"

$RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
$LogsBundleTempDirectory = "$Env:windir\TEMP\LogsBundle-$RandomString"
$null = New-Item -Path $LogsBundleTempDirectory -ItemType Directory -Force

#required to avoid "file is being used by another process" error when compressing the logs
Copy-Item -Path "$($AgConfig.AgDirectories["AgDir"])\Logs\*.log" -Destination $LogsBundleTempDirectory -Force -PassThru
Compress-Archive -Path "$LogsBundleTempDirectory\*.log" -DestinationPath "$($AgConfig.AgDirectories["AgDir"])\Logs\LogsBundle-$RandomString.zip" -PassThru

Write-Host "[$(Get-Date -Format t)] INFO: Changing Wallpaper" -ForegroundColor Gray

# bmp file is required for BGInfo
$imgPath = $AgConfig.AgDirectories["AgDir"] + "\wallpaper.png"
$targetImgPath = $($imgPath -replace 'png','bmp')
Convert-JSImageToBitMap -SourceFilePath $imgPath -DestinationFilePath $targetImgPath

Set-JSDesktopBackground -ImagePath $targetImgPath

Write-Host "Running tests to verify infrastructure"

& "$AgTestsDir\Invoke-Test.ps1"

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes. Enjoy the Agora experience!" -ForegroundColor Green
Write-Host

Stop-Transcript
