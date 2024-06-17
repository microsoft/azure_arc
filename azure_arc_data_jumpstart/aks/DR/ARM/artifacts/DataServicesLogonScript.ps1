Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

# Deployment environment variables
$Env:TempDir = "C:\Temp"
$primaryConnectedClusterName = "Arc-DataSvc-AKS-Primary"
$secondaryConnectedClusterName = "Arc-DataSvc-AKS-Secondary"
$clusterName = $Env:clusterName
$primaryClusterName = $clusterName+"-Primary"
$secondaryClusterName = $clusterName+"-Secondary"
$primaryDcName = "jumpstart-primary-dc"
$secondaryDcName= "jumpstart-secondary-dc"

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Login as service principal
az login --service-principal --username $Env:spnClientId --password=$Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
Write-Host "`n"
Write-Host "Installing Azure CLI extensions"
az extension add --name arcdata
az extension add --name connectedk8s --version 1.3.17
az extension add --name k8s-extension
az extension add --name customlocation
Write-Host "`n"
az -v

# Set default subscription to run commands against
# "subscriptionId" value comes from clientVM.json ARM template, based on which 
# subscription user deployed ARM template to. This is needed in case Service 
# Principal has access to multiple subscriptions, which can break the automation logic
az account set --subscription $Env:subscriptionId

# Installing Azure Data Studio extensions
Write-Host "`n"
Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"
$Env:argument1="--install-extension"
$Env:argument2="microsoft.azcli"
$Env:argument3="microsoft.azuredatastudio-postgresql"
$Env:argument4="Microsoft.arc"
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument3
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument4

# Creating Azure Data Studio desktop shortcut
Write-Host "`n"
Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Registering Azure Arc providers
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait

az provider show --namespace Microsoft.Kubernetes -o table
Write-Host "`n"
az provider show --namespace Microsoft.KubernetesConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.ExtendedLocation -o table
Write-Host "`n"
az provider show --namespace Microsoft.AzureArcData -o table
Write-Host "`n"

# Getting AKS cluster credentials kubeconfig file
Write-Host "Getting AKS cluster credentials for the primary cluster"
Write-Host "`n"
az aks get-credentials --resource-group $Env:resourceGroup `
                       --name $primaryClusterName --admin
Write-Host "`n"
Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

                       Write-Host "Getting AKS cluster credentials for the secondary cluster"
Write-Host "`n"
az aks get-credentials --resource-group $Env:resourceGroup `
                       --name $secondaryClusterName --admin
Write-Host "`n"
Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Creating Kubect aliases
kubectx primary="$primaryConnectedClusterName-admin"
kubectx secondary="$secondaryConnectedClusterName-admin"
Write-Host "`n"

# Localize kubeconfig
$Env:KUBECONFIG = "C:\Users\$Env:adminUsername\.kube\config"
Write-Host "`n"

# Create Kubernetes - Azure Arc Cluster for the primary cluster
Write-Host "Onboarding the primary cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Host "`n"
kubectx primary
Write-Host "`n"
az connectedk8s connect --name $primaryConnectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $Env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services' `
                        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

Start-Sleep -Seconds 10

# Enabling Container Insights cluster extension on primary cluster
Write-Host "`n"
Write-Host "Enabling Container Insights cluster extension"
az k8s-extension create --name "azuremonitor-containers" --cluster-name $primaryConnectedClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
Write-Host "`n"

# Monitor pods across arc namespace
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host }}

