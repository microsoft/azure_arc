Start-Transcript -Path C:\Temp\AppServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Deployment environment variables
$Env:TempDir = "C:\Temp"
# $connectedClusterName = $Env:capiArcAppClusterName
$namespace="appservices"
$extensionName = "arc-app-services"
$extensionVersion = "0.13.1"
$apiVersion = "2020-07-01-preview"
$storageClassName = "managed-premium"
# $kubeEnvironmentName=$Env:connectedClusterName + "-" + -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$kubeEnvironmentName="$Env:capiArcAppClusterName-kube"
$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
$logAnalyticsWorkspaceIdEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceId))
$logAnalyticsKeyEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceKey))

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Set default subscription to run commands against
# "subscriptionId" value comes from clientVM.json ARM template, based on which 
# subscription user deployed ARM template to. This is needed in case Service 
# Principal has access to multiple subscriptions, which can break the automation logic
az account set --subscription $Env:subscriptionId

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y
az extension add --name "appservice-kube" -y
az extension add --source "https://aka.ms/logicapp-latest-py2.py3-none-any.whl" -y

Write-Host "`n"
az -v

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Host "Downloading CAPI Kubernetes cluster kubeconfig file"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

Write-Host "`n"
Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Localize kubeconfig
$Env:KUBECONTEXT = kubectl config current-context
$Env:KUBECONFIG = "C:\Users\$Env:adminUsername\.kube\config"

Start-Sleep -Seconds 10
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n appservices; Start-Sleep -Seconds 5; Clear-Host }}

# Deploying Azure App environment
Write-Host "`n"
Write-Host "Deploying Azure App Service Kubernetes environment"
Write-Host "`n"

az k8s-extension create `
   --resource-group $Env:resourceGroup `
   --name $extensionName `
   --version $extensionVersion `
   --cluster-type connectedClusters `
   --cluster-name $Env:capiArcAppClusterName `
   --extension-type 'Microsoft.Web.Appservice' `
   --release-train stable `
   --auto-upgrade-minor-version false `
   --scope cluster `
   --release-namespace $namespace `
   --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" `
   --configuration-settings "appsNamespace=${namespace}" `
   --configuration-settings "clusterName=${kubeEnvironmentName}" `
   --configuration-settings "keda.enabled=true" `
   --configuration-settings "buildService.storageClassName=${storageClassName}"  `
   --configuration-settings "buildService.storageAccessMode=ReadWriteOnce"  `
   --configuration-settings "customConfigMap=${namespace}/kube-environment-config" `
   --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
   --config-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" `
   --config-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"

   $extensionId=$(az k8s-extension show `
   --cluster-type connectedClusters `
   --cluster-name $Env:capiArcAppClusterName `
   --resource-group $Env:resourceGroup `
   --name $extensionName `
   --query id `
   --output tsv)

az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version $apiVersion

Write-Host "`n"
Do {
   Write-Host "Waiting for build service to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 15
   $buildService = $(if(kubectl get pods -n appservices | Select-String "k8se-build-service" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($buildService -eq "Nope")

Do {
   Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 15
   $logProcessorStatus = $(if(kubectl describe daemonset ($extensionName + "-k8se-log-processor") -n appservices | Select-String "Pods Status:  6 Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($logProcessorStatus -eq "Nope")

Write-Host "`n"
Write-Host "Deploying App Service Kubernetes Environment. Hold tight, this might take a few minutes..."
Write-Host "`n"
$connectedClusterId = az connectedk8s show --name $Env:capiArcAppClusterName --resource-group $Env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name $extensionName --cluster-type connectedClusters --cluster-name $Env:capiArcAppClusterName --resource-group $Env:resourceGroup --query id -o tsv
$customLocationId = $(az customlocation create --name "$Env:capiArcAppClusterName-cl" --resource-group $Env:resourceGroup --namespace appservices --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig "C:\Users\$Env:USERNAME\.kube\config" --query id -o tsv)
az appservice kube create --resource-group $Env:resourceGroup --name $kubeEnvironmentName --custom-location $customLocationId --location $Env:azureLocation --output none

Write-Host "`n"
Do {
   Write-Host "Waiting for kube environment to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 15
   $kubeEnvironmentNameStatus = $(if(az appservice kube show --resource-group $Env:resourceGroup --name $kubeEnvironmentName | Select-String '"provisioningState": "Succeeded"' -Quiet){"Ready!"}Else{"Nope"})
   } while ($kubeEnvironmentNameStatus -eq "Nope")


if ( $Env:deployAppService -eq $true )
{
    & "C:\Temp\deployAppService.ps1"
}

if ( $Env:deployFunction -eq $true )
{
    & "C:\Temp\deployFunction.ps1"
}

if ( $Env:deployLogicApp -eq $true )
{
    & "C:\Temp\deployLogicApp.ps1"
}

if ( $Env:deployApiMgmt -eq $true )
{
    & "C:\Temp\deployApiMgmt.ps1"
}

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
Unregister-ScheduledTask -TaskName "AppServicesLogonScript" -Confirm:$false
Start-Sleep -Seconds 5
