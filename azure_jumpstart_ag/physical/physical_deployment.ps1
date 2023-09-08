#Requires -RunAsAdministrator
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Get Environment Variables and User Inputs
#####################################################################
#$AgConfig           = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgConfig           = Import-PowerShellDataFile -Path "./physical_agora_params.psd1"

#####################################################################
# Initialize the environment
#####################################################################

$AgToolsDir         = $AgConfig.AgDirectories["AgToolsDir"]
$AgIconsDir         = $AgConfig.AgDirectories["AgIconDir"]
$AgAppsRepo         = $AgConfig.AgDirectories["AgAppsRepo"]
$configMapDir       = $agConfig.AgDirectories["AgConfigMapDir"]
$websiteUrls        = $AgConfig.URLs
$appsRepo           = $AgConfig.GitHub["appsRepo"]
$gitHubAPIBaseUri   = $websiteUrls["githubAPI"]
$workflowStatus     = ""
$namespace          = "contoso-supermarket"


# GitHub Account Info
$githubAccount      = $AgConfig.GitHub["githubAccount"]
$githubBranch       = $AgConfig.GitHub["githubBranch"]
$gitHubUser         = $AgConfig.GitHub["gitHubUser"]
$githubPat          = $AgConfig.GitHub["githubPat"]
$appClonedRepo      = "https://github.com/$githubUser/jumpstart-agora-apps"
$appUpstreamRepo    = "https://github.com/microsoft/jumpstart-agora-apps"
$appsRepo           = "jumpstart-agora-apps"

#Deployment Info
$deploymentName     = $AgConfig.AzureDeployment["deploymentName"]
$azureLocation      = $AgConfig.AzureDeployment["azureLocation"]
$database           = $AgConfig.AzureDeployment["database"]
$container          = $AgConfig.AzureDeployment["container"]
$appId              = $AgConfig.AzureDeployment["appId"]
$spnClientSecret    = $AgConfig.AzureDeployment["spnClientSecret"]
$spnTenantId        = $AgConfig.AzureDeployment["spnTenantId"]
$spnClientID        = $AgConfig.AzureDeployment["spnClientID"]
$database           = "Orders"
$container          = "Orders"

# Azure Account Info
$uniqueGuid         = [Guid]::NewGuid().ToString("N").Substring(0, 5)
$resourceGroup      = $deploymentName + "-" + $uniqueGuid + "-" + "RG"
$location           = $azureLocation
$acrName            = $deploymentName + $uniqueGuid
$cosmosDBName       = $deploymentName + $uniqueGuid
$adxClusterName     = $deploymentName + $uniqueGuid
$cosmosDBEndpoint   = "https://" + $deploymentName + $uniqueGuid + ".documents.azure.com:443"
$clusterName        = "agorak3s" + $uniqueGuid
$hostname           = hostname

if (Test-Path -Path $AgConfig.AgDirectories["AgLogsDir"]) {
    Remove-Item -Path $AgConfig.AgDirectories["AgLogsDir"] -Recurse -Force
}

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
#Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Force TLS 1.2 for connections to prevent TLS/SSL errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#####################################################################
# TODO / Check for Requirements 
#####################################################################
# 1. Check if Hyper-V is installed
# 2. Check if Azure CLI is installed
# 3. Check if Git is installed
# 4. Check CPU/Mem


#####################################################################
# Install Azure CLI 
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Ag Folders in C: (Step 1/17)" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}
$Env:AZURE_CONFIG_DIR = $cliDir.FullName


Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")

Write-Host "[$(Get-Date -Format t)] INFO: Installing Github CLI..." -ForegroundColor DarkGreen
winget install --id GitHub.cli


Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI..." -ForegroundColor Gray
New-Item -Path ($AgConfig.AgDirectories["AgAppsRepo"]) -ItemType Directory



#####################################################################
# Install Git
#####################################################################