# Installing Azure Arc-enabled data services extension
Write-Host "`n"
Write-Host "Installing Azure Arc-enabled data services extension"
az k8s-extension create --name arc-data-services `
                        --extension-type microsoft.arcdataservices `
                        --cluster-type connectedClusters `
                        --cluster-name $primaryConnectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --auto-upgrade false `
                        --scope cluster `
                        --version 1.30.0 `
                        --release-namespace arc `
                        --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

Write-Host "`n"
Do {
    Write-Host "Waiting for bootstrapper pod, hold tight...(20s sleeping loop)"
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
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
Write-Host "`n"
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$primaryCustomLocationId = $(az customlocation show --name "jumpstart-primary-cl" --resource-group $Env:resourceGroup --query id -o tsv)
$laWorkspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$laWorkspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "$Env:TempDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage',$Env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'jumpstartdc-stage',$primaryDcName | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage',$Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage',$Env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage',$primaryCustomLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage',$Env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage',$Env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage',$Env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage',$Env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage',$laWorkspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage',$laWorkspaceKey | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $Env:resourceGroup `
                           --template-file "$Env:TempDir\dataController.json" `
                           --parameters "$Env:TempDir\dataController.parameters.json"

Write-Host "`n"
Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")

Write-Host "`n"
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

# Create Kubernetes - Azure Arc Cluster for the secondary cluster
Write-Host "`n"
kubectx secondary
Write-Host "`n"
az connectedk8s connect --name $secondaryConnectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $Env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services'

Start-Sleep -Seconds 10

# Enabling Container Insights cluster extension on secondary cluster
Write-Host "`n"
Write-Host "Enabling Container Insights cluster extension"
az k8s-extension create --name "azuremonitor-containers" --cluster-name $secondaryConnectedClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
Write-Host "`n"

# Installing Azure Arc-enabled data services extension
Write-Host "`n"
Write-Host "Installing Azure Arc-enabled data services extension"
az k8s-extension create --name arc-data-services `
                        --extension-type microsoft.arcdataservices `
                        --cluster-type connectedClusters `
                        --cluster-name $secondaryConnectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --auto-upgrade false `
                        --scope cluster `
                        --version 1.30.0 `
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
Write-Host "`n"
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$secondaryCustomLocationId = $(az customlocation show --name "jumpstart-secondary-cl" --resource-group $Env:resourceGroup --query id -o tsv)

$dataControllerParams = "$Env:TempDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace $primaryCustomLocationId,$secondaryCustomLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace $primaryDcName,$secondaryDcName | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $Env:resourceGroup `
                           --template-file "$Env:TempDir\dataController.json" `
                           --parameters "$Env:TempDir\dataController.parameters.json"

Write-Host "`n"
Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")

Write-Host "`n"
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"


# If flag set, deploy SQL MI
if ( $Env:deploySQLMI -eq $true )
{
& "$Env:TempDir\DeploySQLMI.ps1"
}

# Enabling data controller auto metrics & logs upload to log analytics on the primary cluster
kubectx primary
Write-Host "`n"
Write-Host "Enabling data controller auto metrics & logs upload to log analytics on the primary cluster"
Write-Host "`n"
$Env:WORKSPACE_ID=$(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name $primaryDcName --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name $primaryDcName --resource-group $Env:resourceGroup --auto-upload-metrics true

# Enabling data controller auto metrics & logs upload to log analytics on the secondary cluster
kubectx secondary
Write-Host "`n"
Write-Host "Enabling data controller auto metrics & logs upload to log analytics on the secondary cluster"
Write-Host "`n"
$Env:WORKSPACE_ID=$(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name $secondaryDcName --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name $secondaryDcName --resource-group $Env:resourceGroup --auto-upload-metrics true

# Applying Azure Data Studio settings template file and operations url shortcut
if ( $Env:deploySQLMI -eq $true){
    Write-Host "`n"
    Write-Host "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "$Env:TempDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

    # Creating desktop url shortcuts for built-in Grafana and Kibana services 
    $GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $GrafanaURL = "https://"+$GrafanaURL+":3000"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Grafana.url")
    $Favorite.TargetPath = $GrafanaURL;
    $Favorite.Save()

    $KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $KibanaURL = "https://"+$KibanaURL+":5601"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Kibana.url")
    $Favorite.TargetPath = $KibanaURL;
    $Favorite.Save()
}

Write-Host "`n"
Write-Host "Switching to primary"
kubectx primary
Write-Host "`n"

# Changing to Client VM wallpaper
$imgPath="$Env:TempDir\wallpaper.png"
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