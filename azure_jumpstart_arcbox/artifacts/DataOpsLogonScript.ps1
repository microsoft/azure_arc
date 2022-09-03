$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$aksConnectedClusterName = "ArcBox-AKS"
$aksDRConnectedClusterName = "ArcBox-AKS-DR"

$clusters = @(

    [pscustomobject]@{clusterName = $Env:capiArcDataClusterName; dataController = 'arcbox-capi-dc'; customLocation = 'arcbox-capi-cl' ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'capi' }

    [pscustomobject]@{clusterName = 'ArcBox-AKS'; dataController = 'arcbox-aks-dc'; customLocation = 'arcbox-aks-cl' ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'aks' }

    [pscustomobject]@{clusterName = 'ArcBox-AKS-DR'; dataController = 'arcbox-aksdr-dc'; customLocation = 'arcbox-aksdr-cl' ; storageClassName = 'managed-premium' ; licenseType = 'DisasterRecovery' ; context = 'aks-dr' }

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
az extension add --name arcdata --system
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
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio 18.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Installing AD RSAT tools
Write-Host "`n"
Write-Host "Installing AD RSAT tools"
get-WindowsFeature | Where-Object {$_.Name -like "RSAT-AD-Tools"} | Install-WindowsFeature
get-WindowsFeature | Where-Object {$_.Name -like "RSAT-DNS-Server"} | Install-WindowsFeature
Write-Host "`n"

################################################
# - Created Nested SQL VM
################################################

Write-Header "Creating Nested SQL VM"

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Host "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq "Ethernet" }
Add-DhcpServerv4Scope -Name "ArcBox" `
    -StartRange 10.10.1.100 `
    -EndRange 10.10.1.200 `
    -SubnetMask 255.255.255.0 `
    -LeaseDuration 1.00:00:00 `
    -State Active

Set-DhcpServerv4OptionValue -ComputerName localhost `
    -DnsDomain $dnsClient.ConnectionSpecificSuffix `
    -DnsServer 168.63.129.16, 10.16.2.100 `
    -Router 10.10.1.1 `
    -Force


Add-DhcpServerInDC -DnsName "arcbox-client.jumpstart.local"
Restart-Service dhcpserver

# Create the NAT network
Write-Host "Creating Internal NAT"
$natName = "InternalNat"
New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24

# Create an internal switch with NAT
Write-Host "Creating Internal vSwitch"
$switchName = 'InternalNATSwitch'
New-VMSwitch -Name $switchName -SwitchType Internal
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*" + $switchName + "*" }

# Create an internal network (gateway first)
Write-Host "Creating Gateway"
New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Enable Enhanced Session Mode on Host
Write-Host "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

Write-Host "Fetching Nested VMs"
$sourceFolder = 'https://jumpstart.blob.core.windows.net/v2images'
$sas = "?sp=rl&st=2022-01-27T01:47:01Z&se=2025-01-27T09:47:01Z&spr=https&sv=2020-08-04&sr=c&sig=NB8g7f4JT3IM%2FL6bUfjFdmnGIqcc8WU015socFtkLYc%3D"
$Env:AZCOPY_BUFFER_GB = 4
Write-Output "Downloading nested VMs VHDX file for SQL. This can take some time, hold tight..."
azcopy cp "$sourceFolder/ArcBox-SQL.vhdx$sas" "$Env:ArcBoxVMDir\ArcBox-SQL.vhdx" --check-length=false --log-level=ERROR


# Create the nested SQL VM
Write-Host "Create Hyper-V VMs"
New-VM -Name ArcBox-SQL -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$Env:ArcBoxVMDir\ArcBox-SQL.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-SQL -Count 2

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Host "Set VM Auto Start/Stop"
Set-VM -Name ArcBox-SQL -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Host "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Host "Starting SQL VM"
Start-VM -Name ArcBox-SQL


Write-Host "Creating VM Credentials"
# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

# Restarting Windows VM Network Adapters
Write-Host "Restarting Network Adapters"
Start-Sleep -Seconds 20
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Start-Sleep -Seconds 5

# Configuring the local SQL VM
Write-Host "Setting local SQL authentication and adding a SQL login"
$localSQLUser = $Env:AZDATA_USERNAME
$localSQLPassword = $Env:AZDATA_PASSWORD
Invoke-Command -VMName ArcBox-SQL -Credential $winCreds -ScriptBlock {
    Install-Module -Name SqlServer -AllowClobber -Force
    $server = "localhost"
    $user = $Using:localSQLUser
    $LoginType = "SqlLogin"
    $pass = ConvertTo-SecureString -String $Using:localSQLPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pass
    Add-SqlLogin -ServerInstance $Server -LoginName $User -LoginType $LoginType -DefaultDatabase AdventureWorksLT2019 -Enable -GrantConnectSql -LoginPSCredential $Credential
    $svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
    $svr.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
    $svr.Alter()
    Restart-Service -Force MSSQLSERVER
    $svrole = $svr.Roles | where { $_.Name -eq 'sysadmin' }
    $svrole.AddMember($user)
}

# Creating Hyper-V Manager desktop shortcut
Write-Host "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force


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

# Update CAPI vnet DNS server
az network vnet update -g $Env:resourceGroup -n "arcbox-capi-data-vnet" --dns-servers 10.16.2.100

#VNet peering with CAPI vnet
$dcVnetId=$(az network vnet show `
  --resource-group $Env:resourceGroup `
  --name "ArcBox-VNet" `
  --query id --out tsv)

