# Script runtime environment: Level-1 Nested Hyper-V virtual machine

##############################################################
# Preparing environment folders structure #
##############################################################
$ProgressPreference = "SilentlyContinue"

# Folders to be created
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

##############################################################
# Testing internet connectivity
##############################################################
$githubAPIUrl = 'https://api.github.com'
$azurePortalUrl = 'https://portal.azure.com'
$aksEEk3sUrl = 'https://aka.ms/aks-edge/k3s-msi'

$websiteUrls = @(
    $githubAPIUrl,
    $azurePortalUrl,
    $aksEEk3sUrl
)

$maxRetries = 3
$retryDelaySeconds = 5
$retryCount = 0

foreach ($url in $websiteUrls) {
    do {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
            $statusCode = $response.StatusCode

            if ($statusCode -eq 200) {
                Write-Host "$url is reachable."
                break  # Break out of the loop if website is reachable
            }
            else {
                Write-Host "$_ is unreachable. Status code: $statusCode"
            }
        }
        catch {
            Write-Host "An error occurred while testing the website: $_"
        }

        $retryCount++
        if ($retryCount -le $maxRetries) {
            Write-Host "Retrying in $retryDelaySeconds seconds..."
            Start-Sleep -Seconds $retryDelaySeconds
        }
    } while ($retryCount -le $maxRetries)

    if ($retryCount -gt $maxRetries) {
        Write-Host "Exceeded maximum number of retries. Exiting..."
        exit 1  # Stop script execution if maximum retries reached
    }
}

##############################################################
# Deplying AKS Edge Essentials clusters 
##############################################################
Write-Host "INFO: Configuring L1 VM with AKS Edge Essentials." -ForegroundColor Gray
# Force time sync
$string = Get-Date
Write-Host "INFO: Time before forced time sync:" $string.ToString("u") -ForegroundColor Gray
net start w32time
W32tm /resync
$string = Get-Date
Write-Host "INFO: Time after forced time sync:" $string.ToString("u") -ForegroundColor Gray

########################################################################################
# Creating Hyper-V External Virtual Switch for AKS Edge Essentials cluster deployment
########################################################################################
Start-Sleep 5
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Repository PSGallery -AllowClobber -Name HNS -Force
Write-Host "INFO: Creating Hyper-V External Virtual Switch for AKS Edge Essentials cluster" -ForegroundColor Gray
$switchName = "aksedgesw-ext"
$netConfig = Get-Content -Raw $deploymentFolder"\Config.Json" | ConvertFrom-Json
$gatewayIp = $netConfig.Network.Ip4GatewayAddress
$ipAddressPrefix = "172.20.1.0/24"
$AdapterName = (Get-NetAdapter -Name Ethernet*).Name
$jsonString = @"
{
    "Policies": [
        {
            "Settings":
                {
                    "NetworkAdapterName": "$AdapterName"
                },
            "Type": "NetAdapterName"
        }
    ],
    "SchemaVersion": { "Major": 2, "Minor": 2 },
    "Name":  "$switchName",
    "Type":  "Transparent",
    "Ipams":  [
        {
            "Subnets":  [
                {
                    "Policies":  [],
                    "Routes":  [
                        {
                            "NextHop":  "$gatewayIp",
                            "DestinationPrefix":  "0.0.0.0/0"
                        }
                    ],
                    "IpAddressPrefix":  "$ipAddressPrefix"
                }
            ],
            "Type":  "Static"
        }
    ]
}
"@
New-HnsNetwork -jsonString $jsonString

##################################################################
# Installing AKS Edge Essentials binaries and PowerShell module
##################################################################
$msiFileName = (Get-ChildItem -Path $deploymentFolder | Where-Object { $_.Extension -eq ".msi" }).Name
$msiFilePath = Join-Path $deploymentFolder $msiFileName
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($msiFilePath)
$msiInstallLog = "$deploymentFolder\$fileNameWithoutExt.log"
Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log `"$msiInstallLog`"" -Wait
Import-Module AksEdge.psm1 -Force
Install-AksEdgeHostFeatures -Force

# Deploying AKS Edge Essentials cluster
Set-Location $deploymentFolder
New-AksEdgeDeployment -JsonConfigFilePath ".\Config.json"
Write-Host

# kubeconfig work for changing context and coping to the Hyper-V host machine
$newKubeContext = $(hostname).ToLower()
kubectx ${newKubeContext}=default
Write-Host
kubectl get nodes -o wide
Write-Host

$sourcePath = "$env:USERPROFILE\.kube\config"
$destinationPath = "$env:USERPROFILE\.kube\config-$newKubeContext"

$kubeReplacementParams = @{
    "name: default"    = "name: $newKubeContext"
    "cluster: default" = "cluster: $newKubeContext"
    "user: default"    = "user: $newKubeContext"
}

$content = Get-Content $sourcePath
foreach ($key in $kubeReplacementParams.Keys) {
    $content = $content -replace $key, $kubeReplacementParams[$key]
}
Set-Content $destinationPath -Value $content

################################################################
# Configuring required firewall rules for AKS Edge Essentials
################################################################
Write-Host "INFO: Enabling ICMP for the cluster control plane IP address" -ForegroundColor Gray
Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p ICMP -j ACCEPT"

Write-Host "INFO: Enabling Prometheus metrics port for the cluster control plane IP address" -ForegroundColor Gray
Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT"

# Creating a file on the L1 virtual machine with the AKS Edge Essentials L2 virtual machine id
Write-Host "INFO: Getting the AKS Edge Essentials virtual machine (L2) id" -ForegroundColor Gray
$id = hcsdiag list | Select-Object -First 1
$firstLine = "The AKS Edge Essentials virtual machine id is: $id"
$secondLine = "To access it, use the 'hcsdiag console $id' command using the Windows Terminal."
$firstLine, $secondLine | Out-File "$logsFolder\aksee-id.txt"

#############################################################################
# Unregistering the scheduled task responsible for start script automation
#############################################################################
Unregister-ScheduledTask -TaskName "Startup Scan" -Confirm:$false
