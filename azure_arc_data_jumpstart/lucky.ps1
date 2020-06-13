
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Write-Host "Installing Azure CLI"
# choco install azure-cli -y

Write-Host "Installing Kubernetes CLI"
choco install kubernetes-cli -y

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

$env:appId | Write-Output C:\debug.txt

az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
az aks get-credentials --name $env:arcClusterName --resource-group $env:resourceGroup --overwrite-existing