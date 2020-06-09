# <--- Change the following environment variables according to your Azure Service Principle name --->

Write-Output "Exporting environment variables"
$env:subscriptionId="${subscriptionId}"
$env:appId="${appId}"
$env:password="${appPassword}"
$env:tenantId="${tenantId}"
$env:resourceGroup="${resourceGroup}"
$env:arcClusterName="${arcClusterName}"

curl -LO https://raw.githubusercontent.com/microsoft/OMS-docker/ci_feature/docs/haiku/onboarding_azuremonitor_for_containers.ps1

Write-Output "Log in to Azure with Service Principle & Getting k8s credentials (kubeconfig)"
az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
az aks get-credentials --name $env:arcClusterName --resource-group $env:resourceGroup --overwrite-existing
$env:currentContext = kubectl config current-context

.\onboarding_azuremonitor_for_containers.ps1 -azureArcClusterResourceId /subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$env:arcClusterName -kubeContext $env:currentContext