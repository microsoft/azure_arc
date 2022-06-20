Start-Transcript -Path C:\Temp\DataServicesLogonScript.log

# Deployment environment variables
$connectedClusterName="Arc-Data-EKS-K8s"

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal

# Login as service principal
az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId

# Installing Azure CLI arcdata extension
Write-Host "`n"
Write-Host "Installing Azure CLI arcdata extension"
az extension add --name arcdata

# Set default subscription to run commands against
# "subscriptionId" value comes from clientVM.json ARM template, based on which 
# subscription user deployed ARM template to. This is needed in case Service 
# Principal has access to multiple subscriptions, which can break the automation logic
az account set --subscription $env:subscriptionId

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

# Create Azure Data Studio desktop shortcut
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
az config set extension.use_dynamic_install=yes_without_prompt

Write-Host "Azure CLI version: "
Write-Host "`n"
az -v
Write-Host "`n"

Write-Host "`n"
Write-Host "Azure CLI extensions installed: "
az extension list
Write-Host "`n"

# Settings up kubectl
Write-Host "Setting up the kubectl environment"
Write-Host "`n"

kubectl version

# Leverages AWS IAM to get access to EKS Cluster - see https://aws.amazon.com/premiumsupport/knowledge-center/amazon-eks-cluster-access/
kubectl apply -f "C:\Temp\configmap.yml"

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

Start-Sleep -Seconds 10

# Onboarding the EKS cluster as an Azure Arc-enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc-enabled Kubernetes cluster"
Write-Host "`n"

# Monitor pods across namespaces
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pods --all-namespaces; Start-Sleep -Seconds 5; Clear-Host }}

# Localize kubeconfig
$env:KUBECONTEXT = kubectl config current-context
$env:KUBECONFIG = "C:\Users\$env:adminUsername\.kube\config"

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --location $env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_data_services' `
                        --kube-config $env:KUBECONFIG `
                        --kube-context $env:KUBECONTEXT

Start-Sleep -Seconds 10

# Create Azure Arc-enabled Data Services extension
az k8s-extension create --name arc-data-services `
                        --extension-type microsoft.arcdataservices `
                        --cluster-type connectedClusters `
                        --cluster-name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --auto-upgrade false `
                        --scope cluster `
                        --release-namespace arc `
                        --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

Do {
    Write-Host "Waiting for bootstrapper pod, hold tight..."
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($podStatus -eq "Nope")

$connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $env:resourceGroup --query id -o tsv

$extensionId = az k8s-extension show --name arc-data-services `
                                     --cluster-type connectedClusters `
                                     --cluster-name $connectedClusterName `
                                     --resource-group $env:resourceGroup `
                                     --query id -o tsv
Start-Sleep -Seconds 20

# Create Custom Location
az customlocation create --name 'jumpstart-cl' `
                         --resource-group $env:resourceGroup `
                         --namespace arc `
                         --host-resource-id $connectedClusterId `
                         --cluster-extension-ids $extensionId `
                         --kubeconfig $env:KUBECONFIG

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
Write-Host "`n"

az k8s-extension create --name "azuremonitor-containers" `
                        --cluster-name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureMonitor.Containers

# Deploying Azure Defender Kubernetes extension instance
Write-Host "Create Azure Defender Kubernetes extension instance"
Write-Host "`n"
az k8s-extension create --name "azure-defender" `
                        --cluster-name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureDefender.Kubernetes

# Creating Log Analytics Workspace for Metric Upload
Write-Host "Deploying Log Analytics Workspace"
Write-Host "`n"

az monitor log-analytics workspace create --resource-group $env:resourceGroup `
                                          --workspace-name "jumpstartlaws"

# Deploying Azure Arc Data Controller
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"

$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name "jumpstartlaws" --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name "jumpstartlaws" --query primarySharedKey -o tsv)

$dataControllerParams = "C:\Temp\dataController.parameters.json"

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

az deployment group create --resource-group $env:resourceGroup `
                           --template-file "C:\Temp\dataController.json" `
                           --parameters "C:\Temp\dataController.parameters.json" `
                           --no-wait
Write-Host "`n"

Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

# Need to ensure all Data Controller Pods are running before running SQL MI and Postgres deployment
Do {
    Write-Host "Ensuring all Data Controller Pods are up..."
    # Gets list of Pods in arc namespaces (all DC related thus far) that are not in "Running" state
	$podsPending = kubectl get pods -n arc --field-selector=status.phase!=Running -o jsonpath="{.items[*].metadata.name}"
	# Sets status to "Ready!" only if all pods are "Running"
    $podStatus = $(if($podsPending -eq $null){"Ready!"}Else{"Nope"})
    Start-Sleep -Seconds 30
    } while ($podStatus -eq "Nope")

Write-Host "All data controller pods are ready to go!"
Write-Host "`n"

# If flag set, deploy SQL MI
if ( $env:deploySQLMI -eq $true )
{
    & "C:\Temp\DeploySQLMI.ps1"
}

# If flag set, deploy PostgreSQL
if ( $env:deployPostgreSQL -eq $true )
{
    & "C:\Temp\DeployPostgreSQL.ps1"
}

# Enabling data controller auto metrics & logs upload to log analytics
Write-Host "Enabling data controller auto metrics & logs upload to log analytics"
Write-Host "`n"
$Env:WORKSPACE_ID=$(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name jumpstart-dc --resource-group $env:resourceGroup --auto-upload-logs true
az arcdata dc update --name jumpstart-dc --resource-group $env:resourceGroup --auto-upload-metrics true

# Applying Azure Data Studio settings template file and operations url shortcut
if ( $env:deploySQLMI -eq $true -or $env:deployPostgreSQL -eq $true ){
    Write-Host "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "C:\Temp\settingsTemplate.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

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
}

# Deleting AWS Desktop shortcuts
Write-Host "Deleting AWS Desktop shortcuts"
Write-Host "`n"
Remove-Item -Path "C:\Users\$env:adminUsername\Desktop\EC2 Microsoft Windows Guide.website" -Force
Remove-Item -Path "C:\Users\$env:adminUsername\Desktop\EC2 Feedback.website" -Force

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

Stop-Transcript