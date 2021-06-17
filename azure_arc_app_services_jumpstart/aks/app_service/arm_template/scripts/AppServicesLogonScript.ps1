Start-Transcript -Path C:\Temp\AppServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# $azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($env:spnClientId , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal

az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId
Write-Host "`n"


# Deploying AKS cluster
Write-Host "Deploying AKS cluster"
Write-Host "`n"
az aks create --resource-group $env:resourceGroup --name $env:clusterName --location $env:azureLocation --enable-aad --enable-azure-rbac --generate-ssh-keys --tags "Project=jumpstart_azure_arc_app_services" --enable-addons monitoring
az aks get-credentials --resource-group $env:resourceGroup --name $env:clusterName --admin
$aksResourceGroupMC = $(az aks show --resource-group $env:resourceGroup --name $env:clusterName -o tsv --query nodeResourceGroup)

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes

# Attaching network secuirty group to the deployment virtual network subnet
# Write-Host "Attaching network secuirty group to the deployment virtual network subnet"
# $aksResourceGroupMC = "MC_${env:resourceGroup}_${env:clusterName}_${env:azureLocation}"
# $aksVnetMC = az network vnet list --resource-group $aksResourceGroupMC --query "[0].name" --output tsv
# $nsgName = az network nsg list --resource-group $aksResourceGroupMC --query "[0].name" --output tsv
# $subnetId = az network vnet subnet list --resource-group $aksResourceGroupMC --vnet-name $aksVnetMC --query "[0].id" --output tsv
# az network nsg create -g $aksResourceGroupMC -n $nsgName --output none
# az network nsg rule create -g $aksResourceGroupMC --nsg-name $nsgName -n Inbound-HTTP --destination-port-ranges 80 --priority 100 --output none
# az network nsg rule create -g $aksResourceGroupMC --nsg-name $nsgName -n Inbound-HTTPS --destination-port-ranges 443 --priority 101 --output none
# az network nsg rule create -g $aksResourceGroupMC --nsg-name $nsgName -n Inbound-SQL --destination-port-ranges 1433 --priority 102 --output none
# az network vnet subnet update --nsg $nsgName --ids $subnetId --output none

# Creating Azure Public IP resource to be used by the Azure Arc app service
Write-Host "Creating Azure Public IP resource to be used by the Azure Arc app service"
Write-Host "`n"
az network public-ip create --resource-group $aksResourceGroupMC --name "Arc-AppSvc-PIP" --sku STANDARD
$staticIp = $(az network public-ip show --resource-group $aksResourceGroupMC --name "Arc-AppSvc-PIP" --output tsv --query ipAddress)

# Registering Azure Arc providers
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.Web --wait

az provider show --namespace Microsoft.Kubernetes -o table
Write-Host "`n"
az provider show --namespace Microsoft.KubernetesConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.ExtendedLocation -o table
Write-Host "`n"
az provider show --namespace Microsoft.Web -o table
Write-Host "`n"

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

# # Getting AKS credentials
# Write-Host "Getting AKS credentials"
# Write-Host "`n"
# $azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($env:spnClientId , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal
# Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:clusterName -Admin -Force

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"
az connectedk8s connect --name $env:clusterName --resource-group $env:resourceGroup --location $env:azureLocation --tags 'Project=jumpstart_azure_arc_app_services' --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
Start-Sleep -Seconds 10
$namespace="appservices"

$extensionName = "arc-app-services"
$kubeEnvironmentName=$env:clusterName
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName --query primarySharedKey -o tsv)
$workspaceIdEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceId))
$workspaceKeyEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceKey))

$extensionId = az k8s-extension create -g $env:resourceGroup --name $extensionName --query id -o tsv `
    --cluster-type connectedClusters -c $env:clusterName `
    --extension-type 'Microsoft.Web.Appservice' --release-train stable --auto-upgrade-minor-version true `
    --scope cluster --release-namespace "$namespace" `
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default"  `
    --configuration-settings "appsNamespace=$namespace"  `
    --configuration-settings "clusterName=$kubeEnvironmentName"  `
    --configuration-settings "loadBalancerIp=$staticIp"  `
    --configuration-settings "keda.enabled=true"  `
    --configuration-settings "buildService.storageClassName=default"  `
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce"  `
    --configuration-settings "customConfigMap=$namespace/kube-environment-config" `
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=$aksResourceGroupMC" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${workspaceIdEnc}" --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${workspaceKeyEnc}"

$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n appservices; Start-Sleep -Seconds 5; Clear-Host }}
az resource wait --ids $extensionId --api-version 2020-07-01-preview --custom "properties.installState!='Pending'"

Do {
   Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $logProcessorStatus = $(if(kubectl describe daemonset "arc-app-services-k8se-log-processor" -n appservices | Select-String "Pods Status:  3 Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($logProcessorStatus -eq "Nope")

Do {
   Write-Host "Waiting for build service to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $buildService = $(if(kubectl get pods -n appservices | Select-String "k8se-build-service" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($buildService -eq "Nope")

Do {
   Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $logProcessorStatus = $(if(kubectl describe daemonset "arc-app-services-k8se-log-processor" -n appservices | Select-String "Pods Status:  3 Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($logProcessorStatus -eq "Nope")

Write-Host "Deploying App Service Kubernetes Environment"
Write-Host "`n"
$connectedClusterId = az connectedk8s show --name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name $extensionName --cluster-type connectedClusters --cluster-name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
$customLocationId = $(az customlocation create --name 'jumpstart-cl' --resource-group $env:resourceGroup --namespace appservice --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId  --query id -o tsv)
az appservice kube create --resource-group $env:resourceGroup --name $kubeEnvironmentName --custom-location $customLocationId --static-ip "$staticIp" --location "Central US EUAP" --output none 

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
# Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "AppServicesLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

# Stop-Process -Name powershell -Force
