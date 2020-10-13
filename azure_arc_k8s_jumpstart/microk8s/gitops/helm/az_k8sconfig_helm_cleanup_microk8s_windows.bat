@ECHO OFF
REM <--- Change the following environment variables according to your Azure Service Principal name --->

echo "Exporting environment variables"
SET resourceGroup="<Your resource group name>"
SET arcClusterName="<Your Arc cluster name>"
SET appId="<Your Azure Service Principal name>"
SET password="<Your Azure Service Principal password>"
SET tenantId="<Your Azure tenant ID>"

echo "Log in to Azure with Service Principal"
call az login --service-principal --username %appId% --password %password% --tenant %tenantId%


echo "Deleting GitOps Configurations from Azure Arc Kubernetes cluster"
call az k8sconfiguration delete --name hello-arc --cluster-name %arcClusterName% --resource-group %resourceGroup% --cluster-type connectedClusters -y

echo "Cleaning Kubernetes cluster. You Can safely ignore non-exist resources"
microk8s kubectl delete ns prod

microk8s kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd

microk8s kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator

microk8s kubectl delete -f  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.35.0/deploy/static/provider/baremetal/deploy.yaml

microk8s kubectl delete secret sh.helm.release.v1.azure-arc.v1 -n default