winget install --id Git.Git -e --source winget


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
# Install PowerShell modules
if ($AgConfig.PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($AgConfig.PowerShellModules -join ', ') -ForegroundColor Gray
    foreach ($module in $AgConfig.PowerShellModules) {
        Install-Module -Name $module -Force -AllowClobber | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
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


$azurePassword = ConvertTo-SecureString $spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $spnTenantId -ServicePrincipal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
$subscriptionId = (Get-AzSubscription).Id

#####################################################################
# Configure Azure Resources
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Azure Resources... (Step 3/17)" -ForegroundColor DarkGreen

# Resource Group
az group create --name $resourceGroup --location $location
Write-Host "[$(Get-Date -Format t)] INFO: Resource Group $resourceGroup Created" -ForegroundColor DarkGreen

# Azure Container Registry
az acr create --resource-group $resourceGroup --name $acrName --sku Basic
Write-Host "[$(Get-Date -Format t)] INFO: Container Registry $acrName Created" -ForegroundColor DarkGreen

# CosmosDB
az cosmosdb create --name $cosmosDBName --resource-group $resourceGroup --kind GlobalDocumentDB --capabilities EnableServerless
Write-Host "[$(Get-Date -Format t)] INFO: CosmosDB Account $cosmosDBName Created" -ForegroundColor Gray

az cosmosdb sql database create --account-name $cosmosDBName --resource-group $resourceGroup --name "Orders"
Write-Host "[$(Get-Date -Format t)] INFO: CosmosDB DB Created" -ForegroundColor Gray

az cosmosdb sql container create --account-name $cosmosDBName --resource-group $resourceGroup --database-name "Orders" --name $container --partition-key-path '/OrderId'
Write-Host "[$(Get-Date -Format t)] INFO: CosmosDB Container Created" -ForegroundColor DarkGreen


#####################################################################
# Install AKSEE on Host and Configure Single Cluster with Internal vSwitch
#####################################################################

Write-Host "[$(Get-Date -Format t)] INFO: Configuring AKSEE as Single Machine Cluster (Step 4/17)" -ForegroundColor DarkGreen
$msiurl = "https://aka.ms/aks-edge/k3s-msi"
Invoke-WebRequest -Uri $msiurl -OutFile aksee-k3s-msi.msi
$msiFilePath = "aksee-k3s-msi.msi"
$msiInstallLog = "aksedgelog.txt"
Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log `"$msiInstallLog`"" -Wait
Import-Module AksEdge.psm1 -Force
Install-AksEdgeHostFeatures -Force

$jsonObj = New-AksEdgeConfig -DeploymentType SingleMachineCluster
$jsonObj.User.AcceptEula = $true
$jsonObj.User.AcceptOptionalTelemetry = $true
$jsonObj.Init.ServiceIpRangeSize = 10
$jsonObj.Arc.ClusterName = $clusterName
$jsonObj.Arc.Location = $location
$jsonObj.Arc.ResourceGroupName = $resourceGroup
$jsonObj.Arc.SubscriptionId = $subscriptionId
$jsonObj.Arc.TenantId = $spnTenantId
$jsonObj.Arc.ClientId = $spnClientID
$jsonObj.Arc.ClientSecret = $spnClientSecret
$machine = $jsonObj.Machines[0]
$machine.LinuxNode.CpuCount = 4
$machine.LinuxNode.MemoryInMB = 4096
$machine.LinuxNode.DataSizeInGB = 80

#$scriptPath = "./installaksee.ps1"
#Start-Process -FilePath "powershell.exe" -ArgumentList "-File" $scriptPath -Verb RunAs
New-AksEdgeDeployment -JsonConfigString ($jsonObj | ConvertTo-Json -Depth 4)

Write-Host "[$(Get-Date -Format t)] INFO: AKSEE Succesfully Installed. Connecting to Azure..." -ForegroundColor DarkGreen
Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop  
Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop 
Install-Module Az.ConnectedKubernetes -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
Install-Module Az.ConnectedMachine -Force -AllowClobber -ErrorAction Stop

# Connect Arc-enabled kubernetes
#TODO Uncomment line to connect host to Azure
Connect-AksEdgeArc -JsonConfigString (($jsonObj | ConvertTo-Json -Depth 4))

#Connect Server to Arc
Write-Host "[$(Get-Date -Format t)] INFO: Arc-enabling $hostname server." -ForegroundColor Gray

#TODO Uncomment line to connect host to Azure
Connect-AzConnectedMachine -ResourceGroupName $resourceGroup -Name "$hostname" -Location $location 
Start-Sleep -Seconds 60

#Add C:\Program Files\AksEdge\kubectl to PATH
$kubePath = "C:\Program Files\AksEdge\kubectl"
Copy-Item "C:\Program Files\AksEdge\kubectl\kubectl.exe" -Destination "kubectl.exe"
Copy-Item "C:\Program Files\AksEdge\kubectl\kubectl.exe" -Destination "C:\Windows\System32\kubectl.exe"
$env:Path += ";$newPath"

Write-Host "INFO: Kubectl added to Path" -ForegroundColor DarkGreen
kubectl create ns testagora



#####################################################################
# Configure Jumpstart Agora Apps repository
#####################################################################
Write-Host "INFO: Forking and preparing Apps repository locally (Step 5/17)" -ForegroundColor DarkGreen
Set-Location $AgAppsRepo
Write-Host "INFO: Checking if the $appsRepo repository is forked" -ForegroundColor Gray
$retryCount = 0
$maxRetries = 5
do {
    $forkExists = $false
    try {
        $response = Invoke-RestMethod -Uri "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo"
        if ($response) {
            write-host "INFO: Fork exists....Proceeding" -ForegroundColor Gray
            $forkExists = $true
        }
    }
    catch {
        if ($retryCount -lt $maxRetries) {
            Write-Host "ERROR: $githubUser/$appsRepo Fork doesn't exist, please fork https://github.com/microsoft/jumpstart-agora-apps to proceed (attempt $retryCount/$maxRetries) . . . waiting 60 seconds" -ForegroundColor Red
            $retryCount++
            $forkExists = $false
            start-sleep -Seconds 60
        }
        else {
            Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached, $githubUser/$appsRepo Fork doesn't exist. Exiting." -ForegroundColor Red
            exit
        }
    }
} until ($forkExists -eq $true)

Write-Host "INFO: Checking if the GitHub access token is valid." -ForegroundColor Gray
do {
    $response = gh auth status 2>&1
    if ($response -match "authentication failed") {
        write-host "ERROR: The GitHub Personal access token is not valid" -ForegroundColor Red
        Write-Host "INFO: Please try to re-generate the personal access token and provide it here (https://aka.ms/AgoraPreReqs): "
        do {
            $githubPAT = Read-Host "GitHub personal access token"
        } while ($githubPAT -eq "")
    }
} until (
    $response -notmatch "authentication failed"
)

Write-Host "INFO: The GitHub Personal access token is valid. Proceeding." -ForegroundColor DarkGreen
$Env:GITHUB_TOKEN = $githubPAT.Trim()
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $githubPAT.Trim(), [System.EnvironmentVariableTarget]::Machine)

Write-Host "INFO: Checking if the personal access token is assigned on the $githubUser/$appsRepo Fork" -ForegroundColor Gray
$headers = @{
    Authorization  = "token $githubPat"
    "Content-Type" = "application/json"
}
$retryCount = 0
$maxRetries = 5
$uri = "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/actions/secrets"
do {
    try {
        $response=Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        Write-Host "INFO: Personal access token is assigned on $githubUser/$appsRepo fork" -ForegroundColor DarkGreen
        $PatAssigned = $true
    }
    catch {
        if ($retryCount -lt $maxRetries) {
            Write-Host "ERROR: Personal access token is not assigned on $githubUser/$appsRepo fork. Please assign the personal access token to your fork (https://aka.ms/AgoraPreReqs) (attempt $retryCount/$maxRetries).....waiting 60 seconds" -ForegroundColor Red
            $PatAssigned = $false
            $retryCount++
            start-sleep -Seconds 60
        }
        else{
            Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached, the personal access token is not assigned to $githubUser/$appsRepo. Exiting." -ForegroundColor Red
            exit
        }
    }
} until ($PatAssigned -eq $true)


Write-Host "INFO: Cloning the GitHub repository locally" -ForegroundColor Gray
git clone "https://$githubPat@github.com/$githubUser/$appsRepo.git" "$AgAppsRepo\$appsRepo"
Set-Location "$AgAppsRepo\$appsRepo"

Write-Host "INFO: Verifying 'Administration' permissions" -ForegroundColor Gray
$retryCount = 0
$maxRetries = 5

$body = @{
    required_status_checks        = $null
    enforce_admins                = $false
    required_pull_request_reviews = @{
        required_approving_review_count = 0
    }
    dismiss_stale_reviews         = $true
    restrictions                  = $null
} | ConvertTo-Json

do {
    try {
        $response = Invoke-WebRequest -Uri "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/branches/main/protection" -Method Put -Headers $headers -Body $body -ContentType "application/json"
    }
    catch {
        if ($retryCount -lt $maxRetries) {
            Write-Host "ERROR: The GitHub Personal access token doesn't seem to have 'Administration' write permissions, please assign the right permissions (https://aka.ms/AgoraPreReqs) (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
            $retryCount++
            start-sleep -Seconds 60
        }
        else {
            Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached, the personal access token doesn't have 'Administration' write permissions assigned. Exiting." -ForegroundColor Red
            exit
        }
    }
} until ($response)
Write-Host "INFO: 'Administration' write permissions verified" -ForegroundColor DarkGreen


Write-Host "INFO: Checking if there are existing branch protection policies" -ForegroundColor Gray
$protectedBranches = Invoke-RestMethod -Uri "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/branches?protected=true" -Method GET -Headers $headers
foreach ($branch in $protectedBranches) {
    $branchName = $branch.name
    $deleteProtectionUrl = "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/branches/$branchName/protection"
    Invoke-RestMethod -Uri $deleteProtectionUrl -Headers $headers -Method Delete
    Write-Host "INFO: Deleted protection policy for branch: $branchName" -ForegroundColor Gray
}

Write-Host "INFO: Pulling latests changes to GitHub repository" -ForegroundColor Gray
git config --global user.email "dev@agora.com"
git config --global user.name "Agora Dev"
git remote add upstream "$appUpstreamRepo.git"
git fetch upstream
git checkout main
git reset --hard upstream/main
git push origin main -f
git pull
git remote remove upstream
git remote add upstream "$appClonedRepo.git"

Write-Host "INFO: Creating GitHub workflows" -ForegroundColor Gray
New-Item -ItemType Directory ".github/workflows" -Force
$githubApiUrl = "$gitHubAPIBaseUri/repos/$githubAccount/azure_arc/contents/azure_jumpstart_ag/artifacts/workflows?ref=$githubBranch"
$response = Invoke-RestMethod -Uri $githubApiUrl
$fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
$fileUrls | ForEach-Object {
    $fileName = $_.Substring($_.LastIndexOf("/") + 1)
    $outputFile = Join-Path "$AgAppsRepo\$appsRepo\.github\workflows" $fileName
    Invoke-RestMethod -Uri $_ -OutFile $outputFile
}
git add .
git commit -m "Pushing GitHub Actions to apps fork"
git push
Start-Sleep -Seconds 20

Write-Host "INFO: Verifying 'Secrets' permissions" -ForegroundColor Gray
$retryCount = 0
$maxRetries = 5
do {
    $response = gh secret set "test" -b "test" 2>&1
    if ($response -match "error") {
        if ($retryCount -eq $maxRetries) {
            Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached, the personal access token doesn't have 'Secrets' write permissions assigned. Exiting." -ForegroundColor Red
            exit
        }
        else {
            $retryCount++
            write-host "ERROR: The GitHub Personal access token doesn't seem to have 'Secrets' write permissions, please assign the right permissions (https://aka.ms/AgoraPreReqs) (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
            Start-Sleep -Seconds 60
        }
    }
} while ($response -match "error" -or $retryCount -ge $maxRetries)
gh secret delete test
Write-Host "INFO: 'Secrets' write permissions verified" -ForegroundColor DarkGreen

Write-Host "INFO: Verifying 'Actions' permissions" -ForegroundColor Gray
$retryCount = 0
$maxRetries = 5
do {
    $response = gh workflow enable update-files.yml 2>&1
    if ($response -match "failed") {
        if ($retryCount -eq $maxRetries) {
            Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached, the personal access token doesn't have 'Actions' write permissions assigned. Exiting." -ForegroundColor Red
            exit
        }
        else {
            $retryCount++
            write-host "ERROR: The GitHub Personal access token doesn't seem to have 'Actions' write permissions, please assign the right permissions (https://aka.ms/AgoraPreReqs) (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
            Start-Sleep -Seconds 60
        }
    }
} while ($response -match "failed" -or $retryCount -ge $maxRetries)

Write-Host "INFO: 'Actions' write permissions verified" -ForegroundColor DarkGreen
write-host "INFO: Creating GitHub secrets" -ForegroundColor Gray
Write-Host "INFO: Getting Cosmos DB access key" -ForegroundColor Gray
Write-Host "INFO: Adding GitHub secrets to apps fork" -ForegroundColor Gray
gh api -X PUT "/repos/$githubUser/$appsRepo/actions/permissions/workflow" -F can_approve_pull_request_reviews=true
gh repo set-default "$githubUser/$appsRepo"
gh secret set "SPN_CLIENT_ID" -b $spnClientID
gh secret set "SPN_CLIENT_SECRET" -b $spnClientSecret
gh secret set "ACR_NAME" -b $acrName
gh secret set "ACR_USERNAME" -b $spnClientId
gh secret set "ACR_PASSWORD" -b $spnClientSecret
gh secret set "PAT_GITHUB" -b $githubPat
gh secret set "COSMOS_DB_ENDPOINT" -b $cosmosDBEndpoint
gh secret set "SPN_TENANT_ID" -b $spnTenantId

Write-Host "INFO: Updating ACR name and Cosmos DB endpoint in all branches" -ForegroundColor Gray
gh workflow run update-files.yml
while ($workflowStatus.status -ne "completed") {
    Write-Host "INFO: Waiting for update-files workflow to complete" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $workflowStatus = (gh run list --workflow=update-files.yml --json status) | ConvertFrom-Json
}
Write-Host "INFO: Starting Contoso supermarket pos application v1.0 image build" -ForegroundColor Gray
gh workflow run pos-app-initial-images-build.yml

Write-Host "INFO: Switching to main branch" -ForegroundColor Gray
git checkout main

Write-Host "INFO: GitHub repo configuration complete!" -ForegroundColor Green
Write-Host


#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################

Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps (Step 6)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache namespace on all clusters" -ForegroundColor Gray
# Cleaning up images-cache namespace on all clusters

Copy-Item "C:\Program Files\AksEdge\kubectl\kubectl.exe" -Destination "kubectl.exe"
#TODO testing for kubectl not found error
kubectl create ns $namespace
kubectl create namespace "images-cache"



#  TODO - this looks app-specific so should perhaps be moved to the app loop
while ($workflowStatus.status -ne "completed") {
    Write-Host "INFO: Waiting for pos-app-initial-images-build workflow to complete" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $workflowStatus = (gh run list --workflow=pos-app-initial-images-build.yml --json status) | ConvertFrom-Json
}




#####################################################################
# Setup Azure Container registry pull secret on clusters
#####################################################################


Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 9/17)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure Container registry on $clusterName"
kubectl create secret docker-registry acr-secret `
                --namespace $namespace `
                --docker-server="$acrName.azurecr.io" `
                --docker-username="$spnClientId" `
                --docker-password="$spnClientSecret" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")


