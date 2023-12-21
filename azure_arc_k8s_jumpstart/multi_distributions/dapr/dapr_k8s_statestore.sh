#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export location='<Azure Region>'
export daprExtensionName='daprextension' # Do not change!
export redisSKU='Basic' # Do not change!
export redisVMSize='c0' # Do not change!
export redisName=secret-store-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1) # Do not change!

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

echo "Deploying Azure Cache for Redis"
az group create --location $location --name $resourceGroup
az redis create --location $location --name $redisName --resource-group $resourceGroup --sku $redisSKU --vm-size $redisVMSize

echo "Installing Dapr Azure Arc-enabled Kuberntets Cluster extension"
az k8s-extension create --cluster-type connectedClusters --cluster-name $arcClusterName --resource-group $resourceGroup --name $daprExtensionName --extension-type Microsoft.Dapr

echo "Creating the Kubernetes secret for Redis"
export key=$(az redis list-keys --name $redisName --resource-group $resourceGroup --query "primaryKey" -o tsv)
kubectl create secret generic redis --from-literal=redis-password=$key

echo "Configure State store"
cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: $redisName.redis.cache.windows.net:6380
  - name: redisPassword
    secretKeyRef:
      name: redis
      key: redis-password
  - name: enableTLS
    value: true
auth:
  secretStore: kubernetes
EOF

echo "Deploy the Node.js app with the Dapr sidecar"
cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: nodeapp
  labels:
    app: node
spec:
  selector:
    app: node
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeapp
  labels:
    app: node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: node
  template:
    metadata:
      labels:
        app: node
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "nodeapp"
        dapr.io/app-port: "3000"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: node
        image: ghcr.io/dapr/samples/hello-k8s-node:latest
        env:
        - name: APP_PORT
          value: "3000"
        ports:
        - containerPort: 3000
        imagePullPolicy: Always
EOF
