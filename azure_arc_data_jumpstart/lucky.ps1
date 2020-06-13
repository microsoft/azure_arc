
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

$env:appId | Write-Output C:\debug.txt

Write-Host "Installing Azure CLI"
choco install azure-cli -y

Write-Host "Installing Kubernetes CLI"
choco install kubernetes-cli -y

invoke-expression 'cmd /c start powershell -Command { az login --service-principal --username '$env:appId' --password '$env:password' --tenant '$env:tenantId'; az aks get-credentials --name '$env:arcClusterName' --resource-group '$env:resourceGroup' --overwrite-existing}'


# az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
# az aks get-credentials --name $env:arcClusterName --resource-group $env:resourceGroup --overwrite-existing