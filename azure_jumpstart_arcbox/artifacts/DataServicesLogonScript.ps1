$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$connectedClusterName=$Env:capiArcDataClusterName
Start-Transcript -Path $Env:ArcBoxLogsDir\DataServicesLogonScript.log

# Required for azcopy and Get-AzResource
Write-Header "Az PowerShell Login"
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".data" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
az extension add --name arcdata --system
az -v

# Installing Azure Data Studio extensions
Write-Header "Installing Azure Data Studio extensions"
$Env:argument1="--install-extension"
$Env:argument2="microsoft.azcli"
$Env:argument3="microsoft.azuredatastudio-postgresql"
$Env:argument4="Microsoft.arc"

& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument3
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument4

# Create Azure Data Studio desktop shortcut
Write-Header "Creating Azure Data Studio Desktop Shortcut"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut
Write-Host "`n"
Write-Host "Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Header "Downloading CAPI K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading 'installCAPI.log' log file
Write-Header "Downloading CAPI Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/installCAPI.log"
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\installCAPI.log"

# Downloading 'installK3s.log' log file
Write-Header "Downloading K3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/installK3s.log"
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\installK3s.log"

Write-Header "Checking K8s Nodes"
kubectl get nodes

Write-Host "`n"
azdata --version

# Installing the Azure Arc-enabled data services cluster extension
Write-Host "Installing the Azure Arc-enabled data services cluster extension"
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host }}
az k8s-extension create --name arc-data-services `
                        --extension-type microsoft.arcdataservices `
                        --cluster-type connectedClusters `
                        --cluster-name $connectedClusterName `
                        --resource-group $Env:resourceGroup `
                        --auto-upgrade false `
                        --scope cluster `
                        --version 1.21.0 `
                        --release-namespace arc `
                        --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

Write-Host "`n"

Do {
    Write-Host "Waiting for bootstrapper pod, hold tight..."
    Start-Sleep -Seconds 20
    $podStatus = $(if(kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
} while ($podStatus -eq "Nope")
Write-Host "Bootstrapper pod is ready!"
Write-Host "`n"

# Configuring Azure Arc Custom Location on the cluster 
Write-Header "Configuring Azure Arc Custom Location"
$connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $Env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $connectedClusterName --resource-group $Env:resourceGroup --query id -o tsv
Start-Sleep -Seconds 20
az customlocation create --name "$Env:capiArcDataClusterName-cl" --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig "C:\Users\$Env:USERNAME\.kube\config"

# Deploying Azure Arc Data Controller
Write-Header "Deploying Azure Arc Data Controller"

$customLocationId = $(az customlocation show --name "$Env:capiArcDataClusterName-cl" --resource-group $Env:resourceGroup --query id -o tsv)

$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

$dataControllerParams = "$Env:ArcBoxDir\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', "arcbox-dc" | Set-Content -Path $dataControllerParams
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

az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\dataController.json" --parameters "$Env:ArcBoxDir\dataController.parameters.json"
Write-Host "`n"

Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get datacontroller -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
} while ($dcStatus -eq "Nope")
Write-Host "Azure Arc data controller is ready!"
Write-Host "`n"

Write-Header "Deploying SQLMI & PostgreSQL"
# Deploy SQL MI and PostgreSQL data services
& "$Env:ArcBoxDir\DeploySQLMI.ps1"
& "$Env:ArcBoxDir\DeployPostgreSQL.ps1"

# Enable metrics autoUpload
Write-Header "Enabling metrics and logs auto-upload"

$Env:MSI_OBJECT_ID = (az k8s-extension show --resource-group $Env:resourceGroup  --cluster-name $connectedClusterName --cluster-type connectedClusters --name arc-data-services | convertFrom-json).identity.principalId
$Env:WORKSPACE_ID = $workspaceId
$Env:WORKSPACE_SHARED_KEY = $workspaceKey
az role assignment create --assignee $Env:MSI_OBJECT_ID --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
az arcdata dc update --name arcbox-dc --resource-group $Env:resourceGroup --auto-upload-metrics true
az arcdata dc update --name arcbox-dc --resource-group $Env:resourceGroup --auto-upload-logs true

# Replacing Azure Data Studio settings template file
Write-Header "Updating Azure Data Studio Settings"
New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "$Env:ArcBoxDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

# Downloading Rancher K3s kubeconfig file
Write-Header "Downloading Rancher K3s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config-k3s"

# Merging kubeconfig files from CAPI and Rancher K3s
Write-Header "Merging CAPI & K3s Kubeconfigs"
Copy-Item -Path "C:\Users\$Env:USERNAME\.kube\config" -Destination "C:\Users\$Env:USERNAME\.kube\config.backup"
$Env:KUBECONFIG="C:\Users\$Env:USERNAME\.kube\config;C:\Users\$Env:USERNAME\.kube\config-k3s"
kubectl config view --raw > C:\users\$Env:USERNAME\.kube\config_tmp
kubectl config get-clusters --kubeconfig=C:\users\$Env:USERNAME\.kube\config_tmp
Remove-Item -Path "C:\Users\$Env:USERNAME\.kube\config"
Remove-Item -Path "C:\Users\$Env:USERNAME\.kube\config-k3s"
Move-Item -Path "C:\Users\$Env:USERNAME\.kube\config_tmp" -Destination "C:\users\$Env:USERNAME\.kube\config"
$Env:KUBECONFIG="C:\users\$Env:USERNAME\.kube\config"
kubectx
Write-Host "`n"

# Creating desktop url shortcuts for built-in Grafana and Kibana services
Write-Header "Creating Grafana & Kibana Shortcuts"
$GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$GrafanaURL = "https://"+$GrafanaURL+":3000"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Grafana.url")
$Favorite.TargetPath = $GrafanaURL;
$Favorite.Save()

$KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$KibanaURL = "https://"+$KibanaURL+":5601"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Kibana.url")
$Favorite.TargetPath = $KibanaURL;
$Favorite.Save()

Stop-Process -Id $kubectlMonShell.Id

# Changing to Jumpstart ArcBox wallpaper
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

$ArcServersLogonScript = Get-WmiObject win32_process -filter 'name="powershell.exe"' | Select-Object CommandLine | ForEach-Object { $_ | Select-String "ArcServersLogonScript.ps1" }

if(-not $ArcServersLogonScript) {
    Write-Header "Changing Wallpaper"
    $imgPath="$Env:ArcBoxDir\wallpaper.png"
    Add-Type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
if ($null -ne (Get-ScheduledTask -TaskName "DataServicesLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false
}

Start-Sleep -Seconds 5
