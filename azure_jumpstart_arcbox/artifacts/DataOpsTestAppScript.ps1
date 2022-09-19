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
        image: arcjumpstart.azurecr.io/databaseconnectiontest
        volumeMounts:
        - name: secrets
          mountPath: /app/secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: $sqlInstance-login-secret

"@
Write-Header "Deploying DB Connect Test App"
$appCAPI | kubectl apply -n $appNamespace -f -


# Stop transcript
Stop-Transcript