# <--- Change the following environment variables according to your Azure service principal name --->

Write-Output "Exporting environment variables"
$resourceGroup="<Your resource group name>"
$arcClusterName="<Your Arc cluster name>"
$appId="<Your Azure service principal name>"
$password="<Your Azure service principal password>"
$tenantId="<Your Azure tenant ID>"

Write-Output "Log in to Azure with Service Principal"
call az login --service-principal --username $appId --password $password --tenant $tenantId

Write-Output "Deleting GitOps Configurations from Azure Arc Kubernetes cluster"
call az k8s-configuration delete --name hello-arc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

Write-Output "Cleaning Kubernetes cluster. You Can safely ignore non-exist resources"
microk8s kubectl delete ns prod

microk8s kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd

microk8s kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator

microk8s kubectl delete -f  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.35.0/deploy/static/provider/baremetal/deploy.yaml

microk8s kubectl delete secret sh.helm.release.v1.azure-arc.v1 -n default
