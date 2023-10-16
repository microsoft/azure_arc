Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

# Deployment environment variables
$Env:TempDir = "C:\Temp"

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Installing Azure CLI arcdata extension
Write-Host "`n"
Write-Host "Installing Azure CLI arcdata extension"
az extension add --name arcdata

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

# Adding Azure Arc CLI extensions
Write-Host "Adding Azure Arc CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt

Write-Host "`n"
az -v

# Downloading Microk8s Kubernetes cluster kubeconfig file
Write-Host "Downloading Microk8s Kubernetes cluster kubeconfig file"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Onboarding the Microk8s cluster as an Azure Arc-enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Host "`n"

# Monitor pods across namespaces
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pods --all-namespaces; Start-Sleep -Seconds 5; Clear-Host }}

# Localize kubeconfig
$Env:KUBECONTEXT = kubectl config current-context
$Env:KUBECONFIG = "C:\Users\$Env:adminUsername\.kube\config"

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $Env:arcDataClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $Env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services' `
                        --kube-config $Env:KUBECONFIG `
                        --kube-context $Env:KUBECONTEXT `
                        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

Start-Sleep -Seconds 10

# Create Azure Arc-enabled Data Services extension
az k8s-extension create --name arc-data-services `
                        --extension-type microsoft.arcdataservices `
                        --cluster-type connectedClusters `
                        --cluster-name $Env:arcDataClusterName `
                        --resource-group $Env:resourceGroup `
                        --auto-upgrade false `
                        --scope cluster `
                        --version 1.24.0 `
                        --release-namespace arc `
                        --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

Do {
    Write-Host "Waiting for bootstrapper pod, hold tight..."
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($podStatus -eq "Nope")

$connectedClusterId = az connectedk8s show --name $Env:arcDataClusterName --resource-group $Env:resourceGroup --query id -o tsv

$extensionId = az k8s-extension show --name arc-data-services `
                                     --cluster-type connectedClusters `
                                     --cluster-name $Env:arcDataClusterName ` --resource-group $Env:resourceGroup `
                                     --query id -o tsv

Start-Sleep -Seconds 20

# Create Custom Location

az connectedk8s enable-features -n $Env:arcDataClusterName `
                                -g $Env:resourceGroup `
                                --custom-locations-oid $Env:customLocationRPOID `
                                --features cluster-connect custom-locations


$customLocationName = "$Env:arcDataClusterName-cl" 
az customlocation create --name $customlocationName `
                         --resource-group $Env:resourceGroup `
                         --namespace arc `
                         --host-resource-id $connectedClusterId `
                         --cluster-extension-ids $extensionId

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
Write-Host "`n"

az k8s-extension create --name "azuremonitor-containers" `
                        --cluster-name $Env:arcDataClusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureMonitor.Containers

# Deploying Azure Defender Kubernetes extension instance
Write-Host "Create Azure Defender Kubernetes extension instance"
Write-Host "`n"
az k8s-extension create --name "azure-defender" `
                        --cluster-name $Env:arcDataClusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureDefender.Kubernetes

# Deploying Azure Arc Data Controller
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$customLocationId = $(az customlocation show --name $customLocationName --resource-group $Env:resourceGroup --query id -o tsv)
$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "$Env:TempDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage',$Env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage',$Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage',$Env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage',$Env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage',$Env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage',$Env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage',$Env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage',$workspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage',$workspaceKey | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $Env:resourceGroup `
                           --template-file "$Env:TempDir\dataController.json" `
                           --parameters "$Env:TempDir\dataController.parameters.json"
Write-Host "`n"

Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

# If flag set, deploy SQL MI
if ( $Env:deploySQLMI -eq $true )
{
    & "$Env:TempDir\DeploySQLMI.ps1"
}

# If flag set, deploy PostgreSQL
if ( $Env:deployPostgreSQL -eq $true )
{
    & "$Env:TempDir\DeployPostgreSQL.ps1"
}

# Enabling data controller auto metrics & logs upload to log analytics
Write-Host "Enabling data controller auto metrics & logs upload to log analytics"
Write-Host "`n"
$Env:WORKSPACE_ID=$(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name jumpstart-dc --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name jumpstart-dc --resource-group $Env:resourceGroup --auto-upload-metrics true

# Applying Azure Data Studio settings template file and operations url shortcut
if ( $Env:deploySQLMI -eq $true -or $Env:deployPostgreSQL -eq $true ){
    Write-Host "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "$Env:TempDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

    # Creating desktop url shortcuts for built-in Grafana and Kibana services 
    $nodePrivateIP = az vm show -g $Env:resourceGroup -n $Env:vmMicrok8sName --query privateIps -d --out tsv

    $GrafanaPort = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.spec.ports[].nodePort}'
    $GrafanaURL = "https://"+$nodePrivateIP+":$GrafanaPort"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Grafana.url")
    $Favorite.TargetPath = $GrafanaURL;
    $Favorite.Save()

    $KibanaPort = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.spec.ports[].nodePort}'
    $KibanaURL = "https://"+$nodePrivateIP+":$KibanaPort"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Kibana.url")
    $Favorite.TargetPath = $KibanaURL;
    $Favorite.Save()
}

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