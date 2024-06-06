$Env:TempDir = "C:\Temp"
$Env:ToolsDir = "C:\Tools"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxKVDir = "C:\ArcBox\KeyVault"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"

$osmReleaseVersion = "1.1.1-1"
$osmCLIReleaseVersion = "v1.2.3"
$osmMeshName = "osm"
$ingressNamespace = "ingress-nginx"

# $certname = "ingress-cert"
$certdns = "arcbox.devops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

$clusters = @(
    [pscustomobject]@{clusterName = $Env:k3sArcDataClusterName; context = "arcbox-datasvc-k3s" ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config" }

    [pscustomobject]@{clusterName = $Env:k3sArcClusterName; context = "arcbox-k3s" ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-k3s" }
)

Start-Transcript -Path $Env:ArcBoxLogsDir\DevOpsLogonScript.log

# Required for azcopy and Get-AzResource
Connect-AzAccount -Identity -Tenant $env:spntenantId -Subscription $env:subscriptionId

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".devops" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

$Env:k3sArcDataClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "ArcBox-DataSvc-K3s" | Where-Object { $_ -ne "" }
$Env:k3sArcDataClusterName=$Env:k3sArcDataClusterName -replace "`n",""

$Env:k3sArcClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "ArcBox-K3s" | Where-Object { $_ -ne "" }
$Env:k3sArcClusterName=$Env:k3sArcClusterName -replace "`n",""

# Required for CLI commands
Write-Header "Az CLI Login"
az login --identity
az account set -s $env:subscriptionId

# Downloading ArcBox-DataSvc-K3s Kubernetes cluster kubeconfig file
Write-Header "Downloading ArcBox-DataSvc-K3s K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Container,Object -Permission racwdlup
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading ArcBox-DataSvc-K3s log file
Write-Header "Downloading ArcBox-DataSvc-K3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcDataClusterName.ToLower())/*"
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\" --include-pattern "*.log"

# Downloading ArcBox-K3s cluster kubeconfig file
Write-Header "Downloading ArcBox-K3s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcClusterName.ToLower())/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Container,Object -Permission racwdlup
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config-k3s"
$Env:KUBECONFIG="C:\users\$Env:USERNAME\.kube\config"
kubectx

# Downloading ArcBox-K3s log file
Write-Header "Downloading ArcBox-K3s Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/$($Env:k3sArcClusterName.ToLower())/*"
$sourceFile = $sourceFile + "?" + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\" --include-pattern "*.log"

# # Merging kubeconfig files from ArcBox-DataSvc-K3s and ArcBox-K3s
# Write-Header "Merging ArcBox-DataSvc-K3s & ArcBox-K3s Kubeconfigs"
# Copy-Item -Path "C:\Users\$Env:USERNAME\.kube\config" -Destination "C:\Users\$Env:USERNAME\.kube\config.backup"
# $Env:KUBECONFIG="C:\Users\$Env:USERNAME\.kube\config;C:\Users\$Env:USERNAME\.kube\config-k3s"
# kubectl config view --raw > C:\users\$Env:USERNAME\.kube\config_tmp
# kubectl config get-clusters --kubeconfig=C:\users\$Env:USERNAME\.kube\config_tmp
# Remove-Item -Path "C:\Users\$Env:USERNAME\.kube\config"
# Remove-Item -Path "C:\Users\$Env:USERNAME\.kube\config-k3s"
# Move-Item -Path "C:\Users\$Env:USERNAME\.kube\config_tmp" -Destination "C:\users\$Env:USERNAME\.kube\config"
# $Env:KUBECONFIG="C:\users\$Env:USERNAME\.kube\config"
# kubectx

# Download OSM binaries
Write-Header "Downloading OSM Binaries"
Invoke-WebRequest -Uri "https://github.com/openservicemesh/osm/releases/download/$osmCLIReleaseVersion/osm-$osmCLIReleaseVersion-windows-amd64.zip" -Outfile "$Env:TempDir\osm-$osmCLIReleaseVersion-windows-amd64.zip"
Expand-Archive "$Env:TempDir\osm-$osmCLIReleaseVersion-windows-amd64.zip" -DestinationPath $Env:TempDir
Copy-Item "$Env:TempDir\windows-amd64\osm.exe" -Destination $Env:ToolsDir

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
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml

$nicName = $cluster.clusterName + "-NIC"
$k3sVIP = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $nicName --query "[?primary == ``true``].privateIPAddress" -otsv

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

$serviceIpRange = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $nicName --query "[?primary == ``false``].privateIPAddress" -otsv
$sortedIps = $serviceIpRange | Sort-Object {[System.Version]$_}
$lowestServiceIp = $sortedIps[0]
$highestServiceIp = $sortedIps[-1]

kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
Start-Sleep -Seconds 30

Write-Header "Creating longhorn storage on K3scluster"
kubectl apply -f "$Env:ArcBoxDir\longhorn.yaml" --kubeconfig $cluster.kubeConfig
Start-Sleep -Seconds 30
Write-Host "`n"
}

# # Longhorn setup for RWX-capable storage class
# Write-Header "Creating longhorn storage"
# kubectl apply -f "$Env:ArcBoxDir\longhorn.yaml"
# Start-Sleep -Seconds 30

# "Create OSM Kubernetes extension instance"
Write-Header "Creating OSM K8s Extension Instance"
$Env:KUBECONFIG=$clusters[0].kubeConfig
kubectx
az k8s-extension create `
    --name $osmMeshName `
    --extension-type Microsoft.openservicemesh `
    --scope cluster `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --cluster-type connectedClusters `
    --version $osmReleaseVersion `
    --auto-upgrade-minor-version 'false'


# Create Kubernetes Namespaces
Write-Header "Creating K8s Namespaces"
foreach ($namespace in @('bookstore', 'bookbuyer', 'bookwarehouse', 'hello-arc', 'ingress-nginx')) {
    kubectl create namespace $namespace
}

# Add the bookstore namespaces to the OSM control plane
Write-Header "Adding Bookstore Namespaces to OSM"
osm namespace add bookstore bookbuyer bookwarehouse

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace.
# However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$ingressNamespace" --mesh-name "$osmMeshName" --disable-sidecar-injection

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
    --branch main --sync-interval 3s `
    --kustomization name=nginx path=./nginx/release

# Create GitOps config for Bookstore application
Write-Host "Creating GitOps config for Bookstore application"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-bookstore `
    --cluster-type connectedClusters `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./bookstore/yaml

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
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./bookstore/rbac-sample

# Create GitOps config for Bookstore Traffic Split
Write-Host "Creating GitOps config for Bookstore Traffic Split"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-bookstore-osm `
    --cluster-type connectedClusters `
    --scope namespace `
    --namespace bookstore `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./bookstore/osm-sample

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
    --branch main --sync-interval 3s `
    --kustomization name=helloarc path=./hello-arc/yaml

# ################################################
# # - Install Key Vault Extension / Create Ingress
# ################################################

# Write-Header "Installing KeyVault Extension"

# Write-Host "Generating a TLS Certificate"
# $cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
# $certPassword = ConvertTo-SecureString -String "arcbox" -Force -AsPlainText
# Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$certname.pfx" -Password $certPassword
# Import-PfxCertificate -FilePath "$Env:TempDir\$certname.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $certPassword

# Write-Host "Importing the TLS certificate to Key Vault"
# az keyvault certificate import `
#     --vault-name $Env:keyVaultName `
#     --password "arcbox" `
#     --name $certname `
#     --file "$Env:TempDir\$certname.pfx"

# Write-Host "Installing Azure Key Vault Kubernetes extension instance"
# az k8s-extension create `
#     --name 'akvsecretsprovider' `
#     --extension-type Microsoft.AzureKeyVaultSecretsProvider `
#     --scope cluster `
#     --cluster-name $Env:k3sArcDataClusterName `
#     --resource-group $Env:resourceGroup `
#     --cluster-type connectedClusters `
#     --release-namespace kube-system `
#     --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# # Replace Variable values
Get-ChildItem -Path $Env:ArcBoxKVDir |
    ForEach-Object {
        # (Get-Content -path $_.FullName -Raw) -Replace '\{JS_CERTNAME}', $certname | Set-Content -Path $_.FullName
        # (Get-Content -path $_.FullName -Raw) -Replace '\{JS_KEYVAULTNAME}', $Env:keyVaultName | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_HOST}', $certdns | Set-Content -Path $_.FullName
        # (Get-Content -path $_.FullName -Raw) -Replace '\{JS_TENANTID}', $Env:spnTenantId | Set-Content -Path $_.FullName
    }

Write-Header "Creating Ingress Controller"

# Deploy Ingress resources for Bookstore and Hello-Arc App
foreach ($namespace in @('bookstore', 'bookbuyer', 'hello-arc')) {
    # Create the Kubernetes secret with the service principal credentials
    # kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=$Env:spnClientID --from-literal clientsecret=$Env:spnClientSecret
    # kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

    # Deploy Key Vault resources and Ingress for Book Store and Hello-Arc App
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
$shortcutLocation = "$Env:Public\Desktop\K3s Hello-Arc.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "http://$certdns"
$shortcut.IconLocation="$Env:ArcBoxIconDir\arc.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

# Creating K3s Bookstore Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\K3s Bookstore.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "pwsh.exe"
$shortcut.Arguments =  "-ExecutionPolicy Bypass -File $Env:ArcBoxDir\BookStoreLaunch.ps1"
$shortcut.IconLocation="$Env:ArcBoxIconDir\bookstore.ico, 0"
$shortcut.WindowStyle = 7
$shortcut.Save()

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

if(-not $ArcServersLogonScript) {
    Write-Header "Changing Wallpaper"
    $imgPath="$Env:ArcBoxDir\wallpaper.png"
    Add-Type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
if ($null -ne (Get-ScheduledTask -TaskName "DevOpsLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "DevOpsLogonScript" -Confirm:$false
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
