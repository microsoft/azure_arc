
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
$appsRepo           = "jumpstart-agora-apps"
$gitHubAPIBaseUri   = $websiteUrls["githubAPI"]
$workflowStatus     = ""


# GitHub Account Info
$githubAccount      = "agoraedge"
$githubBranch       = "physical_ag"
$gitHubUser         = "agoraedge"
$githubPat          = "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"
$appClonedRepo      = "https://github.com/$githubUser/jumpstart-agora-apps"
$appUpstreamRepo    = "https://github.com/microsoft/jumpstart-agora-apps"



# Azure Account Info
$uniqueGuid         = [Guid]::NewGuid().ToString("N").Substring(0, 5)
$deploymentName     = "agoraphysical"
$resourceGroup      = $deploymentName + "-" + $uniqueGuid + "-" + "RG"
$azureLocation      = "westus2"
$location           = $azureLocation
$acrName            = $deploymentName + $uniqueGuid
$cosmosDBName       = $deploymentName + $uniqueGuid
$database           = "Orders"
$container          = "Orders"
$templateBaseUrl    = $Env:templateBaseUrl
$adxClusterName     = $deploymentName + $uniqueGuid
$iotHubHostName     = "iothostname"


Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
#Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Force TLS 1.2 for connections to prevent TLS/SSL errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#####################################################################
# Install Azure CLI 
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/17)" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\.cli\") -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}
$Env:AZURE_CONFIG_DIR = $cliDir.FullName

#Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
#az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")

Write-Host "[$(Get-Date -Format t)] INFO: Installing Github CLI..." -ForegroundColor DarkGreen
winget install --id GitHub.cli


Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI..." -ForegroundColor Gray
az login


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
#$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
#$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
#Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
Connect-AzAccount | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
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
#az cosmosdb create --name $cosmosDBName --resource-group $resourceGroup --default-consistency-level Eventual --locations regionName="$location" failoverPriority=0 isZoneRedundant=False --locations regionName="$failoverLocation" failoverPriority=1 isZoneRedundant=False
az cosmosdb create --name $cosmosDBName --resource-group $resourceGroup --kind GlobalDocumentDB --server-version 3.6 --default-consistency-level Eventual --locations $location --capabilities EnableServerless
az cosmosdb sql database create --account-name $cosmosDBName --resource-group $resourceGroup --name $cosmosDBName
az cosmosdb sql container create --account-name $cosmosDBName --resource-group $resourceGroup --database-name $cosmosDBName --name $container
Write-Host "[$(Get-Date -Format t)] INFO: CosmosDB $cosmosDBName Created" -ForegroundColor DarkGreen



#####################################################################
# Install AKSEE on Host and Configure Single Cluster with Internal vSwitch
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring AKSEE as Single Machine Cluster (Step 4/17)" -ForegroundColor DarkGreen
$url = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStart.ps1"
Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStart.ps1
Unblock-File .\AksEdgeQuickStart.ps1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$subscriptionId = (Get-AzSubscription).Id
$TenantId = (Get-AzSubscription).TenantId
.\AksEdgeQuickStart.ps1 -SubscriptionId $subscriptionId -TenantId $TenantId -Location $location
Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.



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

#Write-Host "INFO: Creating GitHub branches to $appsRepo fork" -ForegroundColor Gray
#$branches = $AgConfig.GitBranches


Write-Host "INFO: Switching to main branch" -ForegroundColor Gray
git checkout main

Write-Host "INFO: GitHub repo configuration complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Configure GitOps in Cluster
#####################################################################
#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps (Step 6)" -ForegroundColor DarkGreen

Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache namespace on all clusters" -ForegroundColor Gray
# Cleaning up images-cache namespace on all clusters
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    Start-Job -Name images-cache-cleanup -ScriptBlock {
        $cluster = $using:cluster
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deleting images-cache namespace on cluster $clusterName" -ForegroundColor Gray
        kubectl delete namespace "images-cache" --context $clusterName
    }
}

#  TODO - this looks app-specific so should perhaps be moved to the app loop
while ($workflowStatus.status -ne "completed") {
    Write-Host "INFO: Waiting for pos-app-initial-images-build workflow to complete" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $workflowStatus = (gh run list --workflow=pos-app-initial-images-build.yml --json status) | ConvertFrom-Json
}

foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    Start-Job -Name gitops -ScriptBlock {

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

        $AgConfig       = $using:AgConfig
        $cluster        = $using:cluster
        $site           = $cluster.Value
        $siteName       = $site.FriendlyName.ToLower()
        $namingGuid     = $using:namingGuid
        $resourceGroup  = $using:resourceGroup
        $appClonedRepo  = $using:appClonedRepo
        $appsRepo       = $using:appsRepo

        $AgConfig.AppConfig.GetEnumerator() | sort-object -Property @{Expression = { $_.value.Order }; Ascending = $true } | ForEach-Object {
            $app         = $_
            $store       = $cluster.value.Branch.ToLower()
            $clusterName = $cluster.value.ArcClusterName + "-$namingGuid"
            $branch      = $cluster.value.Branch.ToLower()
            $configName  = $app.value.GitOpsConfigName.ToLower()
            $clusterType = $cluster.value.Type
            $namespace   = $app.value.Namespace
            $appName     = $app.Value.KustomizationName
            $appPath     = $app.Value.KustomizationPath
            $retryCount  = 0
            $maxRetries  = 2

            Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $($cluster.Value.ArcClusterName+"-$namingGuid")" -ForegroundColor Gray
            if ($clusterType -eq "AKS") {
                $type = "managedClusters"
                $clusterName = $cluster.value.ArcClusterName
            }
            else {
                $type = "connectedClusters"
            }
            if ($branch -eq "main") {
                $store = "dev"
            }

            # Wait for Kubernetes API server to become available
            $apiServer = kubectl config view --context $cluster.Name.ToLower() --minify -o jsonpath='{.clusters[0].cluster.server}'
            $apiServerAddress = $apiServer -replace '.*https://| .*$'
            $apiServerFqdn    = ($apiServerAddress -split ":")[0]
            $apiServerPort    = ($apiServerAddress -split ":")[1]

            do {
                $result = Test-NetConnection -ComputerName $apiServerFqdn -Port $apiServerPort -WarningAction SilentlyContinue
                if ($result.TcpTestSucceeded) {
                    break
                }
                else {
                    Start-Sleep -Seconds 5
                }
            } while ($true)
            If ($app.Value.ConfigMaps){
                # download the config files
                foreach ($configMap in $app.value.ConfigMaps.GetEnumerator()){
                    $repoPath     = $configMap.value.RepoPath
                    $configPath   = "$configMapDir\$appPath\config\$($configMap.Name)\$branch"
                    $iotHubName   = $iotHubHostName.replace(".azure-devices.net", "")
                    $gitHubUser   = $gitHubUser
                    $githubBranch = $githubBranch

                    New-Item -Path $configPath -ItemType Directory -Force | Out-Null

                    $githubApiUrl = "https://api.github.com/repos/$gitHubUser/$appsRepo/$($repoPath)?ref=$branch"
                    Get-GitHubFiles -githubApiUrl $githubApiUrl -folderPath $configPath

                    # replace the IoT Hub name and the SAS Tokens with the deployment specific values
                    # this is a one-off for the broker, but needs to be generalized if/when another app needs it
                    If ($configMap.Name -eq "mqtt-broker-config"){
                        $configFile = "$configPath\mosquitto.conf"
                        $update     = (Get-Content $configFile -Raw)
                        $update     = $update -replace "Ag-IotHub-\w*", $iotHubName

                        foreach ($device in $site.IoTDevices) {
                            $deviceId = "$device-$($site.FriendlyName)"
                            $deviceSASToken = $(az iot hub generate-sas-token --device-id $deviceId --hub-name $iotHubName --resource-group $resourceGroup --duration (60 * 60 * 24 * 30) --query sas -o tsv --only-show-errors)
                            $update = $update -replace "Chicago", $site.FriendlyName
                            $update = $update -replace "SharedAccessSignature.*$($device).*",$deviceSASToken
                        }

                        $update | Set-Content $configFile
                    }

                    # create the namespace if needed
                    If (-not (kubectl get namespace $namespace --context $siteName)){
                        kubectl create namespace $namespace --context $siteName
                    }
                    # create the configmap
                    kubectl create configmap $configMap.name --from-file=$configPath --namespace $namespace --context $siteName
                }
            }

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
}

while ($(Get-Job -Name gitops).State -eq 'Running') {
    #Write-Host "[$(Get-Date -Format t)] INFO: Waiting for GitOps configuration to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
    Receive-Job -Name gitops -WarningAction SilentlyContinue
    Start-Sleep -Seconds 60
}

Get-Job -name gitops | Remove-Job
Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
Write-Host