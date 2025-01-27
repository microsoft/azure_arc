$ErrorActionPreference = $env:ErrorActionPreference

$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "F:\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"
$Env:AZCOPY_AUTO_LOGIN_TYPE = "MSI"
$namingPrefix = ($Env:namingPrefix).toLower()
$k3sArcDataClusterName = ($Env:k3sArcDataClusterName).toLower()
$aksArcClusterName = ($Env:aksArcClusterName).toLower()
$aksdrArcClusterName = ($Env:aksdrArcClusterName).toLower()

$clusters = @(
    [pscustomobject]@{clusterName = $Env:k3sArcDataClusterName; dataController = "$k3sArcDataClusterName-dc" ; customLocation = "$k3sArcDataClusterName-cl" ; storageClassName = 'longhorn' ; licenseType = 'LicenseIncluded' ; context = 'k3s' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-k3s-data" }
    [pscustomobject]@{clusterName = $Env:aksArcClusterName ; dataController = "$aksArcClusterName-dc" ; customLocation = "$aksArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'aks' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aks" }
    [pscustomobject]@{clusterName = $Env:aksdrArcClusterName ; dataController = "$aksdrArcClusterName-dc" ; customLocation = "$aksdrArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'DisasterRecovery' ; context = 'aks-dr'; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aksdr" }
)

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsLogonScript.log

# Remove registry keys that are used to automatically logon the user (only used for first-time setup)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$keys = @("AutoAdminLogon", "DefaultUserName", "DefaultPassword")

foreach ($key in $keys) {
    try {
        $property = Get-ItemProperty -Path $registryPath -Name $key -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath -Name $key
        Write-Host "Removed registry key that are used to automatically logon the user: $key"
    } catch {
        Write-Verbose "Key $key does not exist."
    }
}

# Create desktop shortcut for Logs-folder
$WshShell = New-Object -comObject WScript.Shell
$LogsPath = "C:\ArcBox\Logs"
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

# Configure Windows Terminal as the default terminal application
$registryPath = "HKCU:\Console\%%Startup"

if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
} else {
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
}

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".dataops" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Required for azcopy
Write-Header "Az PowerShell Login"
Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId

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
$Env:AZDATA_PASSWORD = $AZDATA_PASSWORD

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
az extension add --name connectedk8s --version 1.9.3
az extension add --name arcdata
az extension add --name k8s-extension
az extension add --name customlocation
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
$TargetFile = "C:\Users\$Env:adminUsername\AppData\Local\Programs\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut
Write-Host "`n"
Write-Host "Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\ssms.exe"
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
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/config"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile "C:\Users\$Env:adminUsername\.kube\config-k3s-data"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile "C:\Users\$Env:adminUsername\.kube\config"

$addsDomainNetBiosName = $Env:addsDomainName.Split(".")[0]
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:adminUsername.$addsDomainNetBiosName\.kube\config"

# Downloading 'installk3s.log' log file
Write-Header "Downloading k3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/*"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\" --include-pattern "*.log"

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
kubectx k3s="$namingPrefix-k3s-data"

Start-Sleep -Seconds 10

# Get Log Analytics workspace details
$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
$workspaceResourceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query id -o tsv)

Write-Header "Onboarding clusters as an Azure Arc-enabled Kubernetes cluster"
foreach ($cluster in $clusters) {
    if ($cluster.context -ne 'k3s') {
        Write-Host "Checking K8s Nodes"
        kubectl get nodes --kubeconfig $cluster.kubeConfig
        Write-Host "`n"
        Write-Host "Connecting $($cluster.clusterName) cluster to Azure Arc"

        # Try until the provision status is successful.
        Write-Host "Attempting to connect $($cluster.clusterName) cluster to Azure Arc."
        try {
            az connectedk8s connect --name $cluster.clusterName `
                --resource-group $Env:resourceGroup `
                --location $Env:azureLocation `
                --correlation-id "6038cc5b-b814-4d20-bcaa-0f60392416d5" `
                --kube-config $cluster.kubeConfig
        }
        catch {
            <#Do this if a terminating exception happens#>
            Write-Host "Connecting $($cluster.clusterName) cluster to Azure Arc failed. Exiting deployment. Please check logs and retry again later!"
            Exit
        }

        # Wait for some time to make sure all the pods are deployed and provisioning is completed.
        $retryCount = 0
        do {
            Start-Sleep -Seconds 20

            # Check connected cluster status and make sure provisioning stutus is successful
            $clusterStatus = (az connectedk8s show --name $cluster.clusterName --resource-group $Env:resourceGroup --query provisioningState -o tsv)
            $retryCount += 1
        } while ($clusterStatus -ne "Succeeded" -and $retryCount -lt 3)

        if ($clusterStatus -ne "Succeeded") {
            Write-Host "Connecting $($cluster.clusterName) cluster to Azure Arc failed. Exiting deployment. Please check logs and retry again later!"
            Exit
        }

        # Enabling Container Insights and Azure Policy cluster extension on Arc-enabled cluster
        Write-Host "`n"
        Write-Host "Enabling Container Insights cluster extension"
        az k8s-extension create --name "azuremonitor-containers" --cluster-name $cluster.clusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId --no-wait
        Write-Host "`n"
    }
}