$capiVnetId=$(az network vnet show `
  --resource-group $Env:resourceGroup `
  --name "arcbox-capi-data-vnet" `
  --query id --out tsv)

az network vnet peering create --name "dcVnet-CapiVnet" `
  --resource-group $Env:resourceGroup `
  --vnet-name "ArcBox-VNet" `
  --remote-vnet $capiVnetId `
  --allow-vnet-access

az network vnet peering create --name "CapiVnet-dcVnet" `
  --resource-group $Env:resourceGroup `
  --vnet-name "arcbox-capi-data-vnet" `
  --remote-vnet $dcVnetId `
  --allow-vnet-access
#az vm restart --no-wait --ids $(az vm list -g $Env:resourceGroup --query "[?contains(name, 'capi')].id" -o tsv)

Start-Sleep -Seconds 30

Write-Header "Checking K8s Nodes"
kubectl get nodes

Write-Host "`n"
azdata --version

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $aksConnectedClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $aksDRConnectedClusterName --admin

kubectx aks="$aksConnectedClusterName-admin"
kubectx aks-dr="$aksDRConnectedClusterName-admin"
kubectx capi="arcbox-capi"


foreach ($cluster in $clusters) {
    Write-Header "Onboarding cluster as an Azure Arc-enabled Kubernetes cluster"
    Write-Host "`n"
    if ($cluster.context -ne 'capi') {
        kubectx $cluster.context
        Write-Host "`n"
        az connectedk8s connect --name $cluster.clusterName `
            --resource-group $Env:resourceGroup `
            --location $Env:azureLocation `
            --correlation-id "6038cc5b-b814-4d20-bcaa-0f60392416d5"
    
        Start-Sleep -Seconds 10
    
        # Enabling Container Insights cluster extension on primary AKS cluster
        Write-Host "`n"
        Write-Host "Enabling Container Insights cluster extension"
        az k8s-extension create --name "azuremonitor-containers" --cluster-name $cluster.clusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
        Write-Host "`n"
    }
}

################################################
# - Deploying data services on CAPI cluster
################################################
$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } }

foreach ($cluster in $clusters) {

    kubectx $cluster.context
    # Installing the Azure Arc-enabled data services cluster extension on the capi cluster
    Write-Host "Installing the Azure Arc-enabled data services cluster extension"
    az k8s-extension create --name arc-data-services `
        --extension-type microsoft.arcdataservices `
        --cluster-type connectedClusters `
        --cluster-name $cluster.clusterName `
        --resource-group $Env:resourceGroup `
        --auto-upgrade false `
        --scope cluster `
        --release-namespace arc `
        --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

    Write-Host "`n"

    Do {
        Write-Host "Waiting for bootstrapper pod, hold tight..."
        Start-Sleep -Seconds 20
        $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($podStatus -eq "Nope")
    Write-Host "Bootstrapper pod is ready!"
    Write-Host "`n"

    # Configuring Azure Arc Custom Location on the capi cluster 
    Write-Header "Configuring Azure Arc Custom Location"
    $connectedClusterId = az connectedk8s show --name $cluster.clusterName --resource-group $Env:resourceGroup --query id -o tsv
    $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $cluster.clusterName --resource-group $Env:resourceGroup --query id -o tsv
    Start-Sleep -Seconds 20
    az customlocation create --name $cluster.customLocation --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig "C:\Users\$Env:USERNAME\.kube\config"

    # Deploying Azure Arc Data Controller on the capi cluster
    Write-Header "Deploying Azure Arc Data Controller"

    $customLocationId = $(az customlocation show --name $cluster.customLocation --resource-group $Env:resourceGroup --query id -o tsv)
    $workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

    Copy-Item "$Env:ArcBoxDir\dataController.parameters.json" -Destination "$Env:ArcBoxDir\dataController-stage.parameters.json"

    $dataControllerParams = "$Env:ArcBoxDir\dataController-stage.parameters.json"

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

    az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\dataController.json" --parameters "$Env:ArcBoxDir\dataController-stage.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc data controller is ready!"
    Write-Host "`n"
    Remove-Item "$Env:ArcBoxDir\dataController-stage.parameters.json" -Force

}

Write-Header "Deploying SQLMI"
# Deploy SQL MI data services
& "$Env:ArcBoxDir\DeploySQLMIADAuth.ps1"

# Enabling data controller auto metrics & logs upload to log analytics
Write-Header "Enabling Data Controller Metrics & Logs Upload"
$Env:WORKSPACE_ID = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName  --query primarySharedKey -o tsv)
az arcdata dc update --name $capiDcName --resource-group $Env:resourceGroup --auto-upload-logs true
az arcdata dc update --name $capiDcName --resource-group $Env:resourceGroup --auto-upload-metrics true

# Replacing Azure Data Studio settings template file
Write-Header "Updating Azure Data Studio Settings"
New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "$Env:ArcBoxDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"


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
Unregister-ScheduledTask -TaskName "DataOpsLogonScript" -Confirm:$false
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
