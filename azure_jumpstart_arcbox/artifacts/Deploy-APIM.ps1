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

$ingressNamespace = "ingress-nginx"

$certname = "ingress-cert"
$certdns = "hcibox.devops.com"

$appClonedRepo = "https://github.com/microsoft/azure-arc-jumpstart-apps"

if ($host.Name -match 'ISE') {throw "Running this script in PowerShell ISE is not supported"}

try {
    Start-Transcript -Path $Env:ArcBoxLogsDir\Deploy-APIM.log
}
catch {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-APIM.log
}

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt
$apimDeploymentOutput =  $(az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\apim\apim.bicep" --parameters "$Env:ArcBoxDir\apim\apim.bicepparam") | ConvertFrom-Json
$gatewayKey = $apimDeploymentOutput.properties.outputs.gatewayKey.value
$apimName = $apimDeploymentOutput.properties.outputs.apiManagementServiceName.value

#Get access token to the rest api
$access_token = $(az account get-access-token -s $env:subscriptionId --query "accessToken")| ConvertFrom-Json

#Call Rest API to get the selft host gateway token
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

##deploy selft host gateway in kubernestes
# Setting kubeconfig
$clusterName = az connectedk8s list --resource-group $Env:resourceGroup --query "[].{Name:name} | [? contains(Name,'ArcBox')]" --output tsv
kubectx arcbox-k3s
kubectl get nodes
kubectl create secret generic selfhost-token --from-literal=value="GatewayKey "+$response.value  --type=Opaque
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
# }
# Deploy APIM and set up weather api
# $apimDeploymentOutput = az deployment group create --resource-group $rg --template-file $Env:HCIBoxDir\artifacts\apim\apim.bicep --parameters $Env:HCIBoxDir\artifacts\apim\apim.bicepparam | ConvertFrom-Json
# $selfhostKey = $apimDeploymentOutput.properties.outputs.gatewayKey.value
# kubectl create secret generic selfhost-token --from-literal=value="GatewayKey ${selfhostKey}"  --type=Opaque
# kubectl apply -f $Env:ArcBoxDir\artifacts\apim\selfhost.yaml

Stop-Transcript
# # Required for azcopy
# $azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal
