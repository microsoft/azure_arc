$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"

$CName = "jumpstartbooks"
$certdns = "$CName.jumpstart.local"
$password = "arcbox"
$appNamespace = "arc"
$sqlInstance = "capi"

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsAppScript.log

Write-Host "Generating a TLS Certificate"
$cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
$certPassword = ConvertTo-SecureString -String $password -Force -AsPlainText
Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$CName.pfx" -Password $certPassword
Import-PfxCertificate -FilePath "$Env:TempDir\$CName.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $certPassword

# Add OpenSSL to path environment variable
$openSSL = "C:\Program Files\FireDaemon OpenSSL 3\bin"
$currentPathVariable = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
$newPathVariable = $currentPathVariable + ";" + $openSSL
[Environment]::SetEnvironmentVariable("PATH", $newPathVariable, [EnvironmentVariableTarget]::Machine)


openssl pkcs12 -in "$Env:TempDir\$CName.pfx" -nocerts -out "$Env:TempDir\$CName.key" -password pass:$password -passout pass:$password
openssl pkcs12 -in "$Env:TempDir\$CName.pfx" -clcerts -nokeys -out "$Env:TempDir\$CName.crt" -password pass:$password 
openssl rsa -in "$Env:TempDir\$CName.key" -out "$Env:TempDir\$CName-dec.key" -passin pass:$password

Write-Header "Creating Ingress Controller"
foreach ($cluster in @('capi', 'aks-dr')) {
    # Create K8s Ingress TLS secret
    kubectx $cluster
    kubectl -n $appNamespace create secret tls "$CName-secret" --key "$Env:TempDir\$CName-dec.key" --cert "$Env:TempDir\$CName.crt"

    # Deploy NGINX Ingress Controller
    helm repo add nginx-stable https://helm.nginx.com/stable
    helm repo update
    helm install dataops-ingress nginx-stable/nginx-ingress
}

# Switch kubectl context to capi
kubectx $sqlInstance

Write-Header "Adding CName Record for App"
$dcInfo = Get-ADDomainController
Do
{
	$appIpaddress= kubectl get svc "dataops-ingress-nginx-ingress-controller" -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
   Start-Sleep -Seconds 5
} while ($appIpaddress -eq $null)
Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name "$CName-$sqlInstance" -AllowUpdateAny -IPv4Address $appIpaddress -TimeToLive 01:00:00 -AgeRecord
Add-DnsServerResourceRecordCName -Name $CName -ComputerName $dcInfo.HostName -HostNameAlias "$CName-$sqlInstance.jumpstart.local" -ZoneName jumpstart.local -TimeToLive 00:05:00

# Deploy the App and service
$appCAPI = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: azurearcjumpstart.azurecr.io/demoapp
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secrets
          mountPath: /app/secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: $sqlInstance-sql-login-secret
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web
  type: ClusterIP
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80

"@
Write-Header "Deploying App Resource"
$appCAPI | kubectl apply -n $appNamespace -f -

# Deploy an Ingress Resource for the app
$appIngress = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - "$certdns"
    secretName: "$CName-secret"
  rules:
  - host: "$certdns"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: web-app-service
            port:
              number: 80
        path: /
"@
Write-Header "Deploying App Ingress Resource"
$appIngress | kubectl apply -n $appNamespace -f -

Do {
  Write-Host "Waiting for Web App pod, hold tight..."
  Start-Sleep -Seconds 260
  $podStatus = $(if(kubectl get pods -n $appNamespace | Select-String "web-app" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
} while ($podStatus -eq "Nope")

# Creating CAPI Bookstore Arc Icon on Desktop
$shortcutLocation = "$Env:Public\Desktop\Bookstore.lnk"
$wScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
$shortcut.TargetPath = "https://$certdns"
$shortcut.IconLocation="$Env:ArcBoxIconDir\bookstore.ico, 0"
$shortcut.WindowStyle = 3
$shortcut.Save()

# Stop transcript
Stop-Transcript
