$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"

$clusters = @(
    [pscustomobject]@{clusterName = $Env:capiArcDataClusterName; dataController = "$Env:capiArcDataClusterName-dc" ; customLocation = "$Env:capiArcDataClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'capi' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-capi" }

    [pscustomobject]@{clusterName = $Env:aksArcClusterName ; dataController = "$Env:aksArcClusterName-dc" ; customLocation = "$Env:aksArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'aks' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aks" }

    [pscustomobject]@{clusterName = $Env:aksdrArcClusterName ; dataController = "$Env:aksdrArcClusterName-dc" ; customLocation = "$Env:aksdrArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'DisasterRecovery' ; context = 'aks-dr'; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aksdr" }
)

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsLogonScript.log

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".dataops" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Required for azcopy
Write-Header "Az PowerShell Login"
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
az extension add --name connectedk8s --version 1.3.17
az extension add --name arcdata
az -v

# Installing Azure Data Studio extensions
Write-Header "Installing Azure Data Studio extensions"
$Env:argument1 = "--install-extension"
$Env:argument2 = "microsoft.azcli"
$Env:argument3 = "microsoft.azuredatastudio-postgresql"
$Env:argument4 = "Microsoft.arc"

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
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Installing AD RSAT tools
Write-Host "`n"
Write-Host "Installing AD RSAT tools"
get-WindowsFeature | Where-Object { $_.Name -like "RSAT-AD-Tools" } | Install-WindowsFeature
get-WindowsFeature | Where-Object { $_.Name -like "RSAT-DNS-Server" } | Install-WindowsFeature
Write-Host "`n"

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Header "Downloading CAPI K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config-capi"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading 'installCAPI.log' log file
Write-Header "Downloading CAPI Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/installCAPI.log"
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\installCAPI.log"

#VNet peering with CAPI vnet
$capiVnetName = $clusters[0].clusterName + '-vnet'
$dcVnetId = $(az network vnet show `
        --resource-group $Env:resourceGroup `
        --name "ArcBox-VNet" `
        --query id --out tsv)

$capiVnetId = $(az network vnet show `
        --resource-group $Env:resourceGroup `
        --name $capiVnetName `
        --query id --out tsv)

az network vnet peering create --name "dcVnet-CapiVnet" `
    --resource-group $Env:resourceGroup `
    --vnet-name "ArcBox-VNet" `
    --remote-vnet $capiVnetId `
    --allow-vnet-access

az network vnet peering create --name "CapiVnet-dcVnet" `
    --resource-group $Env:resourceGroup `
    --vnet-name $capiVnetName `
    --remote-vnet $dcVnetId `
    --allow-vnet-access

Start-Sleep -Seconds 10

Write-Host "`n"
azdata --version

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksArcClusterName --admin --file "c:\users\$Env:adminUsername\.kube\config-aks"
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksdrArcClusterName --admin --file "c:\users\$Env:adminUsername\.kube\config-aksdr"

az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksArcClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksdrArcClusterName --admin

kubectx aks="$Env:aksArcClusterName-admin"
kubectx aks-dr="$Env:aksdrArcClusterName-admin"
kubectx capi="arcbox-capi"

Start-Sleep -Seconds 10

Write-Header "Onboarding clusters as an Azure Arc-enabled Kubernetes cluster"
foreach ($cluster in $clusters) {
    if ($cluster.context -ne 'capi') {
        Write-Host "Checking K8s Nodes"
        kubectl get nodes --kubeconfig $cluster.kubeConfig
        Write-Host "`n"
        az connectedk8s connect --name $cluster.clusterName `
            --resource-group $Env:resourceGroup `
            --location $Env:azureLocation `
            --correlation-id "6038cc5b-b814-4d20-bcaa-0f60392416d5" `
            --kube-config $cluster.kubeConfig

        Start-Sleep -Seconds 10

        # Enabling Container Insights and Azure Policy cluster extension on Arc-enabled cluster
        Write-Host "`n"
        Write-Host "Enabling Container Insights cluster extension"
        az k8s-extension create --name "azuremonitor-containers" --cluster-name $cluster.clusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
        Write-Host "`n"
        #Write-Host "Enabling Defender for Containers on AKS clusters"
        #az aks update --enable-defender --resource-group $Env:resourceGroup --name $cluster.clusterName
    }
}

Stop-Transcript
################################################
# - Deploying data services on CAPI cluster
################################################

