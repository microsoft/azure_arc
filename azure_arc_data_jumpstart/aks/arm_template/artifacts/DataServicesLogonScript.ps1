Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId

Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"

$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"

& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio.lnk"
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
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-configuration" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y

Write-Host "`n"
az -v

# Getting AKS cluster credentials
Write-Host "Getting AKS cluster credentials"
Write-Host "`n"
az aks get-credentials --resource-group $env:resourceGroup --name $env:clusterName --admin

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"
az connectedk8s connect --name "Arc-Data-AKS" --resource-group $env:resourceGroup --location $env:azureLocation --tags 'Project=jumpstart_azure_arc_data_services_services' --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
Start-Sleep -Seconds 10
$deploymentNamespace = "dataservices"
$customlocationName = "Jumpstart-CL"
$controllerName = "Jumpstart-DC"
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n $deploymentNamespace; Start-Sleep -Seconds 5; Clear-Host }}
az k8s-extension create --name arc-data-services --extension-type microsoft.arcdataservices --cluster-type connectedClusters --cluster-name 'Arc-Data-AKS' --resource-group $env:resourceGroup --auto-upgrade false --scope cluster --release-namespace $deploymentNamespace --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

Do {
    Write-Host "Waiting for bootstrapper pod, hold tight..."
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($podStatus -eq "Nope")

$connectedClusterId = az connectedk8s show --name 'Arc-Data-AKS' --resource-group $env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name 'Arc-Data-AKS' --resource-group $env:resourceGroup --query id -o tsv
Start-Sleep -Seconds 20
az customlocation create --name $customlocationName --resource-group $env:resourceGroup --namespace $deploymentNamespace --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId

# Deploying Azure Arc Data Controller
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$customLocationId = $(az customlocation show --name $customlocationName --resource-group $env:resourceGroup --query id -o tsv)
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "C:\Temp\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage',$env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage',$env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage',$env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'controllerName',$controllerName | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage',$env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage',$env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage',$env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage',$env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage',$workspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage',$workspaceKey | Set-Content -Path $dataControllerParams

az deployment group create --resource-group $env:resourceGroup --template-file "C:\Temp\dataController.json" --parameters "C:\Temp\dataController.parameters.json"
Write-Host "`n"

Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

if ( $env:deploySQLMI -eq $true )
{
    & "C:\Temp\DeploySQLMI.ps1"
}

# if ( $env:deployPostgreSQL -eq $true )
# {
#     & "C:\Temp\DeployPostgreSQL.ps1"
# }

# Changing to Client VM wallpaper
$imgPath="C:\Temp\wallpaper.png"
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
