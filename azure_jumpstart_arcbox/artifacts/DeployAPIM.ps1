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
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId
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
# Switch kubectl context
Write-Host "`n"
Write-Host "Switch kubectl context to K3s"
Write-Host "`n"

kubectx arcbox-k3s
kubectl get nodes

# Build the AdventureWorks API manifest
Write-Host "`n"
Write-Host " Build the AdventureWorks API manifest"
Write-Host "`n"

kubectl delete secret adventurework-secrets

$adventureWorkSecretTemplate = "$Env:ArcBoxDir\apim\adventurework_secret_template.yaml" 
$adventureWorkSecret = "$Env:ArcBoxDir\apim\adventurework_secret.yaml" 
(Get-Content -Path $adventureWorkSecretTemplate) -replace 'AdventureWorkConnectionPlaceHolder',$base64ConnectionString | Set-Content -Path $adventureWorkSecret
kubectl apply -f $adventureWorkSecret

# Deploy AdventureWorks API
Write-Host "`n"
Write-Host "Deploy AdvanetureWorks API"
Write-Host "`n"

kubectl apply -f "$Env:ArcBoxDir\apim\adventurework_deployment.yaml" 
kubectl apply -f "$Env:ArcBoxDir\apim\adventurework_service.yaml" 


################################################
# Deploy API Management and self-hosted gateway
################################################

# Update the back end for weather API
Write-Host "`n"
Write-Host "Update the back end for weather API"
Write-Host "`n"

$advanceWorkServiceIp = "http://"+(kubectl get svc adventurework-service -o json | ConvertFrom-Json).spec.clusterIPs
$adventureWorkBackEndPolicyTemplate = "$Env:ArcBoxDir\apim\adventurework_template.xml" 
$adventureWorkBackEndPolicy = "$Env:ArcBoxDir\apim\adventurework.xml" 
(Get-Content -Path $adventureWorkBackEndPolicyTemplate) -replace 'IPPlaceHolder',$advanceWorkServiceIp | Set-Content -Path $adventureWorkBackEndPolicy

# Deploy API Management and the API
Write-Host "`n"
Write-Host "Deploy API Management and the API"
Write-Host "`n"

$apimDeploymentOutput =  $(az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\apim\apim.bicep" --parameters "$Env:ArcBoxDir\apim\apim.bicepparam") | ConvertFrom-Json
$apimName = $apimDeploymentOutput.properties.outputs.apiManagementServiceName.value


# Get access token to the REST API
Write-Host "`n"
Write-Host "Get access token to the REST API"
Write-Host "`n"

$access_token = $(az account get-access-token -s $env:subscriptionId --query "accessToken")| ConvertFrom-Json

# Call REST API to get the self-hosted gateway token
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


# Create a secret for self-hosted gateway
Write-Host "`n"
Write-Host "Create a secret for self-hosted gateway"
Write-Host "`n"

$selfHostToken = "GatewayKey $($response.value)"
kubectl delete secret selfhost-token
kubectl create secret generic selfhost-token --from-literal=value="$($selfHostToken)"  --type=Opaque

# Deploy self host agent into K3s
Write-Host "`n"
Write-Host "Deploy self-hosted gateway into K3s"
Write-Host "`n"

# Build self-hosted gateway config map and deploy to K3s
Write-Host "`n"
Write-Host "Build self-hosted gateway config map and deploy to K3s"
Write-Host "`n"
$selfhostedGatewayConfigMapTemplate = "$Env:ArcBoxDir\apim\selfhosted_gateway_configmap_template.yaml" 
$selfhostedGatewayConfigMap = "$Env:ArcBoxDir\apim\selfhosted_gateway_configmap.yaml" 
(Get-Content -Path $selfhostedGatewayConfigMapTemplate) -replace 'APIMNAMEHOLDER',$apimName | Set-Content -Path $selfhostedGatewayConfigMap
kubectl apply -f $selfhostedGatewayConfigMap

# Deploy self-hosted gateway deployement and service to K3s
Write-Host "`n"
Write-Host "Deploy self-hosted gateway deployement and service to K3s"
Write-Host "`n"
kubectl apply -f "$Env:ArcBoxDir\apim\selfhosted_gateway_deployment.yaml"
kubectl apply -f "$Env:ArcBoxDir\apim\selfhosted_gateway_service.yaml"


# Write log for completion
Write-Host "`n"
Write-Host "Complete deploy APIM and AdventureWorks API"
Write-Host "`n"
Stop-Transcript