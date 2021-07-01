# PowerShell script to deploy Azure Monitor extension

# <--- Change the following environment variables according to your Azure service principal name --->
$appId ='<Your Azure service principal name>'
$password ='<Your Azure service principal password>'
$tenantId ='<Your Azure tenant ID>'
$resourceGroup ='<Azure resource group name>'
$arcClusterName ='<The name of your AKS cluster running on Azure Stack HCI>'
$k8sExtensionName='<Azure Monitor Extension Name' #default: 'azuremonitor-containers'

# Installing Helm 3
choco install kubernetes-helm

# Installing Azure CLI & Azure Arc Extensions
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi


# Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension...

az extension add --name "connectedk8s"
az extension update --name "connectedk8s"

# Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension...

az extension add --name "k8s-extension"
az extension update --name "k8s-extension"

# Login to Az CLI using the service principal
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create monitor k8s extension instance
az k8s-extension create --name $k8sExtensionName --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-ty