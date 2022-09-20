$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

$appNamespace = "arc"
$sqlInstance = "capi"

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsTestAppScript.log

# Switch kubectl context to capi
kubectx $sqlInstance
# Deploy the App and service
$appCAPI = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dbconnecttest-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dbconnecttest
  template:
    metadata:
      labels:
        app: dbconnecttest
    spec:
      containers:
      - name: dbconnecttest
        image: azurearcjumpstart.azurecr.io/databaseconnectiontest
        volumeMounts:
        - name: secrets
          mountPath: /app/secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: $sqlInstance-sql-login-secret

"@
Write-Header "Deploying DB Connect Test App"
$appCAPI | kubectl apply -n $appNamespace -f -

Do {
  Write-Host "Waiting for App pod, hold tight..."
  Start-Sleep -Seconds 5
  $podStatus = $(if(kubectl get pods -n $appNamespace | Select-String "dbconnecttest-app" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
} while ($podStatus -eq "Nope")

# Stop transcript
Stop-Transcript