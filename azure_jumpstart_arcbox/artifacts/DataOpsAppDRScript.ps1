$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

$CName = "dataops"
$certdns = "$CName.jumpstart.local"
$appNamespace = "arc"
$sqlInstance = "aks-dr"

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsAppDRScript.log

# Switch kubectl context to AKS DR
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
$appK3s = @"
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
        image: azurearcjumpstart.azurecr.io/demoapp:dr
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secrets
          mountPath: /app/secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: "$sqlInstance-sql-login-secret"
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
$appK3s | kubectl apply -n $appNamespace -f -

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

# Stop transcript
Stop-Transcript