foreach ($cluster in $clusters) {

    if ($cluster.context -eq 'k3s') {
    Write-Header "Configuring kube-vip on K3s cluster"
    kubectx k3s
    $k3sVIP = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $Env:k3sArcDataClusterName-NIC --query "[?primary == ``true``].privateIPAddress" -otsv

Write-Host "Assignin kube-vip-role on k3s cluster"
$kubeVipRBAC = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-vip
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  name: system:kube-vip-role
rules:
  - apiGroups: [""]
    resources: ["services/status"]
    verbs: ["update"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["list","get","watch", "update"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["list","get","watch", "update", "patch"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["list", "get", "watch", "update", "create"]
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["list","get","watch", "update"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system:kube-vip-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-vip-role
subjects:
- kind: ServiceAccount
  name: kube-vip
  namespace: kube-system
"@

$kubeVipRBAC | kubectl apply -f -

$kubeVipDaemonset = @"
apiVersion: apps/v1
kind: DaemonSet
metadata:
  creationTimestamp: null
  labels:
    app.kubernetes.io/name: kube-vip-ds
    app.kubernetes.io/version: v0.7.0
  name: kube-vip-ds
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-vip-ds
  template:
    metadata:
      creationTimestamp: null
      labels:
        app.kubernetes.io/name: kube-vip-ds
        app.kubernetes.io/version: v0.7.0
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: Exists
            - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
      containers:
      - args:
        - manager
        env:
        - name: vip_arp
          value: "true"
        - name: port
          value: "6443"
        - name: vip_interface
          value: eth0
        - name: vip_cidr
          value: "32"
        - name: dns_mode
          value: first
        - name: cp_enable
          value: "true"
        - name: cp_namespace
          value: kube-system
        - name: svc_enable
          value: "true"
        - name: svc_leasename
          value: plndr-svcs-lock
        - name: vip_leaderelection
          value: "true"
        - name: vip_leasename
          value: plndr-cp-lock
        - name: vip_leaseduration
          value: "5"
        - name: vip_renewdeadline
          value: "3"
        - name: vip_retryperiod
          value: "1"
        - name: address
          value: "$k3sVIP"
        - name: prometheus_server
          value: :2112
        image: ghcr.io/kube-vip/kube-vip:v0.7.0
        imagePullPolicy: Always
        name: kube-vip
        resources: {}
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
      hostNetwork: true
      serviceAccountName: kube-vip
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
  updateStrategy: {}
status:
  currentNumberScheduled: 0
  desiredNumberScheduled: 0
  numberMisscheduled: 0
  numberReady: 0
"@

    $kubeVipDaemonset | kubectl apply -f -

    Write-Host "Deploying Kube vip cloud controller on k3s cluster"
    kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

    $serviceIpRange = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $Env:k3sArcDataClusterName-NIC --query "[?primary == ``false``].privateIPAddress" -otsv
    $sortedIps = $serviceIpRange | Sort-Object {[System.Version]$_}
    $lowestServiceIp = $sortedIps[0]
    $highestServiceIp = $sortedIps[-1]

    kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
    Start-Sleep -Seconds 30

    Write-Host "Creating longhorn storage on K3scluster"
    kubectl apply -f "$Env:ArcBoxDir\longhorn.yaml" --kubeconfig $cluster.kubeConfig
    Start-Sleep -Seconds 30
    Write-Host "`n"
    }
}

Stop-Transcript
################################################
# - Deploying data services on k3s cluster
################################################

wt --% --maximized new-tab pwsh.exe -NoExit -Command Show-K8sPodStatus -kubeconfig "C:\Users\$Env:adminUsername\.kube\config-k3s-data" -clusterName 'k3s Cluster'; split-pane -p "PowerShell" pwsh.exe -NoExit -Command Show-K8sPodStatus -kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aks" -clusterName 'AKS Cluster'; split-pane -H pwsh.exe -NoExit -Command Show-K8sPodStatus -kubeconfig "C:\Users\$Env:USERNAME\.kube\config-aksdr" -clusterName 'AKS-DR Cluster'

Write-Header "Deploying Azure Arc Data Controllers on Kubernetes cluster"
$clusters | Foreach-Object {
    $cluster = $_
    $context = $cluster.context
    $clusterName = $cluster.clusterName
    $customLocation = $cluster.customLocation
    $dataController = $cluster.dataController

    Start-Transcript -Path "$Env:ArcBoxLogsDir\DataController-$context.log"
    Write-Host "Deploying arc data services extension on $clusterName"
    Write-Host "`n"
    az k8s-extension create --name arc-data-services `
            --extension-type microsoft.arcdataservices `
            --cluster-type connectedClusters `
            --cluster-name $clusterName `
            --resource-group $Env:resourceGroup `
            --auto-upgrade false `
            --scope cluster `
            --release-namespace arc `
            --version 1.34.0 `
            --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

            Write-Host "`n"

            Do {
                Write-Host "Waiting for bootstrapper pod, hold tight..."
                Start-Sleep -Seconds 20
                $podStatus = $(if (kubectl get pods -n arc --kubeconfig $cluster.kubeConfig | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
            } while ($podStatus -eq "Nope")
            Write-Host "Bootstrapper pod is ready!"

            # Get workspace information again as this code is executed in a different process
            $workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
            $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

            $connectedClusterId = az connectedk8s show --name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
            $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
            Start-Sleep -Seconds 30

            Write-Host "Creating custom location on $clusterName"

            if ($context -ne 'k3s') {

              az connectedk8s enable-features -n $clusterName -g $Env:resourceGroup --kube-context $cluster.context --custom-locations-oid $Env:customLocationRPOID --features cluster-connect custom-locations --only-show-errors

            } else {

              az connectedk8s enable-features -n $clusterName -g $Env:resourceGroup --custom-locations-oid $Env:customLocationRPOID --features cluster-connect custom-locations --only-show-errors

            }

            Start-Sleep -Seconds 30

            try {
                az customlocation create --name $customLocation --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --only-show-errors
            } catch {
                Write-Host "Error creating custom location: $_" -ForegroundColor Red
                Exit 1
            }

            Start-Sleep -Seconds 30

            # Deploying the Azure Arc Data Controller
            $context = $cluster.context
            $customLocationId = $(az customlocation show --name $customLocation --resource-group $Env:resourceGroup --query id -o tsv)
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
            (Get-Content -Path $dataControllerParams) -replace 'storageClass-stage', $cluster.storageClassName | Set-Content -Path $dataControllerParams

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
    az role assignment create --assignee-object-id $Env:MSI_OBJECT_ID --assignee-principal-type ServicePrincipal --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
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

# Changing to Jumpstart ArcBox wallpaper

  Write-Header "Changing wallpaper"

  # bmp file is required for BGInfo
  Convert-JSImageToBitMap -SourceFilePath "$Env:ArcBoxDir\wallpaper.png" -DestinationFilePath "$Env:ArcBoxDir\wallpaper.bmp"

  Set-JSDesktopBackground -ImagePath "$Env:ArcBoxDir\wallpaper.bmp"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
if ($null -ne (Get-ScheduledTask -TaskName "DataOpsLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "DataOpsLogonScript" -Confirm:$false
}

Start-Sleep -Seconds 5

Write-Header "Running tests to verify infrastructure"

& "$Env:ArcBoxTestsDir\Invoke-Test.ps1"