$kubectlMonShellCapi = Start-Process -PassThru PowerShell { $host.ui.RawUI.WindowTitle = 'CAPI Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-capi" ; Start-Sleep -Seconds 5; Clear-Host } }
$kubectlMonShellAKS = Start-Process -PassThru PowerShell { $host.ui.RawUI.WindowTitle = 'AKS Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aks" ; Start-Sleep -Seconds 5; Clear-Host } }
$kubectlMonShellAKSDr = Start-Process -PassThru PowerShell { $host.ui.RawUI.WindowTitle = 'AKS-DR Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aksdr" ; Start-Sleep -Seconds 5; Clear-Host } }

Write-Header "Deploying Azure Arc Data Controller"
foreach ($cluster in $clusters) {
    Start-Job -Name arcbox -ScriptBlock {
        $cluster = $using:cluster
        $context = $cluster.context
        Start-Transcript -Path "$Env:ArcBoxLogsDir\DataController-$context.log"
        
        az k8s-extension create --name arc-data-services `
            --extension-type microsoft.arcdataservices `
            --cluster-type connectedClusters `
            --cluster-name $cluster.clusterName `
            --resource-group $Env:resourceGroup `
            --auto-upgrade false `
            --scope cluster `
            --release-namespace arc `
            --version 1.26.0 `
            --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

        Write-Host "`n"

        Do {
            Write-Host "Waiting for bootstrapper pod, hold tight..."
            Start-Sleep -Seconds 20
            $podStatus = $(if (kubectl get pods -n arc --kubeconfig $cluster.kubeConfig | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
        } while ($podStatus -eq "Nope")
        Write-Host "Bootstrapper pod is ready!"

        $connectedClusterId = az connectedk8s show --name $cluster.clusterName --resource-group $Env:resourceGroup --query id -o tsv
        $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $cluster.clusterName --resource-group $Env:resourceGroup --query id -o tsv
        Start-Sleep -Seconds 10
        az customlocation create --name $cluster.customLocation --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig $cluster.kubeConfig --only-show-errors

        Start-Sleep -Seconds 20

        # Deploying the Azure Arc Data Controller

        $context = $cluster.context
        $customLocationId = $(az customlocation show --name $cluster.customLocation --resource-group $Env:resourceGroup --query id -o tsv)
        $workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
        $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
        Copy-Item "$Env:ArcBoxDir\dataController.parameters.json" -Destination "$Env:ArcBoxDir\dataController-$context-stage.parameters.json"

        $dataControllerParams = "$Env:ArcBoxDir\dataController-$context-stage.parameters.json"

    (Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', $cluster.dataController | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $Env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $Env:spnClientId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $Env:spnTenantId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $Env:spnClientSecret | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

        az deployment group create --resource-group $Env:resourceGroup --name $cluster.dataController --template-file "$Env:ArcBoxDir\dataController.json" --parameters "$Env:ArcBoxDir\dataController-$context-stage.parameters.json"
        Write-Host "`n"

        Do {
            Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
            Start-Sleep -Seconds 45
            $dcStatus = $(if (kubectl get datacontroller -n arc --kubeconfig $cluster.kubeConfig | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
        } while ($dcStatus -eq "Nope")
        Write-Host "Azure Arc data controller is ready!"
        Write-Host "`n"
        Remove-Item "$Env:ArcBoxDir\dataController-$context-stage.parameters.json" -Force

        Stop-Transcript
    }

}

while ($(Get-Job -Name arcbox).State -eq 'Running') {
    Receive-Job -Name arcbox -WarningAction SilentlyContinue
    Start-Sleep -Seconds 5
}

Get-Job -name arcbox | Remove-Job
write-host "Successfully deployed Azure Arc Data Controllers"

Write-Header "Deploying SQLMI"
# Deploy SQL MI data services
& "$Env:ArcBoxDir\DeploySQLMIADAuth.ps1"

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsLogonScript.log -Append

# Enable metrics autoUpload
Write-Header "Enabling metrics and logs auto-upload"
$Env:WORKSPACE_ID = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

foreach($cluster in $clusters){
    $Env:MSI_OBJECT_ID = (az k8s-extension show --resource-group $Env:resourceGroup  --cluster-name $cluster.clusterName --cluster-type connectedClusters --name arc-data-services | convertFrom-json).identity.principalId
    az role assignment create --assignee $Env:MSI_OBJECT_ID --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
    az arcdata dc update --name $cluster.dataController --resource-group $Env:resourceGroup --auto-upload-metrics true
    az arcdata dc update --name $cluster.dataController --resource-group $Env:resourceGroup --auto-upload-logs true
}

Write-Header "Deploying App"
# Deploy App
& "$Env:ArcBoxDir\DataOpsAppScript.ps1"

# Disable Edge 'First Run' Setup
$edgePolicyRegistryPath = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
$desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
$firstRunRegistryName = 'HideFirstRunExperience'
$firstRunRegistryValue = '0x00000001'
$savePasswordRegistryName = 'PasswordManagerEnabled'
$savePasswordRegistryValue = '0x00000000'
$autoArrangeRegistryName = 'FFlags'
$autoArrangeRegistryValue = '1075839525'

If (-NOT (Test-Path -Path $edgePolicyRegistryPath)) {
    New-Item -Path $edgePolicyRegistryPath -Force | Out-Null
}

New-ItemProperty -Path $edgePolicyRegistryPath -Name $firstRunRegistryName -Value $firstRunRegistryValue -PropertyType DWORD -Force
New-ItemProperty -Path $edgePolicyRegistryPath -Name $savePasswordRegistryName -Value $savePasswordRegistryValue -PropertyType DWORD -Force
Set-ItemProperty -Path $desktopSettingsRegistryPath -Name $autoArrangeRegistryName -Value $autoArrangeRegistryValue -Force

# Creating desktop url shortcuts for built-in Grafana and Kibana services
kubectx $clusters[0].context
Write-Header "Creating Grafana & Kibana Shortcuts"
$GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$GrafanaURL = "https://" + $GrafanaURL + ":3000"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Grafana.url")
$Favorite.TargetPath = $GrafanaURL;
$Favorite.Save()

$KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$KibanaURL = "https://" + $KibanaURL + ":5601"
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($Env:USERPROFILE + "\Desktop\Kibana.url")
$Favorite.TargetPath = $KibanaURL;
$Favorite.Save()

Stop-Process -Id $kubectlMonShellCapi.Id
Stop-Process -Id $kubectlMonShellAKS.Id
Stop-Process -Id $kubectlMonShellAKSDr.Id

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

if (-not $ArcServersLogonScript) {
    Write-Header "Changing Wallpaper"
    $imgPath = "$Env:ArcBoxDir\wallpaper.png"
    Add-Type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
if ($null -ne (Get-ScheduledTask -TaskName "DataOpsLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "DataOpsLogonScript" -Confirm:$false
}

Start-Sleep -Seconds 5

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:ArcBoxLogsDir\LogsBundle-"$RandomString".zip $Env:ArcBoxLogsDir\*.log
}'

Stop-Transcript
