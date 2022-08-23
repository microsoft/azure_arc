Start-Transcript -Path "$Env:tempDir\DataServicesLogonScript.log"

## Function respository
function SetEnviromentVariables() {
    # Deployment environment variables
    $Env:connectedClusterName = "Arc-DataSvc-AKS"
}
function AKSClusterAsAnAzureArcEnabledKubernetesCluster {
    param (
        [string]$adminUsername,
        [string]$connectedClusterName,
        [string]$resourceGroup,
        [string]$azureLocation,
        [string]$workspaceName
    )
    # Localize kubeconfig
    $Env:KUBECONTEXT = kubectl config current-context
    $Env:KUBECONFIG = "C:\Users\$adminUsername\.kube\config"
    Start-Sleep -Seconds 10

    # Create Kubernetes - Azure Arc Cluster
    az connectedk8s connect --name $connectedClusterName `
        --resource-group $resourceGroup `
        --location $azureLocation `
        --tags 'Project=jumpstart_azure_arc_data_services' `
        --kube-config $Env:KUBECONFIG `
        --kube-context $Env:KUBECONTEXT

    Start-Sleep -Seconds 10

    # Enabling Container Insights cluster extension
    $workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    az k8s-extension create --name "azuremonitor-containers" --cluster-name $connectedClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId

    # Monitor pods across arc namespace
    return (Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } })
}

## Main Script
SetEnviromentVariables

. "$Env:tempDir/ArcDataCommonDataServicesLogonScript.ps1"

SetDefaultSubscription -subscriptionId $Env:subscriptionId

InstallingAzureDataStudioExtensions @("microsoft.azcli", "microsoft.azuredatastudio-postgresql", "Microsoft.arc")

Add-Desktop-Shortcut -shortcutName "Azure Data Studio" -targetPath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -username $Env:adminUsername

RegisteringAzureArcProviders @("Kubernetes", "KubernetesConfiguration", "ExtendedLocation", "AzureArcData")

GettingAKSClusterCredentialsKubeconfigFile -resourceGroup $Env:resourceGroup -clusterName $Env:clusterName

# Onboarding the AKS cluster as an Azure Arc-enabled Kubernetes cluster
Write-Output "Onboarding the cluster as an Azure Arc-enabled Kubernetes cluster"
$kubectlMonShell = (AKSClusterAsAnAzureArcEnabledKubernetesCluster -adminUsername $Env:adminUsername -connectedClusterName $Env:connectedClusterName -resourceGroup $Env:resourceGroup -azureLocation $Env:azureLocation -workspaceName $Env:workspaceName)

Write-Output "`n"
Write-Output "Installing Azure Arc-enabled data services extension"
$InstallingAzureArcEnabledDataServicesExtensionResult = InstallingAzureArcEnabledDataServicesExtension $Env:connectedClusterName $Env:resourceGroup
$extensionId = $InstallingAzureArcEnabledDataServicesExtensionResult[$InstallingAzureArcEnabledDataServicesExtensionResult.length - 1]
$connectedClusterId = $InstallingAzureArcEnabledDataServicesExtensionResult[$InstallingAzureArcEnabledDataServicesExtensionResult.length - 2]

CreateCustomLocation -resourceGroup $Env:resourceGroup -connectedClusterId $connectedClusterId -extensionId $extensionId -KUBECONFIG $Env:KUBECONFIG

# Deploying Azure Arc Data Controller
Write-Output "`n"
Write-Output "Deploying Azure Arc Data Controller"
DeployingAzureArcDataController -resourceGroup $Env:resourceGroup -directory $Env:TempDir -workspaceName $Env:workspaceName -AZDATA_USERNAME $Env:AZDATA_USERNAME -AZDATA_PASSWORD $Env:AZDATA_PASSWORD -spnClientId $Env:spnClientId -spnTenantId $Env:spnTenantId -spnClientSecret $Env:spnClientSecret -subscriptionId $Env:subscriptionId

# If flag set, deploy SQL MI
if ( $Env:deploySQLMI -eq $true -and $Env:enableADAuth -eq $false) {
    & "$Env:TempDir\DeploySQLMI.ps1"
}

# if ADDS domainname is passed as parameter, deploy SQLMI with AD auth support
if ($Env:deploySQLMI -eq $true -and $Env:enableADAuth -eq $true) {
    & "$Env:TempDir\DeploySQLMIADAuth.ps1"
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