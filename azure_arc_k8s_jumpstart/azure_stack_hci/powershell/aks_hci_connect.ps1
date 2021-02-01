# <--- Change the following environment variables according to your Azure service principal name --->


$clusterName = #<The name of your k8s cluster as it will be shown in Azure Arc>
$resourceGroup = #<Azure resource group name>
$location = #<Azure resource group location>
$subscriptionId = #<Azure subscription Id>
$appId = #<Your Azure service principal name>
$password = #<Your Azure service principal password>
$tenant = #<Your Azure tenant ID>

Install-AksHciArcOnboarding -clusterName $clusterName -resourcegroup $resourceGroup -location $location -subscriptionid $subscriptionId -clientid $appId -clientsecret $password -tenantid $tenant

