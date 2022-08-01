Start-Transcript -Path "$Env:tempDir\DataServicesLogonScript.log"

## Function respository
function DownloadingCapiFiles {
    param (
        [string]$stagingStorageAccountName,
        [string]$resourceGroup,
        [string]$username,
        [string]$folder
    )
    # Downloading CAPI Kubernetes cluster kubeconfig file
    Write-Output "Downloading CAPI Kubernetes cluster kubeconfig file"
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
    $context = (Get-AzStorageAccount -ResourceGroupName $resourceGroup).Context
    $sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
    $sourceFile = $sourceFile + $sas
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$username\.kube\config"

    # Downloading 'installCAPI.log' log file
    Write-Output "Downloading 'installCAPI.log' log file"
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/staging-capi/installCAPI.log"
    $sourceFile = $sourceFile + $sas
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$folder\installCAPI.log"

    Write-Output "`n"
    Write-Output "Checking kubernetes nodes"
    Write-Output "`n"
    kubectl get nodes
    Write-Output "`n"
}
function LocalizeKubeAndConfigMonitorPods {
    param (
        [string]$adminUsername
    )
    # Localize kubeconfig
    $Env:KUBECONTEXT = kubectl config current-context
    $Env:KUBECONFIG = "C:\Users\$adminUsername\.kube\config"

    Start-Sleep -Seconds 10

    return (Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } })
}

## Main Script
. "$Env:tempDir/ArcDataCommonDataServicesLogonScript.ps1"

SetDefaultSubscription -subscriptionId $Env:subscriptionId

InstallingAzureDataStudioExtensions @("microsoft.azcli", "microsoft.azuredatastudio-postgresql", "Microsoft.arc")

Add-Desktop-Shortcut -shortcutName "Azure Data Studio" -targetPath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -username $Env:adminUsername

RegisteringAzureArcProviders @("Kubernetes", "KubernetesConfiguration", "ExtendedLocation", "AzureArcData")

DownloadingCapiFiles -stagingStorageAccountName "$Env:stagingStorageAccountName" -resourceGroup "$Env:resourceGroup" -username "$Env:USERNAME" -folder "$Env:TempDir"

$kubectlMonShell = (LocalizeKubeAndConfigMonitorPods -adminUsername $Env:adminUsername)

Write-Output "`n"
Write-Output "Installing Azure Arc-enabled data services extension"
$InstallingAzureArcEnabledDataServicesExtensionResult = InstallingAzureArcEnabledDataServicesExtension $Env:ArcK8sClusterName $Env:resourceGroup
$extensionId = $InstallingAzureArcEnabledDataServicesExtensionResult[$InstallingAzureArcEnabledDataServicesExtensionResult.length - 1]
$connectedClusterId = $InstallingAzureArcEnabledDataServicesExtensionResult[$InstallingAzureArcEnabledDataServicesExtensionResult.length - 2]

CreateCustomLocation -resourceGroup $Env:resourceGroup -connectedClusterId $connectedClusterId -extensionId $extensionId -KUBECONFIG $Env:KUBECONFIG

# Deploying Azure Arc Data Controller
Write-Output "`n"
Write-Output "Deploying Azure Arc Data Controller"
DeployingAzureArcDataController -resourceGroup $Env:resourceGroup -directory $Env:TempDir -workspaceName $Env:workspaceName -AZDATA_USERNAME $Env:AZDATA_USERNAME -AZDATA_PASSWORD $Env:AZDATA_PASSWORD -spnClientId $Env:spnClientId -spnTenantId $Env:spnTenantId -spnClientSecret $Env:spnClientSecret -subscriptionId $Env:subscriptionId

# If flag set, deploy SQL MI
if ( $Env:deploySQLMI -eq $true ) {
    & "$Env:TempDir\DeploySQLMI.ps1"
}

# If flag set, deploy PostgreSQL
if ( $Env:deployPostgreSQL -eq $true ) {
    & "$Env:TempDir\DeployPostgreSQL.ps1"
}

EnablingDataControllerAutoMetrics -resourceGroup $Env:resourceGroup -workspaceName $Env:workspaceName

# Applying Azure Data Studio settings template file and operations url shortcut
if ( $Env:deploySQLMI -eq $true -or $Env:deployPostgreSQL -eq $true ) {
    CopyingAzureDataStudioSettingsRemplateFile -adminUsername $Env:adminUsername -directory $Env:TempDir
    
    # Creating desktop url shortcuts for built-in Grafana and Kibana services 
    $GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $GrafanaURL = "https://" + $GrafanaURL + ":3000"
    Add-URL-Shortcut-Desktop -url $GrafanaURL -name "Grafana" -USERPROFILE $Env:USERPROFILE

    $KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $KibanaURL = "https://" + $KibanaURL + ":5601"
    Add-URL-Shortcut-Desktop -url $KibanaURL -name "Kibana" -USERPROFILE $Env:USERPROFILE
}

# Changing to Client VM wallpaper
ChangingToClientVMWallpaper -directory $Env:TempDir

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

Stop-Process -Name powershell -Force

Stop-Transcript