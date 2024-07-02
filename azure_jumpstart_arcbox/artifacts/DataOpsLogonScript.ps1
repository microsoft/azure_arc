$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "F:\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"

$clusters = @(
    [pscustomobject]@{clusterName = $Env:k3sArcDataClusterName; dataController = "$Env:k3sArcDataClusterName-dc" ; customLocation = "$Env:k3sArcDataClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'k3s' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-k3s" }

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
Connect-AzAccount -Identity -Tenant $env:spntenantId -Subscription $env:subscriptionId

# Required for CLI commands
Write-Header "Az CLI Login"
az login --identity
az account set -s $env:subscriptionId

$KeyVault = Get-AzKeyVault -ResourceGroupName $Env:resourceGroup
if (-not (Get-SecretVault -Name $KeyVault.VaultName -ErrorAction Ignore)) {
    Register-SecretVault -Name $KeyVault.VaultName -ModuleName Az.KeyVault -VaultParameters @{ AZKVaultName = $KeyVault.VaultName } -DefaultVault
}

# Retrieve Azure Key Vault secrets and store as runtime environment variables
$AZDATA_PASSWORD = Get-Secret -Name 'AZDATAPASSWORD' -AsPlainText

# Register Azure providers. 
# ---- MOVE THESE INTO PRE-REQUISITES DOCUMENT AND REMOVE---
#Write-Header "Registering Providers"
#az provider register --namespace Microsoft.Kubernetes --wait
#az provider register --namespace Microsoft.KubernetesConfiguration --wait
#az provider register --namespace Microsoft.ExtendedLocation --wait
#az provider register --namespace Microsoft.AzureArcData --wait

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

& "azuredatastudio.cmd" $Env:argument1 $Env:argument2
& "azuredatastudio.cmd" $Env:argument1 $Env:argument3
& "azuredatastudio.cmd" $Env:argument1 $Env:argument4

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

# Downloading k3s Kubernetes cluster kubeconfig file
Write-Header "Downloading k3s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:adminUsername\.kube\config-k3s"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:adminUsername\.kube\config"

$addsDomainNetBiosName = $Env:addsDomainName.Split(".")[0]
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:adminUsername.$addsDomainNetBiosName\.kube\config"

# Downloading 'installk3s.log' log file
Write-Header "Downloading k3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/installK3s-$Env:k3sArcDataClusterName.log"
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\installk3s.log"

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
kubectx k3s="arcbox-datasvc-k3s"

Start-Sleep -Seconds 10

Write-Header "Onboarding clusters as an Azure Arc-enabled Kubernetes cluster"
foreach ($cluster in $clusters) {
    if ($cluster.context -ne 'k3s') {
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
    }
}

Stop-Transcript
################################################
# - Deploying data services on k3s cluster
################################################

$kubectlMonShellk3s = Start-Process -PassThru pwsh { $host.ui.RawUI.WindowTitle = 'k3s Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-k3s" ; Start-Sleep -Seconds 5; Clear-Host } }
$kubectlMonShellAKS = Start-Process -PassThru pwsh { $host.ui.RawUI.WindowTitle = 'AKS Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aks" ; Start-Sleep -Seconds 5; Clear-Host } }
$kubectlMonShellAKSDr = Start-Process -PassThru pwsh { $host.ui.RawUI.WindowTitle = 'AKS-DR Cluster'; for (0 -lt 1) { kubectl get pods -n arc --kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aksdr" ; Start-Sleep -Seconds 5; Clear-Host } }

Write-Header "Deploying Azure Arc Data Controller"
$clusters | Foreach-Object -ThrottleLimit 5 -Parallel {
    $cluster = $_
    $context = $cluster.context
    $clusterName = $cluster.clusterName
    $customLocation = $cluster.customLocation
    $dataController = $cluster.dataController

    Start-Transcript -Path "$Env:ArcBoxLogsDir\DataController-$context.log"
    Write-Host "Deploying arc data services on $clusterName"
    Write-Host "`n"
    az k8s-extension create --name arc-data-services `
            --extension-type microsoft.arcdataservices `
            --cluster-type connectedClusters `
            --cluster-name $clusterName `
            --resource-group $Env:resourceGroup `
            --auto-upgrade false `
            --scope cluster `
            --release-namespace arc `
            --version 1.30.0 `
            --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

            Write-Host "`n"

            Do {
                Write-Host "Waiting for bootstrapper pod, hold tight..."
                Start-Sleep -Seconds 20
                $podStatus = $(if (kubectl get pods -n arc --kubeconfig $cluster.kubeConfig | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
            } while ($podStatus -eq "Nope")
            Write-Host "Bootstrapper pod is ready!"

            $connectedClusterId = az connectedk8s show --name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
            $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
            Start-Sleep -Seconds 10
            az customlocation create --name $customLocation --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig $cluster.kubeConfig --only-show-errors

            Start-Sleep -Seconds 20

            # Deploying the Azure Arc Data Controller

            $context = $cluster.context
            $customLocationId = $(az customlocation show --name $customLocation --resource-group $Env:resourceGroup --query id -o tsv)
            $workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
            $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
            Copy-Item "$Env:ArcBoxDir\dataController.parameters.json" -Destination "$Env:ArcBoxDir\dataController-$context-stage.parameters.json"

            $dataControllerParams = "$Env:ArcBoxDir\dataController-$context-stage.parameters.json"

            (Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', $dataController | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
            (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

            Write-Host "Deploying arc data controller on $clusterName"
            Write-Host "`n"
            az deployment group create --resource-group $Env:resourceGroup --name $dataController --template-file "$Env:ArcBoxDir\dataController.json" --parameters $dataControllerParams
            Write-Host "`n"

            Do {
                Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
                Start-Sleep -Seconds 45
                $dcStatus = $(if (kubectl get datacontroller -n arc --kubeconfig $cluster.kubeConfig | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
            } while ($dcStatus -eq "Nope")
            Write-Host "Azure Arc data controller is ready on $clusterName!"
            Write-Host "`n"
            Remove-Item "$Env:ArcBoxDir\dataController-$context-stage.parameters.json" -Force
            Stop-Transcript
        }

Write-Header "Deploying SQLMI"
# Deploy SQL MI data services
& "$Env:ArcBoxDir\DeploySQLMIADAuth.ps1"

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsLogonScript.log -Append

# Enable metrics autoUpload
Write-Header "Enabling metrics and logs auto-upload"
$Env:WORKSPACE_ID = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

foreach($cluster in $clusters){
    $clusterName = $cluster.clusterName
    $dataController = $cluster.dataController
    $Env:MSI_OBJECT_ID = (az k8s-extension show --resource-group $Env:resourceGroup  --cluster-name $clusterName --cluster-type connectedClusters --name arc-data-services | convertFrom-json).identity.principalId
    az role assignment create --assignee $Env:MSI_OBJECT_ID --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
    az arcdata dc update --name $dataController --resource-group $Env:resourceGroup --auto-upload-metrics true
    az arcdata dc update --name $dataController --resource-group $Env:resourceGroup --auto-upload-logs true
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

Stop-Process -Id $kubectlMonShellk3s.Id
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

$ArcServersLogonScript = Get-WmiObject win32_process -filter 'name="pwsh.exe"' | Select-Object CommandLine | ForEach-Object { $_ | Select-String "ArcServersLogonScript.ps1" }

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

Write-Header "Running tests to verify infrastructure"

& "$Env:ArcBoxTestsDir\Invoke-Test.ps1"

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
