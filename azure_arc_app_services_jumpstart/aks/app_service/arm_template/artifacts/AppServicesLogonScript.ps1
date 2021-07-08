Start-Transcript -Path C:\Temp\AppServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId
Write-Host "`n"

# Deploying AKS cluster
Write-Host "Deploying AKS cluster"
Write-Host "`n"
az aks create --resource-group $env:resourceGroup `
              --name $env:clusterName `
              --location $env:azureLocation `
              --kubernetes-version $env:kubernetesVersion `
              --dns-name-prefix $env:dnsPrefix `
              --enable-aad `
              --enable-azure-rbac `
              --generate-ssh-keys `
              --tags "Project=jumpstart_azure_arc_app_services" `
              --enable-addons monitoring

az aks get-credentials --resource-group $env:resourceGroup `
                       --name $env:clusterName `
                       --admin

$aksResourceGroupMC = $(az aks show --resource-group $env:resourceGroup --name $env:clusterName -o tsv --query nodeResourceGroup)

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes

# Creating Azure Public IP resource to be used by the Azure Arc app service
Write-Host "`n"
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
az extension add --name "k8s-extension" --version "0.4.3" -y # Temporary pin
az extension add --name "customlocation" -y
az extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl"

Write-Host "`n"
az -v

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"
az connectedk8s connect --name $env:clusterName `
                        --resource-group $env:resourceGroup `
                        --location $env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_app_services' `
                        --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
                        # This is the Custom Locations Enterprise Application ObjectID from AAD

Start-Sleep -Seconds 10
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n appservices; Start-Sleep -Seconds 5; Clear-Host }}

if ( $env:deployAppService -eq $true )
{
    & "C:\Temp\deployAppService.ps1"
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
