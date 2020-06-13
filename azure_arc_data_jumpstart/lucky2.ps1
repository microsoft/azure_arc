$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
az aks get-credentials --name $env:arcClusterName --resource-group $env:resourceGroup --overwrite-existing
