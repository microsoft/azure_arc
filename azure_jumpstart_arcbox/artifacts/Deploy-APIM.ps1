$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'
# Set paths
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup

if ($host.Name -match 'ISE') {throw "Running this script in PowerShell ISE is not supported"}

try {
    Start-Transcript -Path $Env:ArcBoxLogsDir\Deploy-APIM.log
}
catch {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-APIM.log
}

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt

################################################
# Retrive SQL Managed Instances
################################################
kubectx arcbox-capi
kubectl get nodes

# Retrieving SQL MI connection endpoints
Write-Host "`n"
Write-Host " Retrieving SQL MI connection endpoints"
Write-Host "`n"
$primaryEndpoint = kubectl get sqlmanagedinstances jumpstart-sql -n arc -o=jsonpath='{.status.endpoints.primary}'
$primaryEndpoint = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(',')) + ",11433" 
$sqlConnectionString = "Data Source=$($primaryEndpoint);Initial Catalog=AdventureWorks2019;User ID=$($Env:AZDATA_USERNAME);Password=$($Env:AZDATA_PASSWORD);Encrypt=False;TrustServerCertificate=True"
$base64ConnectionString = [Convert]::ToBase64String([char[]]$sqlConnectionString)

################################################
# Deploy AdventureWorks API
################################################
#Switch kubectl context
Write-Host "`n"
Write-Host "Switch kubectl context to k3s"
Write-Host "`n"

kubectx arcbox-k3s
kubectl get nodes

# Build the AdventureWorks API manifest
Write-Host "`n"
Write-Host " Build the AdventureWorks API manifest"
Write-Host "`n"

kubectl delete secret adventurework-secrets
$secretManifest = @"
apiVersion: v1
kind: Secret
metadata:
  name: adventurework-secrets
type: Opaque
data:
  AdventureWorkConnection: $($base64ConnectionString)
"@
$secretManifest | kubectl apply -f -


#Deploy AdvanetureWork API
Write-Host "`n"
Write-Host "Deploy AdvanetureWorks API"
Write-Host "`n"

$adventureWorkManifest = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adventurework-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: adventurework
  template:
    metadata:
      labels:
        app: adventurework
    spec:
      containers:
      - name: adventurework
        image: jumpstartprod.azurecr.io/adventureworkwebapi:1.0.4
        env:
        - name: AdventureWorkConnection
          valueFrom:
            secretKeyRef:
              name: adventurework-secrets
              key: AdventureWorkConnection
        - name: DOTNET_HOSTBUILDER__RELOADCONFIGONCHANGE
          value: "false"
        ports:
        - containerPort: 80
        - containerPort: 443
---
apiVersion: v1
kind: Service
metadata:
  name: adventurework-service
spec:
  selector:
    app: adventurework
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443

"@
$adventureWorkManifest | kubectl apply -f -

################################################
# Deploy API Management and self-hosted gateway
################################################

#Update the back end for weather API
Write-Host "`n"
Write-Host "Update the back end for weather API"
Write-Host "`n"

$advanceWorkServiceIp = "http://"+(kubectl get svc adventurework-service -o json | ConvertFrom-Json).spec.clusterIPs
$adventureWorkBackEndPolicyTemplate = "$Env:ArcBoxDir\apim\adventurework_template.xml" 
$adventureWorkBackEndPolicy = "$Env:ArcBoxDir\apim\adventurework.xml" 
(Get-Content -Path $adventureWorkBackEndPolicyTemplate) -replace 'IPPlaceHolder',$advanceWorkServiceIp | Set-Content -Path $adventureWorkBackEndPolicy

#Deploy API Management and the API
Write-Host "`n"
Write-Host "Deploy API Management and the API"
Write-Host "`n"

