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

$certname = "ingress-cert"
$certdns = "arcbox.devops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

Start-Transcript -Path $Env:ArcBoxLogsDir\DevOpsLogonScript.log

# Required for azcopy and Get-AzResource
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".devops" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

$Env:capiArcDataClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "CAPI" | Where-Object { $_ -ne "" }
$Env:capiArcDataClusterName=$Env:capiArcDataClusterName -replace "`n",""

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Header "Downloading CAPI K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading Rancher K3s cluster kubeconfig file
Write-Header "Downloading K3s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config-k3s"

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

# Download OSM binaries
Write-Header "Downloading OSM Binaries"
Invoke-WebRequest -Uri "https://github.com/openservicemesh/osm/releases/download/$osmCLIReleaseVersion/osm-$osmCLIReleaseVersion-windows-amd64.zip" -Outfile "$Env:TempDir\osm-$osmCLIReleaseVersion-windows-amd64.zip"
Expand-Archive "$Env:TempDir\osm-$osmCLIReleaseVersion-windows-amd64.zip" -DestinationPath $Env:TempDir
Copy-Item "$Env:TempDir\windows-amd64\osm.exe" -Destination $Env:ToolsDir

Write-Header "Adding Tools Folder to PATH"
[System.Environment]::SetEnvironmentVariable('PATH', $Env:PATH + ";$Env:ToolsDir" ,[System.EnvironmentVariableTarget]::Machine)
$Env:PATH += ";$Env:ToolsDir"

# Create random 13 character string for Key Vault name
$strLen = 13
$randStr = (-join ((0x30..0x39) + (0x61..0x7A) | Get-Random -Count $strLen | ForEach-Object {[char]$_}))
$Env:keyVaultName = "ArcBox-KV-$randStr"

[System.Environment]::SetEnvironmentVariable('keyVaultName', $Env:keyVaultName, [System.EnvironmentVariableTarget]::Machine)

# Create Azure Key Vault
Write-Header "Creating Azure KeyVault"
az keyvault create --name $Env:keyVaultName --resource-group $Env:resourceGroup --location $Env:azureLocation

# Allow SPN to import certificates into Key Vault
Write-Header "Setting KeyVault Access Policies"
az keyvault set-policy --name $Env:keyVaultName --spn $Env:spnClientID --key-permissions --secret-permissions get --certificate-permissions get list import

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

# "Create OSM Kubernetes extension instance"
Write-Header "Creating OSM K8s Extension Instance"
az k8s-extension create `
    --name $osmMeshName `
    --extension-type Microsoft.openservicemesh `
    --scope cluster `
    --cluster-name $Env:capiArcDataClusterName `
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
    --cluster-name $Env:capiArcDataClusterName `
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
    --cluster-name $Env:capiArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-bookstore `
    --cluster-type connectedClusters `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./bookstore/yaml

# Create GitOps config for Bookstore RBAC
Write-Host "Creating GitOps config for Bookstore RBAC"
az k8s-configuration flux create `
    --cluster-name $Env:capiArcDataClusterName `
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
    --cluster-name $Env:capiArcDataClusterName `
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
    --cluster-name $Env:capiArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc `
    --namespace hello-arc `
    --cluster-type connectedClusters `
    --scope namespace `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=helloarc path=./hello-arc/yaml

################################################
# - Install Key Vault Extension / Create Ingress
################################################

Write-Header "Installing KeyVault Extension"

Write-Host "Generating a TLS Certificate"
$cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
$certPassword = ConvertTo-SecureString -String "arcbox" -Force -AsPlainText
Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$certname.pfx" -Password $certPassword
Import-PfxCertificate -FilePath "$Env:TempDir\$certname.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $certPassword

Write-Host "Importing the TLS certificate to Key Vault"
az keyvault certificate import `
    --vault-name $Env:keyVaultName `
    --password "arcbox" `
    --name $certname `
    --file "$Env:TempDir\$certname.pfx"

Write-Host "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create `
    --name 'akvsecretsprovider' `
    --extension-type Microsoft.AzureKeyVaultSecretsProvider `
    --scope cluster `
    --cluster-name $Env:capiArcDataClusterName `
    --resource-group $Env:resourceGroup `
    --cluster-type connectedClusters `
    --release-namespace kube-system `
    --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Replace Variable values
Get-ChildItem -Path $Env:ArcBoxKVDir |
    ForEach-Object {
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_CERTNAME}', $certname | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_KEYVAULTNAME}', $Env:keyVaultName | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_HOST}', $certdns | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_TENANTID}', $Env:spnTenantId | Set-Content -Path $_.FullName
    }

Write-Header "Creating Ingress Controller"

# Deploy Ingress resources for Bookstore and Hello-Arc App
foreach ($namespace in @('bookstore', 'bookbuyer', 'hello-arc')) {
    # Create the Kubernetes secret with the service principal credentials
    kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=$Env:spnClientID --from-literal clientsecret=$Env:spnClientSecret
    kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

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

# Creating CAPI Hello Arc Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\CAPI Hello-Arc.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "https://$certdns"
$shortcut.IconLocation="$Env:ArcBoxIconDir\arc.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

# Creating CAPI Bookstore Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\CAPI Bookstore.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "powershell.exe"
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

$ArcServersLogonScript = Get-WmiObject win32_process -filter 'name="powershell.exe"' | Select-Object CommandLine | ForEach-Object { $_ | Select-String "ArcServersLogonScript.ps1" }

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
