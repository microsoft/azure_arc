# PowerShell script to deploy an AKS cluster on HCI

#Environment variables to set up your AKS on HCI cluster
$vnetName= 'Provide the name of the virtual switch to connect the virtual machines to'
$vSwitchName= 'Provide external vswitch name'
$vipPoolStart= 'Provide the first IP address for your VIP Pool'
$vipPoolEnd= 'Provide the last IP address for your VIP Pool'
$k8sNodeIpPoolStart= 'first IP for the kubernetes nodes IP pool.'
$k8sNodeIpPoolEnd= 'last IP for the kubernetes nodes IP pool.'
$ipAddressPrefix= 'Network range in CIDR' 
$gateway= 'IP address for your networks gateway'
$dnsServers= 'static IP address that will be assigned to your DNS server.'
$imageDir = 'Provide a path to the directory where AKS on Azure Stack HCI will store its VHD images'
$cloudConfigLocation = 'Provide a path to the directory where the cloud agent will store its configuration'
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

If(!(test-path $imageDir))
{
      New-Item -ItemType Directory -Force -Path $imageDir
}

If(!(test-path $cloudConfigLocation))
{
      New-Item -ItemType Directory -Force -Path $cloudConfigLocation
}

$vnet = New-AksHciNetworkSetting -Name $vnetName -vSwitchName $vSwitchName -gateway $gateway -dnsservers $dnsServers `
    -ipaddressprefix $ipAddressPrefix -k8snodeippoolstart $k8sNodeIpPoolStart -k8snodeippoolend $k8sNodeIpPoolEnd `
    -vipPoolStart $vipPoolStart -vipPoolEnd $vipPoolEnd

Set-AksHciConfig -vnet $vnet -imageDir $imageDir -cloudConfigLocation $cloudConfigLocation -Verbose

$passwordsecure = ConvertTo-SecureString $password -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($appId, $passwordsecure)
Select-AzSubscription -SubscriptionId $subscriptionId

Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenant

Set-AksHciRegistration -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroup -TenantId $tenant -Credential $pscredential

Install-AksHci

New-AksHciCluster -Name $clusterName -controlPlaneNodeCount $controlPlaneNodeCount -linuxNodeCount $linuxNodeCount -windowsNodeCount $windowsNodeCount

Get-AksHciCredential -Name $clusterName -Confirm:$false

# Arc onboarding 

Enable-AksHciArcConnection -Name $clusterName -resourcegroup $resourceGroup -location $location -subscriptionid $subscriptionId -credential $pscredential -tenantId $tenant 