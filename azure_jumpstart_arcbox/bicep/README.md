# Sample commands to deploy ArcBox for IT Pros using Azure Bicep

Make sure to update the **Flavor** parameter in **main.parameters.json** before executing these commands to reflect the desired configuration.

```azurecli-interactive
az login
az account set --subscription "<subscription name>"
az group create --name "<resource-group-name>"  --location "<preferred-location>"
az deployment group create -g "<resource-group-name>" -f "main.bicep" -p "main.parameters.json"
```
