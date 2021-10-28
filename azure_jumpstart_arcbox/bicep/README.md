# Sample commands to deploy ARcBox for IT Pros using bicep

```azurecli-interactive
az login
az account set --subscription "<subscription name>"
az group create --name "<resource-group-name>"  --location "<prefered-location>"
az deployment group create --mode incremental --resource-group "<resource-group-name>" --template-file "main.bicep" --parameters "main.parameters.json"
```
