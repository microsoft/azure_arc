Start-Transcript -Path C:\Temp\AppServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal

az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId
Write-Host "`n"

# Registering Azure Arc providers
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

# Adding Azure Arc CLI extensions
Write-Host "Adding Azure Arc CLI extensions"
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-configuration" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y
az extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl"

Write-Host "`n"
az -v

# Getting AKS credentials
Write-Host "Getting AKS credentials"
Write-Host "`n"
$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal
Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:clusterName -Force

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"
az connectedk8s connect --name $env:clusterName --resource-group $env:resourceGroup --location $env:azureLocation --tags 'Project=jumpstart_azure_arc_app_services' --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
Start-Sleep -Seconds 10
$namespace="appservices"
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n $namespace; Start-Sleep -Seconds 5; Clear-Host }}

$kubeEnvironmentName="$env:clusterName-appsvc"
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceIdBase64 = $([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("$workspaceId'")))
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName --query primarySharedKey -o tsv)
$workspaceKeyBase64 = $([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("$workspaceKey'")))

[String]$logAnalyticsWorkspaceIdEnc = $workspaceIdBase64
"logAnalyticsWorkspaceIdEnc = {0}" -f $logAnalyticsWorkspaceIdEnc
$logAnalyticsWorkspaceIdEnc

[String]$logAnalyticsWorkspaceKeyEnc = $workspaceKeyBase64
"logAnalyticsWorkspaceKeyEnc = {0}" -f $logAnalyticsWorkspaceKeyEnc
$logAnalyticsWorkspaceKeyEnc


az k8s-extension create `
   --resource-group $env:resourceGroup `
   --name arc-app-services `
   --cluster-type connectedClusters `
   --cluster-name $env:clusterName `
   --extension-type 'Microsoft.Web.Appservice' `
   --release-train stable `
   --auto-upgrade-minor-version true `
   --scope cluster `
   --release-namespace $namespace `
   --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" `
   --configuration-settings "appsNamespace=$namespace" `
   --configuration-settings "clusterName=$env:clusterName" `
   --configuration-settings "loadBalancerIp=$publicIp" `
   --configuration-settings "keda.enabled=true" `
   --configuration-settings "buildService.storageClassName=default" `
   --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" `
   --configuration-settings "customConfigMap=$namespace/kube-environment-config" `
   --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=$env:resourceGroup" 
   # --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
   # --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=$logAnalyticsWorkspaceIdEnc" `
   # --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=$logAnalyticsWorkspaceKeyEnc"


# Do {
#     Write-Host "Waiting for bootstrapper pod, hold tight..."
#     Start-Sleep -Seconds 20
#     $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
#     } while ($podStatus -eq "Nope")

# $connectedClusterId = az connectedk8s show --name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
# $extensionId = az k8s-extension show --name appservice --cluster-type connectedClusters --cluster-name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
# Start-Sleep -Seconds 20
# az customlocation create --name 'jumpstart-cl' --resource-group $env:resourceGroup --namespace appservice --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId

# $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)






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

Stop-Process -Name powershell -Force
