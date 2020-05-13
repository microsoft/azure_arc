
Set-ExecutionPolicy Unrestricted -Force

# Injecting environment variables
Invoke-Expression "C:\runtime\vars.ps1"

# Installing Azure CLI
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
az login --service-principal --username $appId --password $password --tenant $tenantId
az group create --location $location --name $resourceGroup --subscription $subscriptionId

# Creating cleanup script for 'vagrant destory'
New-Item C:\vagrant\delete_rg.ps1
Set-Content C:\vagrant\delete_rg.ps1 'az group delete --name $resourceGroup --subscription $subscriptionId --yes'

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --appId "{serviceprincipalAppID}" `
  --password "{serviceprincipalPassword}" `
  --resourceGroup "{ResourceGroupName}" `
  --tenantId "{tenantID}" `
  --location "{resourceLocation}" `
  --subscriptionId "{subscriptionID}"
