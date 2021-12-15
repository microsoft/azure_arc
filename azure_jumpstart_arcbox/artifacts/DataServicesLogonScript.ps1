Start-Transcript -Path C:\ArcBox\DataServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Required for azcopy
$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal

# Required for CLI commands
az login --service-principal --username $env:spnClientID --password $env:spnClientSecret --tenant $env:spnTenantId

# Install Azure Data Studio extensions
Write-Host "`n"
Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"
$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3

# Create Azure Data Studio desktop shortcut
Write-Host "`n"
Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Register Azure providers
az provider register --namespace 'Microsoft.Kubernetes' --wait
az provider register --namespace 'Microsoft.KubernetesConfiguration' --wait
az provider register --namespace 'Microsoft.ExtendedLocation' --wait
az provider register --namespace 'Microsoft.AzureArcData' --wait
az provider register --namespace 'Microsoft.PolicyInsights' --wait

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Host "Downloading CAPI Kubernetes cluster kubeconfig file"
$sourceFile = "https://$env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config.arcbox-capi-data"
$context = (Get-AzStorageAccount -ResourceGroupName $env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$env:USERNAME\.kube\config"
kubectl config rename-context "arcbox-capi-data-admin@arcbox-capi-data" "arcbox-capi"

# Creating Storage Class with azure-managed-disk for the CAPI cluster
Write-Host "`n"
Write-Host "Creating Storage Class with azure-managed-disk for the CAPI cluster"
kubectl apply -f "C:\ArcBox\capiStorageClass.yaml"

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
azdata --version

# Onboarding the CAPI cluster as an Azure Arc-enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Host "`n"
$connectedClusterName="ArcBox-CAPI-Data"
az connectedk8s connect --name $connectedClusterName --resource-group $env:resourceGroup --location $env:azureLocation --tags 'Project=jumpstart_arcbox'
Start-Sleep -Seconds 10
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host }}
az k8s-extension create --name arc-data-services --extension-type microsoft.arcdataservices --cluster-type connectedClusters --cluster-name $connectedClusterName --resource-group $env:resourceGroup --auto-upgrade false --scope cluster --release-namespace arc --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

Do {
    Write-Host "Waiting for bootstrapper pod, hold tight..."
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($podStatus -eq "Nope")

$connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $connectedClusterName --resource-group $env:resourceGroup --query id -o tsv
Start-Sleep -Seconds 20
az customlocation create --name 'arcbox-cl' --resource-group $env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig "C:\Users\$env:USERNAME\.kube\config"

$workspaceResourceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query id -o tsv)

# Configuring Azure Policy for Kubernetes on the cluster
az k8s-extension create --cluster-type connectedClusters --cluster-name $connectedClusterName --resource-group $env:resourceGroup --extension-type Microsoft.PolicyInsights --name arc-azurepolicy

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "`n"
Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
Write-Host "`n"
az k8s-extension create --name "azuremonitor-containers" --cluster-name $connectedClusterName --resource-group $env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId

# Deploying Azure Defender Kubernetes extension instance
Write-Host "`n"
Write-Host "Create Azure Defender Kubernetes extension instance"
Write-Host "`n"
az k8s-extension create --name "azure-defender" --cluster-name $connectedClusterName --resource-group $env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureDefender.Kubernetes --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId

# Deploying Azure Arc Data Controller
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$customLocationId = $(az customlocation show --name "arcbox-cl" --resource-group $env:resourceGroup --query id -o tsv)
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "C:\ArcBox\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage',$env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage',$env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage',$env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage',$env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage',$env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage',$env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage',$env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage',$workspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage',$workspaceKey | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $env:resourceGroup --template-file "C:\ArcBox\dataController.json" --parameters "C:\ArcBox\dataController.parameters.json"
Write-Host "`n"

Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

# Deploy SQL MI and PostgreSQL data services
& "C:\ArcBox\DeploySQLMI.ps1"
& "C:\ArcBox\DeployPostgreSQL.ps1"

# Replacing Azure Data Studio settings template file
Write-Host "Replacing Azure Data Studio settings template file"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "C:\ArcBox\settingsTemplate.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

# Downloading Rancher K3s kubeconfig file
Write-Host "Downloading Rancher K3s kubeconfig file"
$sourceFile = "https://$env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/config"
$context = (Get-AzStorageAccount -ResourceGroupName $env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$env:USERNAME\.kube\config-k3s"

# Merging kubeconfig files from CAPI and Rancher K3s
Write-Host "Merging kubeconfig files from CAPI and Rancher K3s clusters"
Copy-Item -Path "C:\Users\$env:USERNAME\.kube\config" -Destination "C:\Users\$env:USERNAME\.kube\config.backup"
$env:KUBECONFIG="C:\Users\$env:USERNAME\.kube\config;C:\Users\$env:USERNAME\.kube\config-k3s"
kubectl config view --raw > C:\users\$env:USERNAME\.kube\config_tmp
kubectl config get-clusters --kubeconfig=C:\users\$env:USERNAME\.kube\config_tmp
Remove-Item -Path "C:\Users\$env:USERNAME\.kube\config"
Remove-Item -Path "C:\Users\$env:USERNAME\.kube\config-k3s"
Move-Item -Path "C:\Users\$env:USERNAME\.kube\config_tmp" -Destination "C:\users\$env:USERNAME\.kube\config"
$env:KUBECONFIG="C:\users\$env:USERNAME\.kube\config"
kubectx

# Sending deployement status message to Azure storage account queue
# if ($env:flavor -eq "Full" -Or $env:flavor -eq "Developer") {
#     & "C:\ArcBox\DeploymentStatus.ps1"
# }

# Creating desktop url shortcuts for built-in Grafana and Kibana services 
$GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$GrafanaURL = "https://"+$GrafanaURL+":3000"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($env:USERPROFILE + "\Desktop\Grafana.url")
$Favorite.TargetPath = $GrafanaURL;
$Favorite.Save()

$KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$KibanaURL = "https://"+$KibanaURL+":5601"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($env:USERPROFILE + "\Desktop\Kibana.url")
$Favorite.TargetPath = $KibanaURL;
$Favorite.Save()

# Changing to Jumpstart ArcBox wallpaper
$imgPath="C:\ArcBox\wallpaper.png"
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
