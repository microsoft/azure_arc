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
$global:industry = $Env:industry
$global:websiteUrls = $AgConfig.URLs
$global:githubAccount = $Env:githubAccount
$global:githubBranch = $Env:githubBranch
$global:githubUser = $Env:githubUser
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
$global:appClonedRepo = "https://github.com/$githubUser/jumpstart-agora-apps"
$global:appUpstreamRepo = "https://github.com/microsoft/jumpstart-agora-apps"
$global:appsRepo = "jumpstart-agora-apps"
if ($industry -eq "retail") {
    $global:githubPat = $Env:GITHUB_TOKEN
    $global:acrName = $Env:acrName.ToLower()
    $global:cosmosDBName = $Env:cosmosDBName
    $global:cosmosDBEndpoint = $Env:cosmosDBEndpoint
    $global:gitHubAPIBaseUri = $websiteUrls["githubAPI"]
    $global:workflowStatus = ""
}elseif ($industry -eq "manufacturing") {
    $global:aioNamespace = "azure-iot-operations"
    $global:mqListenerService = "aio-mq-dmqtt-frontend"
    $global:mqttExplorerReleasesUrl = $websiteUrls["mqttExplorerReleases"]
    $global:stagingStorageAccountName = $Env:stagingStorageAccountName
    $global:aioStorageAccountName = $Env:aioStorageAccountName
    $global:spnObjectId = $Env:spnObjectId
    $global:stcontainerName = $Env:stcontainerName
}

#####################################################################
# Importing fuctions
#####################################################################
Import-Module "$AgPowerShellDir\common.psm1" -Force -DisableNameChecking
Import-Module "$AgPowerShellDir\retail.psm1" -Force -DisableNameChecking
Import-Module "$AgPowerShellDir\manufacturing.psm1" -Force -DisableNameChecking

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

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
Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
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
if ($industry -eq "retail") {
    Write-Host "INFO: Forking and preparing Apps repository locally (Step 4/17)" -ForegroundColor DarkGreen
    SetupRetailRepo
}


#####################################################################
# Azure IoT Hub resources preparation
#####################################################################
if ($industry -eq "retail") {
    Write-Host "[$(Get-Date -Format t)] INFO: Creating Azure IoT resources (Step 5/17)" -ForegroundColor DarkGreen
    Deploy-AzureIoTHub
}

#####################################################################
# Configure L1 virtualization infrastructure
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure (Step 6/17)" -ForegroundColor DarkGreen
Deploy-VirtualizationInfrastructure

#####################################################################
# Setup Azure Container registry on cloud AKS staging environment
#####################################################################
if ($industry -eq "retail") {
    Deploy-AzContainerRegistry
}

#####################################################################
# Creating Kubernetes namespaces on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating namespaces on clusters (Step 8/17)" -ForegroundColor DarkGreen
Deploy-ClusterNamespaces

#####################################################################
# Setup Azure Container registry pull secret on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 9/17)" -ForegroundColor DarkGreen
Deploy-ClusterSecrets

#####################################################################
# Cache contoso-supermarket images on all clusters
#####################################################################
Deploy-K8sImagesCache

#####################################################################
# Connect the AKS Edge Essentials clusters and hosts to Azure Arc
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Connecting AKS Edge clusters to Azure with Azure Arc (Step 10/17)" -ForegroundColor DarkGreen
Deploy-AzArcK8s

#####################################################################
# Installing flux extension on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on clusters (Step 11/17)" -ForegroundColor DarkGreen
Deploy-ClusterFluxExtension

#####################################################################
# Deploying nginx on AKS cluster
#####################################################################
if ($industry -eq "retail") {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying nginx on AKS cluster (Step 12/17)" -ForegroundColor DarkGreen
    kubectx $AgConfig.SiteConfig.Staging.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
    helm repo add $AgConfig.nginx.RepoName $AgConfig.nginx.RepoURL | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
    helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")

    helm install $AgConfig.nginx.ReleaseName $AgConfig.nginx.ChartName `
        --create-namespace `
        --namespace $AgConfig.nginx.Namespace `
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
}
#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
if ($industry -eq "retail") {
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps (Step 13/17)" -ForegroundColor DarkGreen
    Deploy-RetailConfigs
}

if ($industry -eq "manufacturing") {
    $kubectlMonShells = @()
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        $arguments = "[System.Console]::Title = '$clusterName';for (0 -lt 1) { kubectl get pod -n azure-iot-operations --context $clusterName  | Sort-Object -Descending;Start-Sleep -Seconds 5;Clear-Host}"
        $kubectlMonShell = Start-Process powershell -ArgumentList $arguments -PassThru
        $kubectlMonShells+=$kubectlMonShell
    }
    Deploy-AIO
    #Deploy-InfluxDb
    Deploy-ESA
    #Deploy-ManufacturingConfigs
}

##############################################################
# Get MQ IP address
##############################################################
if ($industry -eq "manufacturing") {
    Configure-MQTTIpAddress
}

#####################################################################
# Deploy Kubernetes Prometheus Stack for Observability
#####################################################################
Deploy-Prometheus

#####################################################################
# Deploy Azure Workbook for Infrastructure Observability
#####################################################################
Deploy-Workbook

##############################################################
# Creating bookmarks
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Edge Bookmarks in Favorites Bar (Step 15/17)" -ForegroundColor DarkGreen
#Deploy-Bookmarks

##############################################################
# Cleanup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up scripts and uploading logs (Step 17/17)" -ForegroundColor DarkGreen
# Creating Hyper-V Manager desktop shortcut
Write-Host "[$(Get-Date -Format t)] INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

if($industry -eq "retail"){
    Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache job" -ForegroundColor Gray
    while ($(Get-Job -Name images-cache-cleanup).State -eq 'Running') {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for images-cache job to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
        Receive-Job -Name images-cache-cleanup -WarningAction SilentlyContinue
        Start-Sleep -Seconds 60
    }
    Get-Job -name images-cache-cleanup | Remove-Job
}


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

# Kill the open PowerShell monitoring kubectl get pods
if ($industry -eq "manufacturing") {
    foreach ($shell in $kubectlMonShells) {
        Stop-Process -Id $shell.Id
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Starting Docker Desktop" -ForegroundColor Green
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes. Enjoy the Agora experience!" -ForegroundColor Green
Write-Host

Stop-Transcript