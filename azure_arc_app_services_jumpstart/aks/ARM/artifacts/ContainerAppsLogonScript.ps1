Start-Transcript -Path C:\Temp\ContainerAppsLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Deployment environment variables
$Env:TempDir = "C:\Temp"
$namespace="appplat-ns"
$extensionName = "appenv-ext"
$connectedEnvironmentName=$Env:clusterName+"-env"
$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
$logAnalyticsWorkspaceIdEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceId))
$logAnalyticsKeyEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceKey))

# Set default subscription to run commands against
# "subscriptionId" value comes from clientVM.json ARM template, based on which 
# subscription user deployed ARM template to. This is needed in case Service 
# Principal has access to multiple subscriptions, which can break the automation logic
az account set --subscription $Env:subscriptionId

# Registering Azure Arc providers
Write-Host "`n"
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.App --wait

az provider show --namespace Microsoft.Kubernetes -o table
Write-Host "`n"
az provider show --namespace Microsoft.KubernetesConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.ExtendedLocation -o table
Write-Host "`n"
az provider show --namespace Microsoft.App -o table
Write-Host "`n"

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt

# Installing Azure CLI extensions
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y
az extension add --source https://download.microsoft.com/download/5/c/2/5c2ec3fc-bd2a-4615-a574-a1b7c8e22f40/containerapp-0.0.1-py2.py3-none-any.whl --yes

Write-Host "`n"
az -v

# Getting AKS cluster credentials kubeconfig file
Write-Host "`n"
Write-Host "Getting AKS cluster credentials"
Write-Host "`n"
az aks get-credentials --resource-group $Env:resourceGroup `
                       --name $Env:clusterName --admin

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Onboarding the AKS cluster as an Azure Arc-enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Host "`n"

# Localize kubeconfig
$Env:KUBECONTEXT = kubectl config current-context
$Env:KUBECONFIG = "C:\Users\$Env:adminUsername\.kube\config"
Start-Sleep -Seconds 10

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $Env:connectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $Env:azureLocation `
                        --tags "jumpstart_azure_arc_app_services" `
                        --kube-config $Env:KUBECONFIG `
                        --kube-context $Env:KUBECONTEXT `
                        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

Start-Sleep -Seconds 10

# Deploying Application Platform extension
Write-Host "Deploying Application Platform extension. Hold tight, this might take a few minutes..."
Write-Host "`n"

az k8s-extension create `
    --resource-group $Env:resourceGroup `
    --name $extensionName `
    --cluster-type connectedClusters `
    --cluster-name $Env:connectedClusterName `
    --extension-type 'Microsoft.App.Environment' `
    --release-train stable `
    --auto-upgrade-minor-version true `
    --scope cluster `
    --release-namespace $namespace `
    --configuration-settings "Microsoft.Customlocation.ServiceAccount=default" `
    --configuration-settings "appsextensionNamespace=${namespace}" `
    --configuration-settings "CLUSTER_NAME=$Env:connectedClusterName" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
    --config-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" `
    --config-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"

$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n appplat-ns; Start-Sleep -Seconds 5; Clear-Host }}

# Get Application Platform extension Id
$extensionId=$(az k8s-extension show `
    --cluster-type connectedClusters `
    --cluster-name $Env:connectedClusterName `
    --resource-group $Env:resourceGroup `
    --name $extensionName `
    --query id `
    --output tsv)

az resource wait --ids $extensionId --custom "properties.installState!='Pending'"

# Deploying Custom Location
Write-Host "`n"
Write-Host "Deploying Custom Location."
Write-Host "`n"

