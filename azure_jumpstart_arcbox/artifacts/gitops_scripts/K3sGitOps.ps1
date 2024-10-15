$Env:TempDir = "C:\Temp"
$Env:ToolsDir = "C:\Tools"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:k3sArcClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "$namingPrefix-K3s" | Where-Object { $_ -ne "" -and $_ -notmatch "-Data-" }
$Env:k3sArcClusterName=$Env:k3sArcClusterName -replace "`n",""

$namingPrefix = $Env:namingPrefix
$k3sNamespace = "hello-arc"
$ingressNamespace = "ingress-nginx"

$certdns = "arcbox.k3sdevops.com"

$appClonedRepo = "https://github.com/$Env:githubUser/jumpstart-apps"

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
    --branch $Env:githubBranch --sync-interval 3s `
    --kustomization name=nginx path=./arcbox/nginx/release

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
    --branch $env:githubBranch --sync-interval 3s `
    --kustomization name=helloarc path=./arcbox/hello_arc/yaml

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

# Deploy an Ingress Resource for Hello-Arc
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
