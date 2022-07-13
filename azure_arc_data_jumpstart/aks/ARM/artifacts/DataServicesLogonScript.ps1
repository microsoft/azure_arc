Start-Transcript -Path "$Env:tempDir\DataServicesLogonScript.log"

## Function respository
function SetEnviromentVariables() {
    # Deployment environment variables
    $Env:connectedClusterName = "Arc-DataSvc-AKS"
}
function GettingAKSClusterCredentialsKubeconfigFile([string]$resourceGroup, [string]$clusterName) {
    Write-Output "Getting AKS cluster credentials"
    Write-Output "`n"
    az aks get-credentials --resource-group $resourceGroup --name $clusterName --admin

    Write-Output "Checking kubernetes nodes"
    Write-Output "`n"
    kubectl get nodes
    Write-Output "`n"
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
function DeployingAzureArcDataController {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUsernameAndPasswordParams", "")]
    param (
        [string]$resourceGroup,
        [string]$directory,
        [string]$workspaceName,
        [string]$AZDATA_USERNAME,
        [string]$AZDATA_PASSWORD,
        [string]$spnClientId,
        [string]$spnTenantId,
        [string]$spnClientSecret,
        [string]$subscriptionId
    )
    $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $resourceGroup --query id -o tsv)
    $workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName --query primarySharedKey -o tsv)

    $dataControllerParams = "$directory\dataController.parameters.json"

    (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $resourceGroup | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $AZDATA_USERNAME | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $subscriptionId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $spnClientId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $spnTenantId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $spnClientSecret | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

    az deployment group create --resource-group $resourceGroup `
        --template-file "$directory\dataController.json" `
        --parameters "$directory\dataController.parameters.json"

    Write-Output "`n"
    Do {
        Write-Output "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")

    Write-Output "`n"
    Write-Output "Azure Arc data controller is ready!"
    Write-Output "`n"
}
function EnablingDataControllerAutoMetrics {
    param (
        [string]$resourceGroup,
        [string]$workspaceName
    )
    Write-Output "`n"
    Write-Output "Enabling data controller auto metrics & logs upload to log analytics"
    Write-Output "`n"
    $Env:WORKSPACE_ID = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName  --query primarySharedKey -o tsv)
    az arcdata dc update --name jumpstart-dc --resource-group $resourceGroup --auto-upload-logs true
    az arcdata dc update --name jumpstart-dc --resource-group $resourceGroup --auto-upload-metrics true
}
function CopyingAzureDataStudioSettingsRemplateFile {
    param (
        [string]$adminUsername,
        [string]$directory
    )
    Write-Output "`n"
    Write-Output "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "$directory\settingsTemplate.json" -Destination "C:\Users\$adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
}
function Add-URL-Shortcut-Desktop {
    param (
        [string]$url,
        [string]$name,
        [string]$USERPROFILE
    )
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($USERPROFILE + "\Desktop\$name.url")
    $Favorite.TargetPath = $url;
    $Favorite.Save()
}
function ChangingToClientVMWallpaper {
    param (
        [string]$directory
    )

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $connectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $Env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services' `
                        --kube-config $Env:KUBECONFIG `
                        --kube-context $Env:KUBECONTEXT `
                        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

     public class Wallpaper{
        [DllImport("user32.dll", CharSet=CharSet.Auto)]
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ;

         public static void SetWallpaper(string thePath){
            SystemParametersInfo(20,0,thePath,3);
         }
    }
 }
'@

    add-type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}
## Main Script
SetEnviromentVariables

. "$Env:tempDir/CommonDataServicesLogonScript.ps1"

SetDefaultSubscription -subscriptionId $Env:subscriptionId

InstallingAzureDataStudioExtensions @("microsoft.azcli", "microsoft.azuredatastudio-postgresql", "Microsoft.arc")

Add-Desktop-Shortcut -shortcutName "Azure Data Studio" -targetPath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -username $Env:adminUsername

RegisteringAzureArcProviders @("Kubernetes", "KubernetesConfiguration", "ExtendedLocation", "AzureArcData")

GettingAKSClusterCredentialsKubeconfigFile $Env:resourceGroup $Env:clusterName

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