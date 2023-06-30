# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$AgConfig           = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgToolsDir         = $AgConfig.AgDirectories["AgToolsDir"]
$AgIconsDir         = $AgConfig.AgDirectories["AgIconDir"]
$AgAppsRepo         = $AgConfig.AgDirectories["AgAppsRepo"]
$configMapDir       = $agConfig.AgDirectories["AgConfigMapDir"]
$websiteUrls        = $AgConfig.URLs
$githubAccount      = $Env:githubAccount
$githubBranch       = $Env:githubBranch
$githubUser         = $Env:githubUser
$githubPat          = $Env:GITHUB_TOKEN
$resourceGroup      = $Env:resourceGroup
$azureLocation      = $Env:azureLocation
$spnClientId        = $Env:spnClientId
$spnClientSecret    = $Env:spnClientSecret
$spnTenantId        = $Env:spnTenantId
$adminUsername      = $Env:adminUsername
$acrName            = $Env:acrName.ToLower()
$cosmosDBName       = $Env:cosmosDBName
$cosmosDBEndpoint   = $Env:cosmosDBEndpoint
$templateBaseUrl    = $Env:templateBaseUrl
$appClonedRepo      = "https://github.com/$githubUser/jumpstart-agora-apps"
$appUpstreamRepo    = "https://github.com/microsoft/jumpstart-agora-apps"
$adxClusterName     = $Env:adxClusterName
$namingGuid         = $Env:namingGuid
$appsRepo           = "jumpstart-agora-apps"
$adminPassword      = $Env:adminPassword
$gitHubAPIBaseUri   = $websiteUrls["githubAPI"]
$workflowStatus     = ""

Start-Transcript -Path ($AgConfig.AgDirectories["AgLogsDir"] + "\AgLogonScript.log")
Write-Header "Executing Jumpstart Agora automation scripts"
$startTime = Get-Date

# Disable Windows firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Force TLS 1.2 for connections to prevent TLS/SSL errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#####################################################################
# Setup Azure CLI
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI (Step 1/17)" -ForegroundColor DarkGreen
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

