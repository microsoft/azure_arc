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
az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\artifacts\apim\apim.bicep" --parameters "$Env:ArcBoxDir\artifacts\apim\apim.bicepparam"

# # Required for azcopy
# $azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal


# Setting kubeconfig
# Write-Header "Get kubeconfig"
$clusterName = az connectedk8s list --resource-group $Env:resourceGroup --query "[].{Name:name} | [? contains(Name,'ArcBox')]" --output tsv
kubectx arcbox-k3s
kubectl get nodes
    
# }
# Deploy APIM and set up weather api
# $apimDeploymentOutput = az deployment group create --resource-group $rg --template-file $Env:HCIBoxDir\artifacts\apim\apim.bicep --parameters $Env:HCIBoxDir\artifacts\apim\apim.bicepparam | ConvertFrom-Json
# $selfhostKey = $apimDeploymentOutput.properties.outputs.gatewayKey.value
# kubectl create secret generic selfhost-token --from-literal=value="GatewayKey ${selfhostKey}"  --type=Opaque
# kubectl apply -f $Env:ArcBoxDir\artifacts\apim\selfhost.yaml

Stop-Transcript
