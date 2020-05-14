

# Injecting environment variables
Invoke-Expression "C:\runtime\vars.ps1"

# Installing Azure CLI
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
az group create --location $env:location --name $env:resourceGroup --subscription $env:subscriptionId 

# Creating cleanup script for 'vagrant destory'
New-Item C:\runtime\delete_rg.ps1
Set-Content C:\runtime\delete_rg.ps1 'az group delete --name $env:resourceGroup --subscription $env:subscriptionId --yes'

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

 # Run connect command
 & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
 --service-principal-id $env:appId `
 --service-principal-secret $env:password `
 --resource-group $env:resourceGroup `
 --tenant-id $env:tenantId `
 --location $env:location `
 --subscription-id $env:subscriptionId
