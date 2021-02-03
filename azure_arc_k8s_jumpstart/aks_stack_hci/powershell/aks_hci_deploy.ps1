# PowerShell script to deploy an AKS cluster on HCI

#Environment variables to set up your AKS on HCI cluster
$imageDir = 'Provide a path to the directory where AKS on Azure Stack HCI will store its VHD images'
$cloudConfigLocation = 'Provide a path to the directory where the cloud agent will store its configuration'
$vnetName = 'Provide the name of the virtual switch to connect the virtual machines to'
$clusterName = 'Provide a name for your AKS cluster'
$controlPlaneNodeCount = 'Provide an odd number of nodes for your control plane'
$linuxNodeCount = 'Provide a number of Linux node VMs for your cluster'
$windowsNodeCount = 'Provide a number of Windows node VMs for your cluster'

#Environment variables to onboard the cluster on Azure Arc 
$resourceGroup = 'Provide a resource group to connect your Azure Arc enabled Kubernetes'
$location = 'Provide an  Azure region to connect your Azure Arc enabled Kubernetes'
$subscriptionId = 'Provide a subscription to connect your Azure Arc enabled Kubernetes'
$appId = 'Provide the appID of the service principal created'
$password = 'Provide the password of the service principal created'
$tenant = 'Provide your tenantID'

# AKS deployment on HCI 

Set-AksHciConfig -imageDir $imageDir -cloudConfigLocation $cloudConfigLocation -vnetName $vnetName

Install-AksHci

Get-AksHciCredential -clusterName clustergroup-management

New-AksHciCluster -Name $clusterName -controlPlaneNodeCount $controlPlaneNodeCount -linuxNodeCount $linuxNodeCount -windowsNodeCount $windowsNodeCount

Get-AksHciCluster

# Arc onboarding 

Install-AksHciArcOnboarding -Name $clusterName -resourcegroup $resourceGroup -location $location -subscriptionid $subscriptionId -clientid $appId -clientsecret $password -tenantid $tenant