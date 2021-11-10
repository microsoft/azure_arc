# Sample commands to deploy ArcBox for IT Pros using Azure Bicep

```azurecli-interactive
az login
az account set --subscription "<subscription name>"
az group create --name "<resource-group-name>"  --location "<prefered-location>"
az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
```