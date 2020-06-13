
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

$appId | Write-Output C:\debug.txt

Write-Host "Installing Azure CLI"
choco install azure-cli -y

Write-Host "Installing Kubernetes CLI"
choco install kubernetes-cli -y

Invoke-Expression 'cmd /c start powershell -Command { az login --service-principal --username '$appId' --password '$password' --tenant '$tenantId'; az aks get-credentials --name '$arcClusterName' --resource-group '$resourceGroup' --overwrite-existing}'


# az login --service-principal --username $appId --password $password --tenant $tenantId
# az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing