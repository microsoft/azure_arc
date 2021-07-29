Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

# Deployment environment variables
$connectedClusterName = "Arc-Data-AKS"

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId

az account set --subscription $env:subscriptionId

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
az config set extension.use_dynamic_install=yes_without_prompt

Write-Host "`n"
az -v

# Getting AKS cluster credentials kubeconfig file
Write-Host "Getting AKS cluster credentials"
Write-Host "`n"
az aks get-credentials --resource-group $env:resourceGroup `
                       --name $env:clusterName --admin

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"

# Monitor pods across namespaces
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pods --all-namespaces; Start-Sleep -Seconds 5; Clear-Host }}

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --location $env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services' ` --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
                        # This is the Custom Locations Enterprise Application ObjectID from AAD

Start-Sleep -Seconds 10

############################################################################################################################
# Create Azure Machine Learning extension (Ctrl + K + C/U to Block/Unblock)

# Training only 
# az k8s-extension create --name amlarc-compute `
#                         --extension-type Microsoft.AzureML.Kubernetes `
# 								  --cluster-type connectedClusters `
#                         --cluster-name $connectedClusterName `
#                         --resource-group $env:resourceGroup `
#                         --scope cluster `
#                         --configuration-settings enableTraining=True

# Inferencing only
# az k8s-extension create --name amlarc-compute `
# 								--extension-type Microsoft.AzureML.Kubernetes `
# 								--cluster-type connectedClusters `
# 								--cluster-name $connectedClusterName `
# 								--resource-group $env:resourceGroup `
# 								--scope cluster `
# 								--configuration-settings enableInference=True allowInsecureConnections=True inferenceLoadBalancerHA=False # This is since our K8s is 1 node

# Print out extension status
# Write-Host "Waiting for extension install, hold tight..."
# Do 
# {
#     $response = az k8s-extension show --name amlarc-compute `
# 											--cluster-type connectedClusters `
# 											--cluster-name $connectedClusterName `
# 											--resource-group $env:resourceGroup `
# 											--output json | ConvertFrom-Json

# 		Write-Host ("Status: ", $response.installState)

# 		If ($response.installState -eq "Failed") {break}

# 		Start-Sleep -Seconds 20

# } while (($response.installState -ne "Installed") -and ($response.installState -ne "Failed"))

# # Received error
# If ($response.installState -eq "Failed"){
# 	Write-Host "Installation failed:" -ForegroundColor Red
# 	Write-Host $response.errorInfo
# }

############################################################################################################################

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
Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

# Stop-Process -Name powershell -Force

Stop-Transcript