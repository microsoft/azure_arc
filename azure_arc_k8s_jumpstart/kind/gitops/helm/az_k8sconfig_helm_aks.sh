#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export appId='558024d3-bcb9-4185-b2e2-87351d81710a'
export password='J-d~g3n4kP5-gNNH-0M3F71jYHz7pqV7jC'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='nfkindarc'
export arcClusterName='testauto4'
export appClonedRepo='https://github.com/nillsf/hello_arc.git'

# Getting AKS credentials
echo "Log in to Azure with Service Principle & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create Namespace-level GitOps-Config for deploying the "Hello Arc" application
echo "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
az k8sconfiguration create \
--name hello-arc \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name hello-arc --operator-namespace prod \
--enable-helm-operator --helm-operator-version='0.6.0' \
--helm-operator-params='--set helm.versions=v3' \
--repository-url $appClonedRepo \
--scope namespace --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