#####################################################################
# Setup Azure PowerShell and register providers
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell (Step 2/17)" -ForegroundColor DarkGreen
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
if ($AgConfig.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($AgConfig.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $AgConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzPowerShell.log")
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

#############################################################
# Install Windows Terminal, WSL2, and Ubuntu
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing dev tools (Step 3/17)" -ForegroundColor DarkGreen

$step3job = Invoke-Command -ScriptBlock {

$AgConfig = $using:AgConfig
$websiteUrls = $using:websiteUrls
$AgToolsDir         = $using:AgToolsDir
$adminUsername = $using:adminUsername


If ($PSVersionTable.PSVersion.Major -ge 7) { Write-Error "This script needs be run by version of PowerShell prior to 7.0" }
$downloadDir = "C:\WinTerminal"
$frameworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$WindowsTerminalKitPath = "$downloadDir\Microsoft.WindowsTerminal.PreinstallKit.zip"
$windowsTerminalPath = "$downloadDir\WindowsTerminal"
$filenamePattern = "*PreinstallKit.zip"
$terminalDownloadUri = ((Invoke-RestMethod -Method GET -Uri $websiteUrls["windowsTerminal"]).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -First 1

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Write-Host "[$(Get-Date -Format t)] INFO: Downloading binaries." -ForegroundColor Gray

$ProgressPreference = 'SilentlyContinue'

Invoke-WebRequest -Uri $websiteUrls["vcLibs"] -OutFile ( New-Item -Path $frameworkPkgPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
Invoke-WebRequest -Uri $terminalDownloadUri -OutFile ( New-Item -Path $windowsTerminalKitPath -Force ) | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

$ProgressPreference = 'Continue'

# Extract Windows Terminal PreinstallKit
Write-Host "[$(Get-Date -Format t)] INFO: Expanding Windows Terminal PreinstallKit." -ForegroundColor Gray
Expand-Archive $WindowsTerminalKitPath $windowsTerminalPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install WSL latest kernel update
Write-Host "[$(Get-Date -Format t)] INFO: Installing WSL." -ForegroundColor Gray
msiexec /i "$AgToolsDir\wsl_update_x64.msi" /qn | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Write-Host "[$(Get-Date -Format t)] INFO: Installing Windows Terminal" -ForegroundColor Gray
Add-AppxPackage -Path $frameworkPkgPath | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Install the Windows Terminal prereqs
foreach ($file in Get-ChildItem $windowsTerminalPath -Filter *x64*.appx) {
    Add-AppxPackage -Path $file.FullName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

# Install Windows Terminal
foreach ($file in Get-ChildItem $windowsTerminalPath -Filter *.msixbundle) {
    Add-AppxPackage -Path $file.FullName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

# Configure Windows Terminal
Set-Location $Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState

# Launch Windows Terminal for default settings.json to be created
$action = New-ScheduledTaskAction -Execute $((Get-Command wt.exe).Source)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(1)
$null = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName WindowsTerminalInit

# Give process time to initiate and create settings file
Start-Sleep 10

# Stop Windows Terminal process
Get-Process WindowsTerminal | Stop-Process

Unregister-ScheduledTask -TaskName WindowsTerminalInit -Confirm:$false

$settings = Get-Content .\settings.json | ConvertFrom-Json
$settings.profiles.defaults.elevate

# Configure the default profile setting "Run this profile as Administrator" to "true"
$settings.profiles.defaults | Add-Member -Name elevate -MemberType NoteProperty -Value $true -Force

$settings | ConvertTo-Json -Depth 8 | Set-Content .\settings.json

# Install Ubuntu
Write-Host "[$(Get-Date -Format t)] INFO: Installing Ubuntu" -ForegroundColor Gray
Add-AppxPackage -Path "$AgToolsDir\Ubuntu.appx" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Setting WSL environment variables
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + ";C:\Users\$adminUsername\Ubuntu", "User")

# Initializing the wsl ubuntu app without requiring user input
$ubuntu_path = "c:/users/$adminUsername/AppData/Local/Microsoft/WindowsApps/ubuntu"
Invoke-Expression -Command "$ubuntu_path install --root" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")

# Create Windows Terminal shortcut
$WshShell = New-Object -comObject WScript.Shell
$WinTerminalPath = (Get-ChildItem "C:\Program Files\WindowsApps" -Recurse | Where-Object { $_.name -eq "wt.exe" }).FullName
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Windows Terminal.lnk")
$Shortcut.TargetPath = $WinTerminalPath
$shortcut.WindowStyle = 3
$shortcut.Save()

#############################################################
# Install VSCode extensions
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($AgConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
# Install VSCode extensions
foreach ($extension in $AgConfig.VSCodeExtensions) {
    code --install-extension $extension 2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Tools.log")
}

#############################################################
# Install Docker Desktop
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing Docker Desktop." -ForegroundColor DarkGreen
# Download and Install Docker Desktop
$arguments = 'install --quiet --accept-license'
Start-Process "$AgToolsDir\DockerDesktopInstaller.exe" -Wait -ArgumentList $arguments
Get-ChildItem "$Env:USERPROFILE\Desktop\Docker Desktop.lnk" | Remove-Item -Confirm:$false
Copy-Item "$AgToolsDir\settings.json" -Destination "$Env:USERPROFILE\AppData\Roaming\Docker\settings.json" -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep -Seconds 10
Get-Process | Where-Object { $_.name -like "Docker Desktop" } | Stop-Process -Force
Start-Sleep -Seconds 5
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
# Cleanup
Remove-Item $downloadDir -Recurse -Force

} -JobName step3 -ThrottleLimit 16 -AsJob -ComputerName .

Write-Host "[$(Get-Date -Format t)] INFO: Tools setup initiated in background job." -ForegroundColor Green

$step3job

Write-Host

#####################################################################
# Configure Jumpstart Agora Apps repository
#####################################################################
Write-Host "INFO: Forking and preparing Apps repository locally (Step 4/17)" -ForegroundColor DarkGreen
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
        Write-Host "INFO: Please try to re-generate the personal access token and provide it here [Placeholder for readme]: "
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
            Write-Host "ERROR: Personal access token is not assigned on $githubUser/$appsRepo fork. Please assign the personal access token to your fork [Placeholder to readme] (attempt $retryCount/$maxRetries).....waiting 60 seconds" -ForegroundColor Red
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
            Write-Host "ERROR: The GitHub Personal access token doesn't seem to have 'Administration' write permissions, please assign the right permissions [Placeholder for docs] (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
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
            write-host "ERROR: The GitHub Personal access token doesn't seem to have 'Secrets' write permissions, please assign the right permissions [Placeholder for docs] (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
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
            write-host "ERROR: The GitHub Personal access token doesn't seem to have 'Actions' write permissions, please assign the right permissions [Placeholder for docs] (attempt $retryCount/$maxRetries)...waiting 60 seconds" -ForegroundColor Red
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

Write-Host "INFO: Creating GitHub branches to $appsRepo fork" -ForegroundColor Gray
$branches = $AgConfig.GitBranches
foreach ($branch in $branches) {
    try {
        $response = Invoke-RestMethod -Uri "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/branches/$branch"
        if ($response) {
            if ($branch -ne "main") {
                Write-Host "INFO: branch $branch already exists! Deleting and recreating the branch" -ForegroundColor Gray
                git push origin --delete $branch
                git branch -d $branch
                git fetch origin
                git checkout main
                git pull origin main
                git checkout -b $branch main
                git pull origin main
                git push --set-upstream origin $branch
            }
        }
    }
    catch {
        Write-Host "INFO: Creating $branch branch" -ForegroundColor Gray
        git fetch origin
        git checkout main
        git pull origin main
        git checkout -b $branch main
        git pull origin main
        git push --set-upstream origin $branch
    }
}
Write-Host "INFO: Cleaning up any other branches" -ForegroundColor Gray
$existingBranches = gh api "repos/$githubUser/$appsRepo/branches" | ConvertFrom-Json
$branches = $AgConfig.GitBranches
foreach ($branch in $existingBranches) {
    if ($branches -notcontains $branch.name){
        $branchToDelete = $branch.name
        git push origin --delete $branchToDelete
    }
}

Write-Host "INFO: Switching to main branch" -ForegroundColor Gray
git checkout main

Write-Host "INFO: Adding branch protection policies for all branches" -ForegroundColor Gray
foreach ($branch in $branches) {
    Write-Host "INFO: Adding branch protection policies for $branch branch" -ForegroundColor Gray
    $headers = @{
        "Authorization" = "Bearer $githubPat"
        "Accept"        = "application/vnd.github+json"
    }
    $body = @{
        required_status_checks        = $null
        enforce_admins                = $false
        required_pull_request_reviews = @{
            required_approving_review_count = 0
        }
        dismiss_stale_reviews         = $true
        restrictions                  = $null
    } | ConvertTo-Json

    Invoke-WebRequest -Uri "$gitHubAPIBaseUri/repos/$githubUser/$appsRepo/branches/$branch/protection" -Method Put -Headers $headers -Body $body -ContentType "application/json"
}
Write-Host "INFO: GitHub repo configuration complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Azure IoT Hub resources preparation
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Azure IoT resources (Step 6/17)" -ForegroundColor DarkGreen
if ($githubUser -ne "microsoft") {
    $iotHubHostName = $Env:iotHubHostName
    $iotHubName = $iotHubHostName.replace(".azure-devices.net", "")
    $sites = $AgConfig.SiteConfig.Values
    Write-Host "[$(Get-Date -Format t)] INFO: Create an Azure IoT device for each site" -ForegroundColor Gray
    foreach ($site in $sites) {
        foreach ($device in $site.IoTDevices) {
            $deviceId = "$device-$($site.FriendlyName)"
            Add-AzIotHubDevice -ResourceGroupName $resourceGroup -IotHubName $iotHubName -DeviceId $deviceId -EdgeEnabled | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\IoT.log")
        }
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Azure IoT Hub configuration complete!" -ForegroundColor Green
    Write-Host
}
else {
    Write-Host "[$(Get-Date -Format t)] ERROR: You have to fork the jumpstart-agora-apps repository!" -ForegroundColor Red
}

### BELOW IS AN ALTERNATIVE APPROACH TO IMPORT DASHBOARD USING README INSTRUCTIONS
$adxDashBoardsDir = $AgConfig.AgDirectories["AgAdxDashboards"]
$dataEmulatorDir = $AgConfig.AgDirectories["AgDataEmulator"]
$kustoCluster = Get-AzKustoCluster -ResourceGroupName $resourceGroup -Name $adxClusterName
if ($null -ne $kustoCluster) {
    $adxEndPoint = $kustoCluster.Uri
    if ($null -ne $adxEndPoint -and $adxEndPoint -ne "") {
        $ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx_dashboards/adx-dashboard-orders-payload.json").Content -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
        Set-Content -Path "$adxDashBoardsDir\adx-dashboard-orders-payload.json" -Value $ordersDashboardBody -Force -ErrorAction Ignore
        $iotSensorsDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx_dashboards/adx-dashboard-iotsensor-payload.json") -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
        Set-Content -Path "$adxDashBoardsDir\adx-dashboard-iotsensor-payload.json" -Value $iotSensorsDashboardBody -Force -ErrorAction Ignore
    }
    else {
        Write-Host "[$(Get-Date -Format t)] ERROR: Unable to find Azure Data Explorer endpoint from the cluster resource in the resource group."
    }
}

# Download DataEmulator.zip into Agora folder and unzip
$emulatorPath = "$dataEmulatorDir\DataEmulator.zip"
Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/data_emulator/DataEmulator.zip" -OutFile $emulatorPath

# Unzip DataEmulator.zip to copy DataEmulator exe and config file to generate sample data for dashboards
if (Test-Path -Path $emulatorPath) {
    Expand-Archive -Path "$emulatorPath" -DestinationPath "$dataEmulatorDir" -ErrorAction SilentlyContinue -Force
}

# Download products.json and stores.json file to use in Data Emulator
$productsJsonPath = "$dataEmulatorDir\products.json"
Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/data_emulator/products.json" -OutFile $productsJsonPath
if (!(Test-Path -Path $productsJsonPath)) {
    Write-Host "Unabled to download products.json file. Please download manually from GitHub into the data_emulator folder."
}

$storesJsonPath = "$dataEmulatorDir\stores.json"
Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/data_emulator/stores.json" -OutFile $storesJsonPath
if (!(Test-Path -Path $storesJsonPath)) {
    Write-Host "Unabled to download stores.json file. Please download manually from GitHub into the data_emulator folder."
}

# Download icon file
$iconPath = "$AgIconsDir\emulator.ico"
Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/icons/emulator.ico" -OutFile $iconPath
if (!(Test-Path -Path $iconPath)) {
    Write-Host "Unabled to download emulator.ico file. Please download manually from GitHub into the icons folder."
}

# Create desktop shortcut
$shortcutLocation = "$Env:Public\Desktop\Data Emulator.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "$dataEmulatorDir\DataEmulator.exe"
$shortcut.IconLocation = "$iconPath, 0"
$shortcut.WindowStyle = 7
$shortcut.Save()

#####################################################################
# Configure L1 virtualization infrastructure
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring L1 virtualization infrastructure (Step 5/17)" -ForegroundColor DarkGreen
$password = ConvertTo-SecureString $AgConfig.L1Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($AgConfig.L1Username, $password)

# Turn the .kube folder to a shared folder where all Kubernetes kubeconfig files will be copied to
$kubeFolder = "$Env:USERPROFILE\.kube"
New-Item -ItemType Directory $kubeFolder -Force | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-SmbShare -Name "kube" -Path "$Env:USERPROFILE\.kube" -FullAccess "Everyone" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Enable Enhanced Session Mode on Host
Write-Host "[$(Get-Date -Format t)] INFO: Enabling Enhanced Session Mode on Hyper-V host" -ForegroundColor Gray
Set-VMHost -EnableEnhancedSessionMode $true | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create Internal Hyper-V switch for the L1 nested virtual machines
New-VMSwitch -Name $AgConfig.L1SwitchName -SwitchType Internal | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
$ifIndex = (Get-NetAdapter -Name ("vEthernet (" + $AgConfig.L1SwitchName + ")")).ifIndex
New-NetIPAddress -IPAddress $AgConfig.L1DefaultGateway -PrefixLength 24 -InterfaceIndex $ifIndex | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
New-NetNat -Name $AgConfig.L1SwitchName -InternalIPInterfaceAddressPrefix $AgConfig.L1NatSubnetPrefix | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

#####################################################################
# Deploying the nested L1 virtual machines
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Fetching Windows 11 IoT Enterprise VM image from Azure storage. This may take a few minutes." -ForegroundColor Yellow
#azcopy cp $AgConfig.PreProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
azcopy cp $AgConfig.ProdVHDBlobURL $AgConfig.AgDirectories["AgVHDXDir"] --recursive=true --check-length=false --log-level=ERROR | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

# Create three virtual machines from the base VHDX image
$vhdxPath = Get-ChildItem $AgConfig.AgDirectories["AgVHDXDir"] -Filter *.vhdx | Select-Object -ExpandProperty FullName
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        # Create disks for each site host
        Write-Host "[$(Get-Date -Format t)] INFO: Creating $($site.Name) disk." -ForegroundColor Gray
        $destVhdxPath = "$($AgConfig.AgDirectories["AgVHDXDir"])\$($site.Name)Disk.vhdx"
        $destPath = $AgConfig.AgDirectories["AgVHDXDir"]
        New-VHD -ParentPath $vhdxPath -Path $destVhdxPath -Differencing | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

        # Create a new virtual machine and attach the existing virtual hard disk
        Write-Host "[$(Get-Date -Format t)] INFO: Creating and configuring $($site.Name) virtual machine." -ForegroundColor Gray
        New-VM -Name $site.Name `
            -Path $destPath `
            -MemoryStartupBytes $AgConfig.L1VMMemory `
            -BootDevice VHD `
            -VHDPath $destVhdxPath `
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
# Create an array with VM names
$VMnames = (Get-VM).Name
foreach ($VM in $VMNames) {
    Copy-VMFile $VM -SourcePath "$PsHome\Profile.ps1" -DestinationPath "C:\Deployment\Profile.ps1" -CreateFullPath -FileSource Host -Force
}
########################################################################
# Prepare L1 nested virtual machines for AKS Edge Essentials bootstrap
########################################################################
foreach ($site in $AgConfig.SiteConfig.GetEnumerator()) {
    if ($site.Value.Type -eq "AKSEE") {
        Write-Host "[$(Get-Date -Format t)] INFO: Renaming computer name of $($site.Name)" -ForegroundColor Gray
        $ErrorActionPreference = "SilentlyContinue"
        Invoke-Command -VMName $site.Name -Credential $Credentials -ScriptBlock {
            $site = $using:site
            (gwmi win32_computersystem).Rename($site.Name)
        } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")
        $ErrorActionPreference = "Continue"
        Stop-VM -Name $site.Name -Force -Confirm:$false
        Start-VM -Name $site.Name
    }
}

foreach ($VM in $VMNames) {
    $VMStatus = Get-VMIntegrationService -VMName $VM -Name Heartbeat
    while ($VMStatus.PrimaryStatusDescription -ne "OK") {
        $VMStatus = Get-VMIntegrationService -VMName $VM -Name Heartbeat
        write-host "[$(Get-Date -Format t)] INFO: Waiting for $VM to finish booting." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}

Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
    $hostname = hostname
    $ProgressPreference = "SilentlyContinue"
    ###########################################
    # Preparing environment folders structure
    ###########################################
    Write-Host "[$(Get-Date -Format t)] INFO: Preparing folder structure on $hostname." -ForegroundColor Gray
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"
    $kubeFolder = "$Env:USERPROFILE\.kube"

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
    $websiteUrls = $using:websiteUrls

    ##########################################
    # Deploying AKS Edge Essentials clusters
    ##########################################
    $deploymentFolder = "C:\Deployment" # Deployment folder is already pre-created in the VHD image
    $logsFolder = "$deploymentFolder\Logs"

    # Assigning network adapter IP address
    $NetIPAddress = $AgConfig.SiteConfig[$Env:COMPUTERNAME].NetIPAddress
    $DefaultGateway = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DefaultGateway
    $PrefixLength = $AgConfig.SiteConfig[$Env:COMPUTERNAME].PrefixLength
    $DNSClientServerAddress = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DNSClientServerAddress
    Write-Host "[$(Get-Date -Format t)] INFO: Configuring networking interface on $hostname with IP address $NetIPAddress." -ForegroundColor Gray
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $ifIndex = (Get-NetAdapter -Name $AdapterName).ifIndex
    New-NetIPAddress -IPAddress $NetIPAddress -DefaultGateway $DefaultGateway -PrefixLength $PrefixLength -InterfaceIndex $ifIndex | Out-Null
    Set-DNSClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $DNSClientServerAddress | Out-Null

    ###########################################
    # Validating internet connectivity
    ###########################################
    $timeElapsed = 0
    do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for internet connection to be healthy on $hostname." -ForegroundColor Gray
        Start-Sleep -Seconds 5
        $timeElapsed = $timeElapsed + 10
    } until ((Test-Connection bing.com -Count 1 -ErrorAction SilentlyContinue) -or ($timeElapsed -eq 60))

    # Fetching latest AKS Edge Essentials msi file
    Write-Host "[$(Get-Date -Format t)] INFO: Fetching latest AKS Edge Essentials install file on $hostname." -ForegroundColor Gray
    Invoke-WebRequest $websiteUrls["aksEEk3s"] -OutFile $deploymentFolder\AKSEEK3s.msi

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

    ###############################################################################
    # Setting up replacement parameters for AKS Edge Essentials config json file
    ###############################################################################
    Write-Host "[$(Get-Date -Format t)] INFO: Building AKS Edge Essentials config json file on $hostname." -ForegroundColor Gray
    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $AdapterName = (Get-NetAdapter -Name Ethernet*).Name
    $namingGuid = $using:namingGuid
    $arcClusterName = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ArcClusterName + "-$namingGuid"
    $replacementParams = @{
        "ServiceIPRangeStart-null"    = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ServiceIPRangeStart
        "1000"                        = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $AgConfig.SiteConfig[$Env:COMPUTERNAME].ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DefaultGateway
        "2000"                        = $AgConfig.SiteConfig[$Env:COMPUTERNAME].PrefixLength
        "DnsServer-null"              = $AgConfig.SiteConfig[$Env:COMPUTERNAME].DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $AgConfig.SiteConfig[$Env:COMPUTERNAME].LinuxNodeIp4Address
        "ClusterName-null"            = $arcClusterName
        "Location-null"               = $using:azureLocation
        "ResourceGroupName-null"      = $using:resourceGroup
        "SubscriptionId-null"         = $using:subscriptionId
        "TenantId-null"               = $using:spnTenantId
        "ClientId-null"               = $using:spnClientId
        "ClientSecret-null"           = $using:spnClientSecret
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

Write-Host "[$(Get-Date -Format t)] INFO: Installing AKS Edge Essentials (Step 7/17)" -ForegroundColor DarkGreen
foreach ($VMName in $VMNames) {
    $Session = New-PSSession -VMName $VMName -Credential $Credentials
    Write-Host "[$(Get-Date -Format t)] INFO: Rebooting $VMName." -ForegroundColor Gray
    Invoke-Command -Session $Session -ScriptBlock {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Deployment\AKSEEBootstrap.ps1"
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "Startup Scan" -Action $Action -Trigger $Trigger -User $Env:USERNAME -Password 'Agora123!!' -RunLevel Highest | Out-Null
        Restart-Computer -Force -Confirm:$false
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
    Remove-PSSession $Session | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
}

Write-Host "[$(Get-Date -Format t)] INFO: Sleeping for three (3) minutes to allow for AKS EE installs to complete." -ForegroundColor Gray
Start-Sleep -Seconds 180 # Give some time for the AKS EE installs to complete. This will take a few minutes.

#####################################################################
# Monitor until the kubeconfig files are detected and copied over
#####################################################################
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
        $destinationPath = $Env:USERPROFILE + "\.kube\config-" + $VMName
        $s = New-PSSession -VMName $VMName -Credential $credential
        Copy-Item -FromSession $s -Path $path -Destination $destinationPath
        $file = Get-Item $destinationPath
        if ($file.Length -eq 0) {
            Write-Host "[$(Get-Date -Format t)] ERROR: Kubeconfig on $VMName is corrupt. This error is unrecoverable. Exiting." -ForegroundColor White -BackgroundColor Red
            exit 1
        }
    }
}

# Display the elapsed time in seconds it took for kubeconfig files to show up in folder
Write-Host "[$(Get-Date -Format t)] INFO: Waiting on kubeconfig files took $($elapsedTime.ToString("g"))." -ForegroundColor Gray

#####################################################################
# Merging kubeconfig files on the L0 virtual machine
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files are present. Merging kubeconfig files for use with kubectx." -ForegroundColor Gray
$kubeconfigpath = ""
foreach ($VMName in $VMNames) {
    $kubeconfigpath = $kubeconfigpath + "$Env:USERPROFILE\.kube\config-" + $VMName.ToLower() + ";"
}
$Env:KUBECONFIG = $kubeconfigpath
kubectl config view --merge --flatten > "$Env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
kubectl config get-clusters --kubeconfig="$Env:USERPROFILE\.kube\config-raw" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1AKSInfra.log")
Rename-Item -Path "$Env:USERPROFILE\.kube\config-raw" -NewName "$Env:USERPROFILE\.kube\config"
$Env:KUBECONFIG = "$Env:USERPROFILE\.kube\config"

# Print a message indicating that the merge is complete
Write-Host "[$(Get-Date -Format t)] INFO: All three kubeconfig files merged successfully." -ForegroundColor Gray

# Validate context switching using kubectx & kubectl
foreach ($cluster in $VMNames) {
    Write-Host "[$(Get-Date -Format t)] INFO: Testing connectivity to kube api on $cluster cluster." -ForegroundColor Gray
    kubectx $cluster.ToLower()
    kubectl get nodes -o wide
}
Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials installs are complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Setup Azure Container registry on cloud AKS staging environment
#####################################################################
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksStagingClusterName --admin | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
kubectx staging="$Env:aksStagingClusterName-admin" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")

# Attach ACR to staging cluster
Write-Host "[$(Get-Date -Format t)] INFO: Attaching Azure Container Registry to AKS staging cluster." -ForegroundColor Gray
az aks update -n $Env:aksStagingClusterName -g $Env:resourceGroup --attach-acr $acrName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")

#####################################################################
# Creating Kubernetes namespaces on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating namespaces on clusters (Step 8/17)" -ForegroundColor DarkGreen
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    foreach ($namespace in $AgConfig.Namespaces) {
        Write-Host "[$(Get-Date -Format t)] INFO: Creating namespace $namespace on $clusterName" -ForegroundColor Gray
        kubectl create namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
    }
}

#####################################################################
# Setup Azure Container registry pull secret on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring secrets on clusters (Step 9/17)" -ForegroundColor DarkGreen
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    foreach ($namespace in $AgConfig.Namespaces) {
        if ($namespace -eq "contoso-supermarket" -or $namespace -eq "images-cache"){
            Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure Container registry on $clusterName"
            kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
            kubectl create secret docker-registry acr-secret `
                --namespace $namespace `
                --docker-server="$acrName.azurecr.io" `
                --docker-username="$Env:spnClientId" `
                --docker-password="$Env:spnClientSecret" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
        }
    }
}

#####################################################################
# Create secrets for GitHub actions
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Kubernetes secrets" -ForegroundColor Gray
$cosmosDBKey = $(az cosmosdb keys list --name $cosmosDBName --resource-group $resourceGroup --query primaryMasterKey --output tsv)
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    Write-Host "[$(Get-Date -Format t)] INFO: Creating Kubernetes secrets on $clusterName" -ForegroundColor Gray
    foreach ($namespace in $AgConfig.Namespaces) {
        if ($namespace -eq "contoso-supermarket" -or $namespace -eq "images-cache"){
            kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
            kubectl create secret generic postgrespw --from-literal=POSTGRES_PASSWORD='Agora123!!' --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
            kubectl create secret generic cosmoskey --from-literal=COSMOS_KEY=$cosmosDBKey --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
            kubectl create secret generic github-token --from-literal=token=$githubPat --namespace $namespace | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
        }
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Cluster secrets configuration complete." -ForegroundColor Green
Write-Host

#####################################################################
# Cache contoso-supermarket images on all clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Caching contoso-supermarket images on all clusters" -ForegroundColor Gray
while ($workflowStatus.status -ne "completed") {
    Write-Host "INFO: Waiting for pos-app-initial-images-build workflow to complete" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $workflowStatus = (gh run list --workflow=pos-app-initial-images-build.yml --json status) | ConvertFrom-Json
}
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $branch = $cluster.Name.ToLower()
    $context = $cluster.Name.ToLower()
    $applicationName = "contoso-supermarket"
    $imageTag = "v1.0"
    $imagePullSecret = "acr-secret"
    $namespace = "images-cache"
    if ($branch -eq "chicago") {
        $branch = "canary"
    }
    if ($branch -eq "seattle") {
        $branch = "production"
    }
    Save-K8sImage -applicationName $applicationName -imageName "contosoai" -imageTag $imageTag -namespace $namespace -imagePullSecret $imagePullSecret -branch $branch -acrName $acrName -context $context
    Save-K8sImage -applicationName $applicationName -imageName "pos" -imageTag $imageTag -namespace $namespace -imagePullSecret $imagePullSecret -branch $branch -acrName $acrName -context $context
    Save-K8sImage -applicationName $applicationName -imageName "pos-cloudsync" -imageTag $imageTag -namespace $namespace -imagePullSecret $imagePullSecret -branch $branch -acrName $acrName -context $context
    Save-K8sImage -applicationName $applicationName -imageName "queue-monitoring-backend" -imageTag $imageTag -namespace $namespace -imagePullSecret $imagePullSecret -branch $branch -acrName $acrName -context $context
    Save-K8sImage -applicationName $applicationName -imageName "queue-monitoring-frontend" -imageTag $imageTag -namespace $namespace -imagePullSecret $imagePullSecret -branch $branch -acrName $acrName -context $context
}

#####################################################################
# Connect the AKS Edge Essentials clusters and hosts to Azure Arc
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Connecting AKS Edge clusters to Azure with Azure Arc (Step 10/17)" -ForegroundColor DarkGreen

# Running pre-checks to ensure that the aksedge ConfigMap is present on all clusters
$maxRetries = 5
$retryInterval = 30 # seconds
$retryCount = 0
foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    if ($clusterName -ne "staging") {
        while ($retryCount -lt $maxRetries) {
            kubectx $clusterName
            $configMap = kubectl get configmap -n aksedge aksedge
            if ($null -eq $configMap) {
                $retryCount++
                Write-Host "Retry ${retryCount}/${maxRetries}: aksedge ConfigMap not found on $clusterName. Retrying in $retryInterval seconds..." | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
                Start-Sleep -Seconds $retryInterval
            }
            else {
                # ConfigMap found, continue with the rest of the script
                Write-Host "aksedge ConfigMap found on $clusterName. Continuing with the script..." | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
                break # Exit the loop
            }
        }

        if ($retryCount -eq $maxRetries) {
            Write-Host "[$(Get-Date -Format t)] ERROR: aksedge ConfigMap not found on $clusterName. Exiting..." -ForegroundColor White -BackgroundColor Red | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
            exit 1 # Exit the script
        }
    }
}

foreach ($VM in $VMNames) {
    $secret = $Env:spnClientSecret
    $clientId = $Env:spnClientId
    $tenantId = $Env:spnTenantId
    $location = $Env:azureLocation
    $resourceGroup = $Env:resourceGroup

    Invoke-Command -VMName $VM -Credential $Credentials -ScriptBlock {
        # Install prerequisites
        . C:\Deployment\Profile.ps1
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
        Redo-Command -ScriptBlock { Connect-AzConnectedMachine -ResourceGroupName $using:resourceGroup -Name "Ag-$hostname-Host" -Location $using:location }

        # Connect clusters to Arc
        $deploymentPath = "C:\Deployment\config.json"
        Write-Host "[$(Get-Date -Format t)] INFO: Arc-enabling $hostname AKS Edge Essentials cluster." -ForegroundColor Gray


        kubectl get svc
        Connect-AksEdgeArc -JsonConfigFilePath $deploymentPath
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
}

#####################################################################
# Tag Azure Arc resources
#####################################################################
$arcResourceTypes = $AgConfig.ArcServerResourceType, $AgConfig.ArcK8sResourceType
$Tag = @{$AgConfig.TagName = $AgConfig.TagValue }

# Iterate over the Arc resources and tag it
foreach ($arcResourceType in $arcResourceTypes) {
    $arcResources = Get-AzResource -ResourceType $arcResourceType -ResourceGroupName $Env:resourceGroup
    foreach ($arcResource in $arcResources) {
        Update-AzTag -ResourceId $arcResource.Id -Tag $Tag -Operation Merge | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ArcConnectivity.log")
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: AKS Edge Essentials clusters and hosts have been registered with Azure Arc!" -ForegroundColor Green
Write-Host


#####################################################################
# Installing flux extension on clusters
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on clusters (Step 11/17)" -ForegroundColor DarkGreen
$retryCount = 0
$maxRetries = 3
$resourceTypes = @($AgConfig.ArcK8sResourceType, $AgConfig.AksResourceType)
$resources = Get-AzResource -ResourceGroupName $Env:resourceGroup | Where-Object { $_.ResourceType -in $resourceTypes }

$jobs = @()

foreach ($resource in $resources) {
    $resourceName = $resource.Name
    $resourceType = $resource.Type
    Write-Host "[$(Get-Date -Format t)] INFO: Installing flux extension on $resourceName" -ForegroundColor Gray
    if ($resourceType -eq $AgConfig.ArcK8sResourceType) {
        $job = Start-Job -ScriptBlock {
            param($resourceName, $resourceType)
            az k8s-extension create --name flux `
                --extension-type Microsoft.flux `
                --scope cluster `
                --cluster-name $resourceName `
                --resource-group $Env:resourceGroup `
                --cluster-type connectedClusters `
                --auto-upgrade false

            $provisioningState = az k8s-extension show --cluster-name $resourceName `
                --resource-group $Env:resourceGroup `
                --cluster-type connectedClusters `
                --name flux `
                --query provisioningState `
                --output tsv

            [PSCustomObject]@{
                ResourceName = $resourceName
                ResourceType = $resourceType
                ProvisioningState = $provisioningState
            }
        } -ArgumentList $resourceName, $resourceType

        $jobs += $job
    }
    else {
        $job = Start-Job -ScriptBlock {
            param($resourceName, $resourceType)

            az k8s-extension create --name flux `
                --extension-type Microsoft.flux `
                --scope cluster `
                --cluster-name $resourceName `
                --resource-group $Env:resourceGroup `
                --cluster-type managedClusters `
                --auto-upgrade false

            $provisioningState = az k8s-extension show --cluster-name $resourceName `
                --resource-group $Env:resourceGroup `
                --cluster-type managedClusters `
                --name flux `
                --query provisioningState `
                --output tsv

            [PSCustomObject]@{
                ResourceName = $resourceName
                ResourceType = $resourceType
                ProvisioningState = $provisioningState
            }
        } -ArgumentList $resourceName, $resourceType

        $jobs += $job
    }
}

# Wait for all jobs to complete
$null = $jobs | Wait-Job

# Check provisioning states for each resource
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    $resourceName = $result.ResourceName
    $resourceType = $result.ResourceType
    $provisioningState = $result.ProvisioningState

    if ($provisioningState -ne "Succeeded") {
        Write-Host "[$(Get-Date -Format t)] INFO: flux extension is not ready yet for $resourceName. Retrying in 10 seconds (attempt $retryCount/$maxRetries)..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
        $retryCount++
    }
    else {
        Write-Host "[$(Get-Date -Format t)] INFO: flux extension installed successfully on $resourceName" -ForegroundColor Gray
    }
}

if ($retryCount -eq $maxRetries) {
    Write-Host "[$(Get-Date -Format t)] ERROR: Retry limit reached. Exiting..." -ForegroundColor White -BackgroundColor Red
}

# Clean up jobs
$jobs | Remove-Job

#####################################################################
# Deploying nginx on AKS cluster
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Deploying nginx on AKS cluster (Step 12/17)" -ForegroundColor DarkGreen
kubectx $AgConfig.SiteConfig.Staging.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
helm repo add $AgConfig.nginx.RepoName $AgConfig.nginx.RepoURL | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")
helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")

helm install $AgConfig.nginx.ReleaseName $AgConfig.nginx.ChartName `
    --create-namespace `
    --namespace $AgConfig.nginx.Namespace `
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Nginx.log")

#####################################################################
# Configuring applications on the clusters using GitOps
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring GitOps (Step 13/17)" -ForegroundColor DarkGreen

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
                    $iotHubName   = $Env:iotHubHostName.replace(".azure-devices.net", "")
                    $gitHubUser   = $Env:gitHubUser
                    $githubBranch = $Env:githubBranch

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

#####################################################################
# Deploy Kubernetes Prometheus Stack for Observability
#####################################################################
$AgMonitoringDir = $AgConfig.AgDirectories["AgMonitoringDir"]
$observabilityNamespace = $AgConfig.Monitoring["Namespace"]
$observabilityDashboards = $AgConfig.Monitoring["Dashboards"]
$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

# Set Prod Grafana API endpoint
$grafanaDS = $AgConfig.Monitoring["ProdURL"] + "/api/datasources"

# Installing Grafana
Write-Host "[$(Get-Date -Format t)] INFO: Installing and Configuring Observability components (Step 14/17)" -ForegroundColor DarkGreen
Write-Host "[$(Get-Date -Format t)] INFO: Installing Grafana." -ForegroundColor Gray
$latestRelease = (Invoke-WebRequest -Uri $websiteUrls["grafana"] | ConvertFrom-Json).tag_name.replace('v', '')
Start-Process msiexec.exe -Wait -ArgumentList "/I $AgToolsDir\grafana-$latestRelease.windows-amd64.msi /quiet" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Prometheus Helm charts
helm repo add prometheus-community $websiteUrls["prometheus"] | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
helm repo update | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Update Grafana Icons
Copy-Item -Path $AgIconsDir\contoso.png -Destination "C:\Program Files\GrafanaLabs\grafana\public\img"
Copy-Item -Path $AgIconsDir\contoso.svg -Destination "C:\Program Files\GrafanaLabs\grafana\public\img\grafana_icon.svg"

Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object {
(Get-Content $_.FullName) -replace 'className:u,src:"public/img/grafana_icon.svg"', 'className:u,src:"public/img/contoso.png"' | Set-Content $_.FullName
}

# Reset Grafana UI
Get-ChildItem -Path 'C:\Program Files\GrafanaLabs\grafana\public\build\*.js' -Recurse -File | ForEach-Object {
(Get-Content $_.FullName) -replace 'Welcome to Grafana', 'Welcome to Grafana for Contoso Supermarket Production' | Set-Content $_.FullName
}

# Reset Grafana Password
$Env:Path += ';C:\Program Files\GrafanaLabs\grafana\bin'
grafana-cli --homepath "C:\Program Files\GrafanaLabs\grafana" admin reset-admin-password $adminPassword | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

# Get Grafana Admin credentials
$adminCredentials = $AgConfig.Monitoring["AdminUser"] + ':' + $adminPassword
$adminEncodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($adminCredentials))

$adminHeaders = @{
    "Authorization" = ("Basic " + $adminEncodedcredentials)
    "Content-Type"  = "application/json"
}

# Get Contoso User credentials
$userCredentials = $adminUsername + ':' + $adminPassword
$userEncodedcredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userCredentials))

$userHeaders = @{
    "Authorization" = ("Basic " + $userEncodedcredentials)
    "Content-Type"  = "application/json"
}

# Download dashboards
foreach ($dashboard in $observabilityDashboards.'grafana.com') {
    $grafanaDBPath = "$AgMonitoringDir\grafana-$dashboard.json"
    $dashboardmetadata = Invoke-RestMethod -Uri https://grafana.com/api/dashboards/$dashboard/revisions
    $dashboardversion = $dashboardmetadata.items | Sort-Object revision | Select-Object -Last 1 | Select-Object -ExpandProperty revision
    Invoke-WebRequest https://grafana.com/api/dashboards/$dashboard/revisions/$dashboardversion/download -OutFile $grafanaDBPath
}

$observabilityDashboardstoImport = @()
$observabilityDashboardstoImport += $observabilityDashboards.'grafana.com'
$observabilityDashboardstoImport += $observabilityDashboards.'custom'

Write-Host "[$(Get-Date -Format t)] INFO: Creating Prod Grafana User" -ForegroundColor Gray
# Add Contoso Operator User
$grafanaUserBody = @{
    name     = $AgConfig.Monitoring["User"] # Display Name
    email    = $AgConfig.Monitoring["Email"]
    login    = $adminUsername
    password = $adminPassword
} | ConvertTo-Json

# Make HTTP request to the API to create user
$retryCount = 10
$retryDelay = 30
do {
    try {
        Invoke-RestMethod -Method Post -Uri "$($AgConfig.Monitoring["ProdURL"])/api/admin/users" -Headers $adminHeaders -Body $grafanaUserBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
        $retryCount = 0
    }
    catch {
        $retryCount--
        if ($retryCount -gt 0) {
            Write-Host "[$(Get-Date -Format t)] INFO: Retrying in $retryDelay seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds $retryDelay
        }
    }
} while ($retryCount -gt 0)

# Deploying Kube Prometheus Stack for stores
$AgConfig.SiteConfig.GetEnumerator() | ForEach-Object {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying Kube Prometheus Stack for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    kubectx $_.Value.FriendlyName.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    # Wait for Kubernetes API server to become available
    $apiServer = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
    $apiServerAddress = $apiServer -replace '.*https://| .*$'
    $apiServerFqdn = ($apiServerAddress -split ":")[0]
    $apiServerPort = ($apiServerAddress -split ":")[1]

    do {
        $result = Test-NetConnection -ComputerName $apiServerFqdn -Port $apiServerPort -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Host "[$(Get-Date -Format t)] INFO: Kubernetes API server $apiServer is available" -ForegroundColor Gray
            break
        }
        else {
            Write-Host "[$(Get-Date -Format t)] INFO: Kubernetes API server $apiServer is not yet available. Retrying in 10 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    } while ($true)

    # Install Prometheus Operator
    $helmSetValue = $_.Value.HelmSetValue -replace 'adminPasswordPlaceholder', $adminPassword
    helm install prometheus prometheus-community/kube-prometheus-stack --set $helmSetValue --namespace $observabilityNamespace --create-namespace --values "$AgMonitoringDir\$($_.Value.HelmValuesFile)" | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    Do {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for $($_.Value.FriendlyName) monitoring service to provision.." -ForegroundColor Gray
        Start-Sleep -Seconds 45
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
        Invoke-RestMethod -Method Post -Uri $grafanaDS -Headers $adminHeaders -Body $grafanaDSBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
    }

    # Add Contoso Operator User
    if (!$_.Value.IsProduction) {
        Write-Host "[$(Get-Date -Format t)] INFO: Creating $($_.Value.FriendlyName) Grafana User" -ForegroundColor Gray
        $grafanaUserBody = @{
            name     = $AgConfig.Monitoring["User"] # Display Name
            email    = $AgConfig.Monitoring["Email"]
            login    = $adminUsername
            password = $adminPassword
        } | ConvertTo-Json

        # Make HTTP request to the API to create user
        $retryCount = 10
        $retryDelay = 30

        do {
            try {
                Invoke-RestMethod -Method Post -Uri "http://$monitorLBIP/api/admin/users" -Headers $adminHeaders -Body $grafanaUserBody | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")
                $retryCount = 0
            }
            catch {
                $retryCount--
                if ($retryCount -gt 0) {
                    Write-Host "[$(Get-Date -Format t)] INFO: Retrying in $retryDelay seconds..." -ForegroundColor Gray
                    Start-Sleep -Seconds $retryDelay
                }
            }
        } while ($retryCount -gt 0)
    }

    Write-Host "[$(Get-Date -Format t)] INFO: Importing dashboards for $($_.Value.FriendlyName) environment" -ForegroundColor Gray
    # Add dashboards
    foreach ($dashboard in $observabilityDashboardstoImport) {
        $grafanaDBPath = "$AgMonitoringDir\grafana-$dashboard.json"
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
            $grafanaDBStarURI = $AgConfig.Monitoring["ProdURL"] + "/api/user/stars/dashboard"
        }
        else {
            # Set Grafana Dashboard endpoint
            $grafanaDBURI = "http://$monitorLBIP/api/dashboards/db"
            $grafanaDBStarURI = "http://$monitorLBIP/api/user/stars/dashboard"
        }

        # Make HTTP request to the API
        $dashboardID=(Invoke-RestMethod -Method Post -Uri $grafanaDBURI -Headers $adminHeaders -Body $grafanaDBBody).id

        Invoke-RestMethod -Method Post -Uri "$grafanaDBStarURI/$dashboardID" -Headers $userHeaders | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Observability.log")

    }

}
Write-Host

##############################################################
# Creating bookmarks
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Edge Bookmarks in Favorites Bar (Step 15/17)" -ForegroundColor DarkGreen
$bookmarksFileName = "$AgToolsDir\Bookmarks"
$edgeBookmarksPath = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")
    $services = kubectl get services --all-namespaces -o json | ConvertFrom-Json

    # Matching url: pos - customer
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 5000 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $posIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($posIp in $posIps) {
        $output = "http://$posIp" + ':5000'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("POS-" + $cluster.Name + "-URL-Customer"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }

    # Matching url: pos - manager
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 81 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $posIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($posIp in $posIps) {
        $output = "http://$posIp" + ':81'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("POS-" + $cluster.Name + "-URL-Manager"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }

    # Matching url: prometheus-grafana
    if ($cluster.Name -eq "Staging" -or $cluster.Name -eq "Dev") {
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'prometheus-grafana'
        }
        $grafanaIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($grafanaIp in $grafanaIps) {
            $output = "http://$grafanaIp"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Grafana-" + $cluster.Name + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName

            Start-Sleep -Seconds 2
        }
    }

    # Matching url: prometheus
    $matchingServices = $services.items | Where-Object {
        $_.spec.ports.port -contains 9090 -and
        $_.spec.type -eq "LoadBalancer"
    }
    $prometheusIps = $matchingServices.status.loadBalancer.ingress.ip

    foreach ($prometheusIp in $prometheusIps) {
        $output = "http://$prometheusIp" + ':9090'
        $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        # Replace matching value in the Bookmarks file
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("Prometheus-" + $cluster.Name + "-URL"), $output
        $newContent | Set-Content -Path $bookmarksFileName

        Start-Sleep -Seconds 2
    }
}

# Matching url: Agora apps forked repo
$output = $appClonedRepo
$output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

# Replace matching value in the Bookmarks file
$content = Get-Content -Path $bookmarksFileName
$newContent = $content -replace "Agora-Apps-Repo-Clone-URL", $output
$newContent = $newContent -replace "Agora-Apps-Repo-Your-Fork", "Agora Apps Repo - $githubUser"
$newContent | Set-Content -Path $bookmarksFileName

Start-Sleep -Seconds 2

Copy-Item -Path $bookmarksFileName -Destination $edgeBookmarksPath -Force

##############################################################
# Pinning important directories to Quick access
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Pinning important directories to Quick access (Step 16/17)" -ForegroundColor DarkGreen
$quickAccess = new-object -com shell.application
$quickAccess.Namespace($AgConfig.AgDirectories.AgDir).Self.InvokeVerb("pintohome")
$quickAccess.Namespace($AgConfig.AgDirectories.AgLogsDir).Self.InvokeVerb("pintohome")


##############################################################
# Cleanup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up scripts and uploading logs (Step 17/17)" -ForegroundColor DarkGreen
# Creating Hyper-V Manager desktop shortcut
Write-Host "[$(Get-Date -Format t)] INFO: Creating Hyper-V desktop shortcut." -ForegroundColor Gray
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force


Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache job" -ForegroundColor Gray
while ($(Get-Job -Name images-cache-cleanup).State -eq 'Running') {
  Write-Host "[$(Get-Date -Format t)] INFO: Waiting for images-cache job to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
  Receive-Job -Name images-cache-cleanup -WarningAction SilentlyContinue
  Start-Sleep -Seconds 60
}
Get-Job -name images-cache-cleanup | Remove-Job

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

Write-Host "[$(Get-Date -Format t)] INFO: Tools setup background job:" -ForegroundColor Green

$step14job
$step14job | Receive-Job -Wait

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes. Please enjoy the Agora experience!" -ForegroundColor Green
Write-Host

Stop-Transcript
