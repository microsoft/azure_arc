# PowerShell script to deploy an AKS cluster on HCI


$imageDir = Read-Host -Prompt 'Provide a path to the directory where AKS on Azure Stack HCI will store its VHD images'
$cloudConfigLocation = Read-Host -Prompt 'Provide a path to the directory where the cloud agent will store its configuration'
$vnetName = Read-Host -Prompt 'Provide the name of the virtual switch to connect the virtual machines to'
$clusterName = Read-Host -Prompt 'Provide a name for your AKS cluster'
$controlPlaneNodeCount = Read-Host -Prompt 'Provide an odd number of nodes for your control plane'
$linuxNodeCount = Read-Host -Prompt 'Provide a number of Linux node VMs for your cluster'
$windowsNodeCount = Read-Host -Prompt 'Provide a number of Windows node VMs for your cluster'

# AKS deployment on HCI 

Set-AksHciConfig -imageDir $imageDir -cloudConfigLocation $cloudConfigLocation -vnetName $vnetName

Install-AksHci

Get-AksHciCredential -clusterName clustergroup-management

New-AksHciCluster -clusterName $clusterName -controlPlaneNodeCount $controlPlaneNodeCount -linuxNodeCount $linuxNodeCount -windowsNodeCount $windowsNodeCount

Get-AksHciCluster