#####################################################################
# Create secrets for GitHub actions
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Kubernetes secrets" -ForegroundColor Gray
az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
$cosmosDBKey = $(az cosmosdb keys list --name $cosmosDBName --resource-group $resourceGroup --query primaryMasterKey --output tsv)

kubectl create secret generic postgrespw --from-literal=POSTGRES_PASSWORD='Agora123!!' --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")


kubectl create secret generic cosmoskey --from-literal=COSMOS_KEY=$cosmosDBKey --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")


kubectl create secret generic github-token --from-literal=token=$githubPat --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")


Write-Host "[$(Get-Date -Format t)] INFO: Cluster secrets configuration complete." -ForegroundColor Green
Write-Host

foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    

        Function Get-GitHubFiles ($githubApiUrl, $folderPath, [Switch]$excludeFolders) {
            # Force TLS 1.2 for connections to prevent TLS/SSL errors
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $response = Invoke-RestMethod -Uri $githubApiUrl
            $fileUrls = $response | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
            $fileUrls | ForEach-Object {
                $fileName = $_.Substring($_.LastIndexOf("/") + 1)
                $outputFile = Join-Path $folderPath $fileName
                Invoke-RestMethod -Uri $_ -OutFile $outputFile
            }

            If (-not $excludeFolders) {
                $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
                    $folderName = $_.name
                    $path = Join-Path $folderPath $folderName
                    New-Item $path -ItemType Directory -Force -ErrorAction Continue
                    Get-GitHubFiles -githubApiUrl $_.url -folderPath $path
                }
            }
        }

        

        $site           = $cluster.Value
        $siteName       = $site.FriendlyName.ToLower()
       
       
        az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
        $AgConfig.AppConfig.GetEnumerator() | sort-object -Property @{Expression = { $_.value.Order }; Ascending = $true } | ForEach-Object {
            $app         = $_
            $store       = "dev"
            $branch      = "main"
            $configName  = $app.value.GitOpsConfigName.ToLower()
            $clusterType = "$cluster.value.Type"            
            $namespace   = $app.value.Namespace
            $appName     = $app.Value.KustomizationName
            $appPath     = $app.Value.KustomizationPath
            $retryCount  = 0
            $maxRetries  = 2

            #Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $($cluster.Value.ArcClusterName+"-$namingGuid")" -ForegroundColor Gray
            Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $clustername" -ForegroundColor Gray
            $type = "connectedClusters"
            
            # Wait for Kubernetes API server to become available
            $apiServer = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
            

            $apiServerAddress = $apiServer -replace '.*https://| .*$'
            $apiServerFqdn    = ($apiServerAddress -split ":")[0]
            $apiServerPort    = ($apiServerAddress -split ":")[1]

            az k8s-configuration flux create `
                --cluster-name $clusterName `
                --resource-group $resourceGroup `
                --name $configName `
                --cluster-type $type `
                --url $appClonedRepo `
                --branch $branch `
                --sync-interval 5s `
                --kustomization name=$appName path=$appPath/$store prune=true retry_interval=1m `
                --timeout 10m `
                --namespace $namespace `
                --only-show-errors `
            | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

            do {
                $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json) | convertFrom-JSON
                if ($configStatus.ComplianceState -eq "Compliant") {
                    Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration $configName is ready on $clusterName" -ForegroundColor DarkGreen | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                }
                else {
                    if ($configStatus.ComplianceState -ne "Non-compliant") {
                        Start-Sleep -Seconds 20
                    }
                    elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                        Start-Sleep -Seconds 20
                        $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json) | convertFrom-JSON
                        if ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                            $retryCount++
                            Write-Host "[$(Get-Date -Format t)] INFO: Attempting to re-install $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                            Write-Host "[$(Get-Date -Format t)] INFO: Deleting $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                            az k8s-configuration flux delete `
                            --resource-group $resourceGroup `
                            --cluster-name $clusterName `
                            --cluster-type $type `
                            --name $configName `
                            --force `
                            --yes `
                            --only-show-errors `
                            | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

                            Start-Sleep -Seconds 10
                            Write-Host "[$(Get-Date -Format t)] INFO: Re-creating $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

                            az k8s-configuration flux create `
                            --cluster-name $clusterName `
                            --resource-group $resourceGroup `
                            --name $configName `
                            --cluster-type $type `
                            --url $appClonedRepo `
                            --branch $branch `
                            --sync-interval 5s `
                            --kustomization name=$appName path=$appPath/$store prune=true `
                            --timeout 30m `
                            --namespace $namespace `
                            --only-show-errors `
                        | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                        }
                    }
                    elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -eq $maxRetries) {
                        Write-Host "[$(Get-Date -Format t)] ERROR: GitOps configuration $configName has failed on $clusterName. Exiting..." -ForegroundColor White -BackgroundColor Red | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                        break
                    }
                }
            } until ($configStatus.ComplianceState -eq "Compliant")
        }
    
}

$services = kubectl get services --all-namespaces -o json | ConvertFrom-Json
$matchingServices = $services.items | Where-Object {
    $_.spec.ports.port -contains 5000 -and
    $_.spec.type -eq "LoadBalancer"
}
$posIps = $matchingServices.status.loadBalancer.ingress.ip
$posIps = "http://" + $posIps + ":5000"


$matchingServices = $services.items | Where-Object {
    $_.spec.ports.port -contains 81 -and
    $_.spec.type -eq "LoadBalancer"
}
$storemanagerip = $matchingServices.status.loadBalancer.ingress.ip
$storemanagerip = "http://" + $storemanagerip + ":81"

Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
Write-Host "Agora Physical Deployment Complete." -ForegroundColor Green
Write-Host "Resource Group: "  $resourceGroup -ForegroundColor Green
Write-Host "POS Endpoint: " $posIps -ForegroundColor Green
Write-Host "Store Manager Endpoint: " $storemanagerip -ForegroundColor Green
Write-Host