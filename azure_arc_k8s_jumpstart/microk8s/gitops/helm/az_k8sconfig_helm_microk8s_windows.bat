@ECHO OFF
REM <--- Change the following environment variables according to your Azure Service Principal name --->

echo "Exporting environment variables"
SET appId="<Your Azure Service Principal name>"
SET password="<Your Azure Service Principal password>"
SET tenantId="<Your Azure tenant ID>"
SET resourceGroup="<Azure Resource Group Name>"
SET arcClusterName="<The name of your k8s cluster as it will be shown in Azure Arc>"
SET appClonedRepo="<The URL for the 'Hello Arc' cloned GitHub repository>"

echo "Log in to Azure with Service Principal"
call az login --service-principal --username %appId% --password %password% --tenant %tenantId%

echo "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
call az k8sconfiguration create ^
--name hello-arc ^
--cluster-name %arcClusterName% --resource-group %resourceGroup% ^
--operator-instance-name hello-arc --operator-namespace prod ^
--enable-helm-operator --helm-operator-version="0.6.0" ^
--helm-operator-params="--set helm.versions=v3" ^
--repository-url %appClonedRepo% ^
--scope namespace --cluster-type connectedClusters ^
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
