
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

$appId | Write-Output C:\debug.txt

Write-Host "Installing Azure CLI"
choco install azure-cli -y

Write-Host "Installing Kubernetes CLI"
choco install kubernetes-cli -y

.\lucky2.ps1