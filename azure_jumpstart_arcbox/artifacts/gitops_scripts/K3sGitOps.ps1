$Env:TempDir = "C:\Temp"
$Env:ToolsDir = "C:\Tools"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:k3sArcClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "ArcBox-K3s" | Where-Object { $_ -ne "" }
$Env:k3sArcClusterName=$Env:k3sArcClusterName -replace "`n",""

$k3sNamespace = "hello-arc"
$ingressNamespace = "ingress-nginx"

# $certname = "k3s-ingress-cert"
$certdns = "arcbox.k3sdevops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

Start-Transcript -Path $Env:ArcBoxLogsDir\K3sGitOps.log

Write-Host "Login to Az CLI using the managed identity"
az login --identity

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

# Switch kubectl context to arcbox-k3s
$Env:KUBECONFIG="C:\Users\$Env:adminUsername\.kube\config-k3s"
kubectx

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for NGINX Ingress Controller
Write-Host "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcClusterName `
    --resource-group $Env:resourceGroup `
    --name config-nginx `
    --namespace $ingressNamespace `
    --cluster-type connectedClusters `
    --scope cluster `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=nginx path=./nginx/release

# Create GitOps config for Hello-Arc application
Write-Host "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcClusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc `
    --namespace $k3sNamespace `
    --cluster-type connectedClusters `
    --scope namespace `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=helloarc path=./hello-arc/yaml

$configs = $(az k8s-configuration flux list --cluster-name $Env:k3sArcClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup --query "[].name" -otsv)

foreach ($configName in $configs) {
    Write-Host "Checking GitOps configuration $configName on $Env:k3sArcClusterName"
    $retryCount = 0
    $maxRetries = 5
    do {
      $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $Env:k3sArcClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup -o json 2>$null) | convertFrom-JSON
      if ($configStatus.ComplianceState -eq "Compliant") {
          Write-Host "GitOps configuration $configName is ready on $Env:k3sArcClusterName"
      }
      else {
          if ($configStatus.ComplianceState -ne "Non-compliant") {
              Start-Sleep -Seconds 60
          }
          elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
              Start-Sleep -Seconds 60
              $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $Env:k3sArcClusterName --cluster-type connectedClusters --resource-group $Env:resourceGroup -o json 2>$null) | convertFrom-JSON
              if ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                  $retryCount++
              }
          }
          elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -eq $maxRetries) {
              Write-Host "GitOps configuration $configName has failed on $Env:k3sArcClusterName. Exiting..."
              break
          }
      }
    } until ($configStatus.ComplianceState -eq "Compliant")
}

# ################################################
# # - Install Key Vault Extension / Create Ingress
# ################################################

# Write-Host "Generating a TLS Certificate"
# $cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
# $certPassword = ConvertTo-SecureString -String "arcbox" -Force -AsPlainText
# Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$certname.pfx" -Password $certPassword
# Import-PfxCertificate -FilePath "$Env:TempDir\$certname.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $certPassword

# Write-Host "Importing the TLS certificate to Key Vault"
# az keyvault certificate import `
#   --vault-name $Env:keyVaultName `
#   --password "arcbox" `
#   --name $certname `
#   --file "$Env:TempDir\$certname.pfx"
 
# Write-Host "Installing Azure Key Vault Kubernetes extension instance"
# az k8s-extension create `
#   --name 'akvsecretsprovider' `
#   --extension-type Microsoft.AzureKeyVaultSecretsProvider `
#   --scope cluster `
#   --cluster-name $Env:k3sArcClusterName `
#   --resource-group $Env:resourceGroup `
#   --cluster-type connectedClusters `
#   --release-namespace kube-system `
#   --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# # Create the Kubernetes secret with the service principal credentials
# kubectl create secret generic secrets-store-creds --namespace $k3sNamespace --from-literal clientid=$Env:spnClientID --from-literal clientsecret=$Env:spnClientSecret
# kubectl --namespace $k3sNamespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

# # Deploy SecretProviderClass
# $secretProvider = @"
# apiVersion: secrets-store.csi.x-k8s.io/v1
# kind: SecretProviderClass
# metadata:
#   name: azure-kv-sync-tls
# spec:
#   provider: azure
#   secretObjects:                       # secretObjects defines the desired state of synced K8s secret objects                                
#   - secretName: ingress-tls-csi
#     type: kubernetes.io/tls
#     data: 
#     - objectName: "$certname"
#       key: tls.key
#     - objectName: "$certname"
#       key: tls.crt
#   parameters:
#     usePodIdentity: "false"
#     keyvaultName: $Env:keyVaultName                        
#     objects: |
#       array:
#         - |
#           objectName: "$certname"
#           objectType: secret
#     tenantId: "$Env:spnTenantId"
# "@

# Write-Host "Creating Secret Provider Class"
# $secretProvider | kubectl apply -n $k3sNamespace -f -

# # Create the pod with volume referencing the secrets-store.csi.k8s.io driver
# $appConsumer = @"
# apiVersion: v1
# kind: Pod
# metadata:
#   name: busybox-secrets-sync
# spec:
#   containers:
#   - name: busybox
#     image: k8s.gcr.io/e2e-test-images/busybox:1.29
#     command:
#       - "/bin/sleep"
#       - "10000"
#     volumeMounts:
#     - name: secrets-store-inline
#       mountPath: "/mnt/secrets-store"
#       readOnly: true
#   volumes:
#     - name: secrets-store-inline
#       csi:
#         driver: secrets-store.csi.k8s.io
#         readOnly: true
#         volumeAttributes:
#           secretProviderClass: "azure-kv-sync-tls"
#         nodePublishSecretRef:
#           name: secrets-store-creds  
# "@

# Write-Host "Deploying App referencing the secret"
# $appConsumer | kubectl apply -n $k3sNamespace -f -

# Deploy an Ingress Resource referencing the Secret created by the CSI driver
$ingressController = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: "$certdns"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: hello-arc
            port:
              number: 8080
"@

Write-Host "Deploying Ingress Resource"
$ingressController | kubectl apply -n $k3sNamespace -f -

$ip = kubectl get service/ingress-nginx-controller --namespace $ingressNamespace --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'

#Insert into HOSTS file
Add-Content -Path $Env:windir\System32\drivers\etc\hosts -Value "`n`t$ip`t$certdns" -Force

# Creating ArcBox K3s Hello-Arc Website URL on Desktop
$shortcutLocation = "$Env:Public\Desktop\K3s Hello-Arc.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "http://$certdns"
$shortcut.IconLocation="$Env:ArcBoxIconDir\arc.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()
