# Sample commands to deploy ARcBox for IT Pros using bicep

```azurecli-interactive
az login
az account set --subscription "<subscription name>"
az group create --name "<resource-group-name>"  --location "<prefered-location>"
az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
```