$apimDeploymentOutput =  $(az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\apim\apim.bicep" --parameters "$Env:ArcBoxDir\apim\apim.bicepparam") | ConvertFrom-Json
$apimName = $apimDeploymentOutput.properties.outputs.apiManagementServiceName.value


#Get access token to the REST API
Write-Host "`n"
Write-Host "Get access token to the REST API"
Write-Host "`n"

$access_token = $(az account get-access-token -s $env:subscriptionId --query "accessToken")| ConvertFrom-Json

#Call REST API to get the self-hosted gateway token
Write-Host "`n"
Write-Host "Call REST API to get the self-hosted gateway token"
Write-Host "`n"

$currentDate = Get-Date
$tokenExpire =  $currentDate.AddDays(5).ToString("yyyy-MM-ddTHH:mm:ssZ")
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Authorization", "Bearer "+$access_token)

$body = @"
{
	expiry: `"${tokenExpire}`",
	keyType: `"primary`"
}
"@
$generateTokenUrl = 'https://management.azure.com/subscriptions/'+$env:subscriptionId+'/resourceGroups/'+$env:resourceGroup+'/providers/Microsoft.ApiManagement/service/'+$apimName+'/gateways/selfhost/generateToken?api-version=2022-08-01'

$response = Invoke-RestMethod  $generateTokenUrl -Method 'POST' -Headers $headers -Body $body


#Create a secret for self-hosted gateway
Write-Host "`n"
Write-Host "Create a secret for self-hosted gateway"
Write-Host "`n"

$selfHostToken = "GatewayKey $($response.value)"
kubectl delete secret selfhost-token
kubectl create secret generic selfhost-token --from-literal=value="$($selfHostToken)"  --type=Opaque

#Deploy self host agent into k3s
Write-Host "`n"
Write-Host "Deploy self-hosted gateway into k3s"
Write-Host "`n"

$selfHostYaml = @"
# NOTE: Before deploying to a production environment, please review the documentation -> https://aka.ms/self-hosted-gateway-production
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: selfhost-env
  labels:
    app: selfhost
data:
  config.service.endpoint: "$($apimName).configuration.azure-api.net"
  neighborhood.host: "selfhost-instance-discovery"
  runtime.deployment.artifact.source: "Azure Portal"
  runtime.deployment.mechanism: "YAML"
  runtime.deployment.orchestrator.type: "Kubernetes"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selfhost
  labels:
    app: selfhost
spec:
  replicas: 1
  selector:
    matchLabels:
      app: selfhost
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 25%
  template:
    metadata:
      labels:
        app: selfhost
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: selfhost
        image: mcr.microsoft.com/azure-api-management/gateway:v2
        ports:
        - name: http
          containerPort: 8080
        - name: https
          containerPort: 8081
          # Container port used for rate limiting to discover instances
        - name: rate-limit-dc
          protocol: UDP
          containerPort: 4290
          # Container port used for instances to send heartbeats to each other
        - name: dc-heartbeat
          protocol: UDP
          containerPort: 4291
        readinessProbe:
          httpGet:
            path: /status-0123456789abcdef
            port: http
            scheme: HTTP
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        env:
        - name: config.service.auth
          valueFrom:
            secretKeyRef:
              name: selfhost-token
              key: value
        envFrom:
        - configMapRef:
            name: selfhost-env
---
apiVersion: v1
kind: Service
metadata:
  name: selfhost-live-traffic
  labels:
    app: selfhost
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8081
  selector:
    app: selfhost
---
apiVersion: v1
kind: Service
metadata:
  name: selfhost-instance-discovery
  labels:
    app: selfhost
  annotations:
    azure.apim.kubernetes.io/notes: "Headless service being used for instance discovery of self-hosted gateway"
spec:
  clusterIP: None
  type: ClusterIP
  ports:
  - name: rate-limit-discovery
    port: 4290
    targetPort: rate-limit-dc
    protocol: UDP
  - name: discovery-heartbeat
    port: 4291
    targetPort: dc-heartbeat
    protocol: UDP
  selector:
    app: selfhost
"@    
$selfHostYaml | kubectl apply -f -
Write-Host "`n"
Write-Host "Complete deploy APIM and AdventureWorks API"
Write-Host "`n"
Stop-Transcript
