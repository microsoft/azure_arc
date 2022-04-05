$Env:TempDir = "C:\Temp"
$Env:ToolsDir = "C:\Tools"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxKVDir = "C:\ArcBox\KeyVault"

$osmRelease = "v1.0.0"
$osmMeshName = "osm"
$ingressNamespace = "ingress-nginx"

$certname = "ingress-cert"
$certdns = "arcbox.devops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

Start-Transcript -Path $Env:ArcBoxLogsDir\DevOpsLogonScript.log

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".devops" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Register Azure providers
#az provider register --namespace Microsoft.HybridCompute --wait
#az provider register --namespace Microsoft.GuestConfiguration --wait
#az provider register --namespace Microsoft.AzureArcData --wait

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Host "Downloading CAPI Kubernetes cluster kubeconfig file"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# "Download OSM binaries"
Invoke-WebRequest -Uri "https://github.com/openservicemesh/osm/releases/download/$osmRelease/osm-$osmRelease-windows-amd64.zip" -Outfile "$Env:TempDir\osm-$osmRelease-windows-amd64.zip"
Expand-Archive "$Env:TempDir\osm-$osmRelease-windows-amd64.zip" -DestinationPath $Env:TempDir
Copy-Item "$Env:TempDir\windows-amd64\osm.exe" -Destination $Env:ToolsDir

[System.Environment]::SetEnvironmentVariable('PATH', $Env:PATH + ";$Env:ToolsDir" ,[System.EnvironmentVariableTarget]::Machine)
$Env:PATH += ";$Env:ToolsDir"

# Allow SPN to import certificates into KeyVault
az keyvault set-policy --name $Env:keyVaultName --spn $Env:spnClientID --secret-permissions get --certificate-permissions get list import

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt 2>null
Write-Host "`n"
az -v

az extension add --name k8s-extension
az extension add --name k8s-configuration

# "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $Env:capiArcDataClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $osmMeshName

# Create Kubernetes Namespaces
foreach ($namespace in @('bookstore', 'bookbuyer', 'bookwarehouse', 'hello-arc', 'ingress-nginx')) {
    kubectl create namespace $namespace
}

# Add the bookstore namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookwarehouse

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. 
# However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$ingressNamespace" --mesh-name "$osmMeshName" --disable-sidecar-injection

#############################
# - Apply GitOps Configs
#############################

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

Write-Host "Generating a TLS Certificate"
$cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
$certPassword = ConvertTo-SecureString -String "arcbox" -Force -AsPlainText
Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$certname.pfx" -Password $certPassword
Import-PfxCertificate -FilePath "$Env:TempDir\$certname.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $certPassword

Write-Host "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $Env:keyVaultName --password "arcbox" -n $certname -f "$Env:TempDir\$certname.pfx"

Write-Host "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name 'akvsecretsprovider' --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $Env:capiArcDataClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Replace Variable values
Get-ChildItem -Path $Env:ArcBoxKVDir |
    ForEach-Object {
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_CERTNAME}', $certname | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_KEYVAULTNAME}', $Env:keyVaultName | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_HOST}', $certdns | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_TENANTID}', $Env:spnTenantId | Set-Content -Path $_.FullName
    }


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

# Creating ArcBox DevOps Website URL on Desktop
$shortcutLocation = "$Env:Public\Desktop\DevOps Bookstore.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "https://arcbox.devops.com"
$shortcut.IconLocation="C:\windows\System32\SHELL32.dll, 17"
$shortcut.WindowStyle = 3
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
    $imgPath="$Env:ArcBoxDir\wallpaper.png"
    Add-Type $code 
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "DevOpsLogonScript" -Confirm:$false
Start-Sleep -Seconds 5
