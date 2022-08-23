Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

# Function repository
function OnboardingCluster {
    param (
        [string]$resourceGroup,
        [string]$clusterName,
        [string]$azureLocation,
        [string]$workspaceName
    )
    az connectedk8s connect --name $clusterName `
        --resource-group $resourceGroup `
        --location $azureLocation `
        --tags 'Project=jumpstart_azure_arc_data_services' `
        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
    Start-Sleep -Seconds 10
    $workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    az k8s-extension create --name "azuremonitor-containers" --cluster-name $clusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
}

# Deployment environment variables
$primaryConnectedClusterName = "Arc-DataSvc-AKS-Primary"
$secondaryConnectedClusterName = "Arc-DataSvc-AKS-Secondary"
$clusterName = $Env:clusterName
$primaryClusterName = $clusterName + "-Primary"
$secondaryClusterName = $clusterName + "-Secondary"
$primaryDcName = "jumpstart-primary-dc"
$secondaryDcName = "jumpstart-secondary-dc"

. $Env:tempDir/ArcDataCommonDataServicesLogonScript.ps1 -extraAzExtensions @("customlocation")

SetDefaultSubscription $Env:subscriptionId

InstallingAzureDataStudioExtensions @("microsoft.azcli", "microsoft.azuredatastudio-postgresql", "Microsoft.arc")

Add-Desktop-Shortcut -shortcutName "Azure Data Studio" -targetPath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -username $Env:adminUsername

RegisteringAzureArcProviders @("Kubernetes", "KubernetesConfiguration", "ExtendedLocation", "AzureArcData")

# Getting AKS cluster credentials kubeconfig file
GettingAKSClusterCredentialsKubeconfigFile -resourceGroup $Env:resourceGroup -clusterName $primaryClusterName
GettingAKSClusterCredentialsKubeconfigFile -resourceGroup $Env:resourceGroup -clusterName $secondaryClusterName

# Creating Kubect aliases
kubectx primary="$primaryConnectedClusterName-admin"
kubectx secondary="$secondaryConnectedClusterName-admin"
Write-Output "`n"

# Localize kubeconfig
$Env:KUBECONFIG = "C:\Users\$Env:adminUsername\.kube\config"
Write-Output "`n"

# Create Kubernetes - Azure Arc Cluster for the primary cluster
Write-Output "Onboarding the primary cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Output "`n"
kubectx primary
Write-Output "`n"
OnboardingCluster -resourceGroup $Env:resourceGroup -clusterName $primaryConnectedClusterName -azureLocation $Env:azureLocation -workspaceName $Env:workspaceName

# Monitor pods across arc namespace
$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } }

# Installing Azure Arc-enabled data services extension
Write-Output "`n"
Write-Output "Installing Azure Arc-enabled data services extension"
az k8s-extension create --name arc-data-services `
    --extension-type microsoft.arcdataservices `
    --cluster-type connectedClusters `
    --cluster-name $primaryConnectedClusterName `
    --resource-group $Env:resourceGroup `
    --auto-upgrade false `
    --scope cluster `
    --release-namespace arc `
    --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

Write-Output "`n"
Do {
    Write-Output "Waiting for bootstrapper pod, hold tight...(20s sleeping loop)"
    Start-Sleep -Seconds 20
    $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
} while ($podStatus -eq "Nope")

$primaryConnectedClusterId = az connectedk8s show --name $primaryConnectedClusterName --resource-group $Env:resourceGroup --query id -o tsv

$primaryExtensionId = az k8s-extension show --name arc-data-services `
    --cluster-type connectedClusters `
    --cluster-name $primaryConnectedClusterName `
    --resource-group $Env:resourceGroup `
    --query id -o tsv

Start-Sleep -Seconds 20

# Create Custom Location
az customlocation create --name 'jumpstart-primary-cl' `
    --resource-group $Env:resourceGroup `
    --namespace arc `
    --host-resource-id $primaryConnectedClusterId `
    --cluster-extension-ids $primaryExtensionId `
    --kubeconfig $Env:KUBECONFIG

# Deploying Azure Arc Data Controller
Write-Output "`n"
Write-Output "Deploying Azure Arc Data Controller"
Write-Output "`n"

$primaryCustomLocationId = $(az customlocation show --name "jumpstart-primary-cl" --resource-group $Env:resourceGroup --query id -o tsv)
$laWorkspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$laWorkspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "$Env:TempDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'jumpstartdc-stage', $primaryDcName | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $Env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $primaryCustomLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $Env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $Env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $Env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $laWorkspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $laWorkspaceKey | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $Env:resourceGroup `
    --template-file "$Env:TempDir\dataController.json" `
    --parameters "$Env:TempDir\dataController.parameters.json"

Write-Output "`n"
Do {
    Write-Output "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
} while ($dcStatus -eq "Nope")

