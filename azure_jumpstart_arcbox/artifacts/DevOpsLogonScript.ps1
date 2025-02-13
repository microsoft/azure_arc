$ErrorActionPreference = $env:ErrorActionPreference

$Env:TempDir = "C:\Temp"
$Env:ToolsDir = "C:\Tools"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxKVDir = "C:\ArcBox\KeyVault"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"
$namingPrefix = ($Env:namingPrefix).toLower()

$ingressNamespace = "ingress-nginx"
$Env:AZCOPY_AUTO_LOGIN_TYPE = "MSI"

$certdns = "arcbox.devops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/jumpstart-apps"

$clusters = @(
    [pscustomobject]@{clusterName = $Env:k3sArcDataClusterName; context = "$namingPrefix-k3s-data" ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config" }

    [pscustomobject]@{clusterName = $Env:k3sArcClusterName; context = "$namingPrefix-k3s" ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-k3s" }
)

Start-Transcript -Path $Env:ArcBoxLogsDir\DevOpsLogonScript.log

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

# Required for azcopy and Get-AzResource
Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".devops" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az login --identity
az account set -s $env:subscriptionId

# Downloading ArcBox-K3s-data Kubernetes cluster kubeconfig file
Write-Header "Downloading $namingPrefix-K3s-data K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/config"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading ArcBox-K3s-data log file
Write-Header "Downloading $namingPrefix-K3s-data Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/*"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\" --include-pattern "*.log"

# Downloading ArcBox-K3s cluster kubeconfig file
Write-Header "Downloading $namingPrefix-K3s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcClusterName.ToLower())/config"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config-k3s"
$Env:KUBECONFIG="C:\users\$Env:USERNAME\.kube\config"

# Downloading ArcBox-K3s log file
Write-Header "Downloading $namingPrefix-K3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcClusterName.ToLower())/*"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\" --include-pattern "*.log"

Write-Header "Adding Tools Folder to PATH"
[System.Environment]::SetEnvironmentVariable('PATH', $Env:PATH + ";$Env:ToolsDir" ,[System.EnvironmentVariableTarget]::Machine)
$Env:PATH += ";$Env:ToolsDir"

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

foreach ($cluster in $clusters) {

  Write-Header "Configuring kube-vip on K3s cluster"
  $Env:KUBECONFIG=$cluster.kubeConfig
  kubectx

  $nicName = $cluster.clusterName + "-NIC"
  $k3sVIP = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $nicName --query "[?primary == ``true``].privateIPAddress" -otsv

  Write-Header "Installing istio on K3s cluster"
  istioctl install --skip-confirmation

# Apply kube-vip RBAC manifests https://kube-vip.io/manifests/rbac.yaml
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

# Apply kube-vip DaemonSet
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

  # Kube vip cloud controller
  kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

  # Set kube-vip range-global for kubernetes services
  $serviceIpRange = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $nicName --query "[?primary == ``false``].privateIPAddress" -otsv
  $sortedIps = $serviceIpRange | Sort-Object {[System.Version]$_}
  $lowestServiceIp = $sortedIps[0]
  $highestServiceIp = $sortedIps[-1]

  kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
  Start-Sleep -Seconds 30

  Write-Header "Creating longhorn storage on $($cluster.clusterName)"
  kubectl apply -f "$Env:ArcBoxDir\longhorn.yaml" --kubeconfig $cluster.kubeConfig
  Start-Sleep -Seconds 30
  Write-Host "`n"
}

# Switch Kubernetes context to ArcBox-K3s-data cluster
foreach ($cluster in $clusters) {
  if ($cluster.context -like '*-k3s-data') {
    $Env:KUBECONFIG=$cluster.kubeConfig
    kubectx
  }
}

# Create Kubernetes Namespaces
Write-Header "Creating K8s Namespaces"
foreach ($namespace in @('bookstore', 'bookbuyer', 'bookwarehouse', 'hello-arc', 'ingress-nginx')) {
    kubectl create namespace $namespace
}

# Label Bookstore Namespaces for Istio injection
Write-Header "Labeling K8s Namespaces for Istio Injection"
foreach ($namespace in @('bookstore', 'bookbuyer', 'bookwarehouse')) {
    kubectl label namespace $namespace istio-injection=enabled
}

#############################
# - Apply GitOps Configs
#############################

Write-Header "Applying GitOps Configs"

# Create GitOps config for NGINX Ingress Controller
Write-Host "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-nginx `
    --namespace $ingressNamespace `
    --cluster-type connectedClusters `
    --scope cluster `
    --url $appClonedRepo `
    --branch $env:githubBranch --sync-interval 3s `
    --kustomization name=nginx path=./arcbox/nginx/release

# Create GitOps config for Bookstore application
Write-Host "Creating GitOps config for Bookstore application"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-bookstore `
    --cluster-type connectedClusters `
    --url $appClonedRepo `
    --branch $env:githubBranch --sync-interval 3s `
    --kustomization name=bookstore path=./arcbox/bookstore/yaml

# Create GitOps config for Bookstore RBAC
Write-Host "Creating GitOps config for Bookstore RBAC"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-bookstore-rbac `
    --cluster-type connectedClusters `
    --scope namespace `
    --namespace bookstore `
    --url $appClonedRepo `
    --branch $env:githubBranch --sync-interval 3s `
    --kustomization name=bookstore path=./arcbox/bookstore/rbac-sample

# Create GitOps config for Hello-Arc application
Write-Host "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc `
    --namespace hello-arc `
    --cluster-type connectedClusters `
    --scope namespace `
    --url $appClonedRepo `
    --branch $env:githubBranch --sync-interval 3s `
    --kustomization name=helloarc path=./arcbox/hello_arc/yaml

$configs = $(az k8s-configuration flux list --cluster-name $Env:k3sArcDataClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup --query "[].name" -otsv)

foreach ($configName in $configs) {
    Write-Host "Checking GitOps configuration $configName on $Env:k3sArcDataClusterName"
    $retryCount = 0
    $maxRetries = 5
    do {
      $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $Env:k3sArcDataClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup -o json 2>$null) | convertFrom-JSON
      if ($configStatus.ComplianceState -eq "Compliant") {
          Write-Host "GitOps configuration $configName is ready on $Env:k3sArcDataClusterName"
      }
      else {
          if ($configStatus.ComplianceState -ne "Non-compliant") {
              Start-Sleep -Seconds 60
          }
          elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
              Start-Sleep -Seconds 60
              $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $Env:k3sArcDataClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup -o json 2>$null) | convertFrom-JSON
              if ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                  $retryCount++
              }
          }
          elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -eq $maxRetries) {
              Write-Host "GitOps configuration $configName has failed on $Env:k3sArcDataClusterName. Exiting..." -ForegroundColor Red
              break
          }
      }
    } until ($configStatus.ComplianceState -eq "Compliant")
}
# ################################################
# Create Ingress
# ################################################

# Replace Variable values
Get-ChildItem -Path $Env:ArcBoxKVDir |
    ForEach-Object {
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_HOST}', $certdns | Set-Content -Path $_.FullName
    }

Write-Header "Creating Ingress Controller"

# Deploy Ingress resources for Bookstore and Hello-Arc App
foreach ($namespace in @('bookstore', 'bookbuyer', 'hello-arc')) {
    # Deploy Ingress for Book Store and Hello-Arc App
    kubectl --namespace $namespace apply -f "$Env:ArcBoxKVDir\$namespace.yaml"
}

$ip = kubectl get service/ingress-nginx-controller --namespace $ingressNamespace --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'

#Insert into HOSTS file
Add-Content -Path $Env:windir\System32\drivers\etc\hosts -Value "`n`t$ip`t$certdns" -Force

Write-Header "Configuring Edge Policies"

# Disable Edge 'First Run' Setup
$edgePolicyRegistryPath  = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
$desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
$firstRunRegistryName  = 'HideFirstRunExperience'
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

# Tab Auto-Refresh Extension
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist -Name 1 -Value odiofbnciojkpogljollobmhplkhmofe -Force

Write-Header "Creating Desktop Icons"

# Creating K3s Hello Arc Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\Hello-Arc.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "http://$certdns"
$shortcut.IconLocation="$Env:ArcBoxIconDir\arc.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

# Creating K3s Bookstore Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\Bookstore.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "pwsh.exe"
$shortcut.Arguments =  "-ExecutionPolicy Bypass -File $Env:ArcBoxDir\BookStoreLaunch.ps1"
$shortcut.IconLocation="$Env:ArcBoxIconDir\bookstore.ico, 0"
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Header "Changing wallpaper"

# bmp file is required for BGInfo
Convert-JSImageToBitMap -SourceFilePath "$Env:ArcBoxDir\wallpaper.png" -DestinationFilePath "$Env:ArcBoxDir\wallpaper.bmp"

Set-JSDesktopBackground -ImagePath "$Env:ArcBoxDir\wallpaper.bmp"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
if ($null -ne (Get-ScheduledTask -TaskName "DevOpsLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "DevOpsLogonScript" -Confirm:$false
}

Start-Sleep -Seconds 5

Write-Header "Running tests to verify infrastructure"

& "$Env:ArcBoxTestsDir\Invoke-Test.ps1"