az connectedk8s enable-features --name $Env:connectedClusterName `
                                --resource-group $Env:resourceGroup `
                                --custom-locations-oid $Env:connectedClusterName `
                                --features cluster-connect custom-locations

$connectedClusterId = $(az connectedk8s show `
    --name $Env:clusterName `
    --resource-group $Env:resourceGroup `
    --query id `
    --output tsv)

$customLocationId = $(az customlocation create `
    --name 'jumpstart-cl' `
    --resource-group $Env:resourceGroup `
    --namespace $namespace `
    --host-resource-id $connectedClusterId `
    --cluster-extension-ids $extensionId `
    --kubeconfig "C:\Users\$Env:USERNAME\.kube\config" `
    --query id `
    --output tsv)

# Deploying Connected Environment
Write-Host "`n"
Write-Host "Deploying Connected Environment. Hold tight, this might take a few minutes..."
Write-Host "`n"
az containerapp connected-env create `
    --resource-group $Env:resourceGroup `
    --name $connectedEnvironmentName `
    --custom-location $customLocationId `
    --location $Env:azureLocation

$containerAppEnvId = $(az containerapp connected-env show `
    --name $connectedEnvironmentName `
     --resource-group $Env:resourceGroup  `
     --query id `
     --output tsv)

az resource wait --ids $containerAppEnvId --created

# Deploying Products API Container App
Write-Host "`n"
Write-Host "Creating the products api container app"
Write-Host "`n"
az containerapp create `
    --name 'products' `
    --resource-group $Env:resourceGroup `
    --environment $connectedEnvironmentName `
    --environment-type connected `
    --enable-dapr true `
    --dapr-app-id 'products' `
    --dapr-app-port 80 `
    --dapr-app-protocol 'http' `
    --revisions-mode 'single' `
    --image $Env:productsImage `
    --ingress 'internal' `
    --target-port 80 `
    --transport 'http' `
    --min-replicas 1 `
    --max-replicas 1 `
    --query properties.configuration.ingress.fqdn

Write-Host "`n"
Do {
    Write-Host "Waiting for products api to become available."
    Start-Sleep -Seconds 15
    $productsapi = $(if(kubectl get pods -n $namespace | Select-String "product" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($productsapi -eq "Nope")

# Deploying Inventory API Container App
Write-Host "`n"
Write-Host "Creating the inventory api container app"
Write-Host "`n"
az containerapp create `
    --name 'inventory' `
    --resource-group $Env:resourceGroup `
    --environment $connectedEnvironmentName `
    --environment-type connected `
    --enable-dapr true `
    --dapr-app-id 'inventory' `
    --dapr-app-port 80 `
    --dapr-app-protocol 'http' `
    --revisions-mode 'single' `
    --image $Env:inventoryImage `
    --ingress 'internal' `
    --target-port 80 `
    --transport 'http' `
    --min-replicas 1 `
    --max-replicas 1 `
    --query properties.configuration.ingress.fqdn

Do {
    Write-Host "Waiting for inventory api to become available."
    Start-Sleep -Seconds 15
    $inventoryapi = $(if(kubectl get pods -n $namespace | Select-String "inventory" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($inventoryapi -eq "Nope")

# Deploying Store API Container App
Write-Host "`n"
Write-Host "Creating the store api container app"
Write-Host "`n"
az containerapp create `
    --name 'store' `
    --resource-group $Env:resourceGroup `
    --environment $connectedEnvironmentName `
    --environment-type connected `
    --enable-dapr true `
    --dapr-app-id 'store' `
    --dapr-app-port 80 `
    --dapr-app-protocol 'http' `
    --revisions-mode 'single' `
    --image $Env:storeImage `
    --ingress 'external' `
    --target-port 80 `
    --transport 'http' `
    --min-replicas 1 `
    --max-replicas 1 `
    --query properties.configuration.ingress.fqdn

Do {
    Write-Host "Waiting for store api to become available."
    Start-Sleep -Seconds 15
    $storeapi = $(if(kubectl get pods -n $namespace | Select-String "store" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($storeapi -eq "Nope")

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
Unregister-ScheduledTask -TaskName "ContainerAppsLogonScript" -Confirm:$false
Start-Sleep -Seconds 5