Write-Output "`n"
Write-Output "Azure Arc data controller is ready!"
Write-Output "`n"

# Create Kubernetes - Azure Arc Cluster for the secondary cluster
Write-Output "`n"
kubectx secondary
Write-Output "`n"
OnboardingCluster -resourceGroup $Env:resourceGroup -clusterName $secondaryConnectedClusterName -azureLocation $Env:azureLocation -workspaceName $Env:clusterName

# Installing Azure Arc-enabled data services extension
Write-Output "`n"
Write-Output "Installing Azure Arc-enabled data services extension"
az k8s-extension create --name arc-data-services `
    --extension-type microsoft.arcdataservices `
    --cluster-type connectedClusters `
    --cluster-name $secondaryConnectedClusterName `
    --resource-group $Env:resourceGroup `
    --auto-upgrade false `
    --scope cluster `
    --release-namespace arc `
    --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

$secondaryConnectedClusterId = az connectedk8s show --name $secondaryConnectedClusterName --resource-group $Env:resourceGroup --query id -o tsv

$secondaryExtensionId = az k8s-extension show --name arc-data-services `
    --cluster-type connectedClusters `
    --cluster-name $secondaryConnectedClusterName `
    --resource-group $Env:resourceGroup `
    --query id -o tsv

Start-Sleep -Seconds 20

# Create Custom Location
az customlocation create --name 'jumpstart-secondary-cl' `
    --resource-group $Env:resourceGroup `
    --namespace arc `
    --host-resource-id $secondaryConnectedClusterId `
    --cluster-extension-ids $secondaryExtensionId `
    --kubeconfig $Env:KUBECONFIG

# Deploying Azure Arc Data Controller
Write-Output "`n"
Write-Output "Deploying Azure Arc Data Controller"
Write-Output "`n"

$secondaryCustomLocationId = $(az customlocation show --name "jumpstart-secondary-cl" --resource-group $Env:resourceGroup --query id -o tsv)

$dataControllerParams = "$Env:TempDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace $primaryCustomLocationId, $secondaryCustomLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace $primaryDcName, $secondaryDcName | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $Env:resourceGroup `
    --template-file "$Env:TempDir\dataController.json" `
    --parameters "$Env:TempDir\dataController.parameters.json"

Write-Output "`n"
Do {
    Write-Output "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
} while ($dcStatus -eq "Nope")

Write-Output "`n"
Write-Output "Azure Arc data controller is ready!"
Write-Output "`n"


# If flag set, deploy SQL MI
if ( $Env:deploySQLMI -eq $true ) {
    & "$Env:TempDir\DeploySQLMI.ps1"
}

# Enabling data controller auto metrics & logs upload to log analytics on the primary cluster
kubectx primary
Write-Output "`n"
Write-Output "Enabling data controller auto metrics & logs upload to log analytics on the primary cluster"
Write-Output "`n"
$Env:WORKSPACE_ID = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name $primaryDcName --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name $primaryDcName --resource-group $Env:resourceGroup --auto-upload-metrics true

# Enabling data controller auto metrics & logs upload to log analytics on the secondary cluster
kubectx secondary
Write-Output "`n"
Write-Output "Enabling data controller auto metrics & logs upload to log analytics on the secondary cluster"
Write-Output "`n"
$Env:WORKSPACE_ID = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name $secondaryDcName --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name $secondaryDcName --resource-group $Env:resourceGroup --auto-upload-metrics true

# Applying Azure Data Studio settings template file and operations url shortcut
if ( $Env:deploySQLMI -eq $true) {
    Write-Output "`n"
    Write-Output "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "$Env:TempDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

    # Creating desktop url shortcuts for built-in Grafana and Kibana services 
    $GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $GrafanaURL = "https://" + $GrafanaURL + ":3000"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Grafana.url")
    $Favorite.TargetPath = $GrafanaURL;
    $Favorite.Save()

    $KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $KibanaURL = "https://" + $KibanaURL + ":5601"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Kibana.url")
    $Favorite.TargetPath = $KibanaURL;
    $Favorite.Save()
}

Write-Output "`n"
Write-Output "Switching to primary"
kubectx primary
Write-Output "`n"

# Changing to Client VM wallpaper
$imgPath = "$Env:TempDir\wallpaper.png"
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

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

Stop-Process -Name powershell -Force

Stop-Transcript