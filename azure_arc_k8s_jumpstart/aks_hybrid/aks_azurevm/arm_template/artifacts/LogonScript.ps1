Start-Transcript -Path C:\Temp\LogonScript.log

# Powershell-Cmdlet -Confirm:$false

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register your Azure subscription for features and providers
az provider register --namespace Microsoft.Kubernetes --wait 
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.ResourceConnector --wait
az provider register --namespace Microsoft.HybridContainerService --wait
az feature register --namespace Microsoft.HybridConnectivity --name hiddenPreviewAccess

Do {
    Write-Host "Waiting for hiddenPreviewAccess feature registration, hold tight...(30s sleeping loop)"
    Start-Sleep -Seconds 30
    $state = az feature show --namespace Microsoft.HybridConnectivity --name hiddenPreviewAccess --query "properties.state" -o tsv
    $state = $(if($state = "Registered"){"Ready!"}Else{"Nope"})
} while ($state -eq "Nope")

az provider register --namespace Microsoft.HybridConnectivity --wait

# Installing Azure CLI extensions
Write-Host "`n"
Write-Host "Installing Azure CLI extensions"
az extension add -n k8s-extension --upgrade
az extension add -n customlocation --upgrade
az extension add -n arcappliance --upgrade --version 0.2.27
az extension add -n hybridaks --upgrade
Write-Host "`n"
az -v

# Set default subscription to run commands against
az account set --subscription $Env:subscriptionId

# Parameters
$aksHciConfigVersion = "1.0.13.10907"
$workingDir = "V:\AKS-HCI\WorkDir"
$arcAppName = "arc-resource-bridge"
$configFilePath = $workingDir + "\hci-appliance.yaml"
$arcExtnName = "aks-hybrid-ext"
$customLocationName = "azurevm-customlocation"
$kubernetesVersion = "1.21.9"

# Install pre-requisite PowerShell repositories

$nid = (Start-Process -PassThru PowerShell {for (0 -lt 1) {Install-PackageProvider -Name NuGet -Force; Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted; Install-Module -Name PowershellGet -Force; Exit}}).id
Wait-Process -Id $nid
$nid = (Start-Process -PassThru PowerShell {for (0 -lt 1) {Install-Module -Name AksHci -Repository PSGallery -AcceptLicense -Force; Exit}}).id
Wait-Process -Id $nid
$nid = (Start-Process -PassThru PowerShell {for (0 -lt 1) {Install-Module -Name ArcHci -Repository PSGallery -AcceptLicense -Force; Exit}}).id
Wait-Process -Id $nid


Initialize-AksHciNode

New-Item -Path "V:\" -Name "AKS-HCI" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Images" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "WorkingDir" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Config" -ItemType "directory" -Force

# Install the AKS on Windows Server management cluster
$vnet=New-AksHciNetworkSetting -Name "mgmt-vnet" -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.4" -k8snodeippoolend "192.168.0.10" -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.160"
Set-AksHciConfig -vnet $vnet -imageDir "V:\AKS-HCI\Images" -workingDir "V:\AKS-HCI\WorkingDir" -cloudConfigLocation "V:\AKS-HCI\Config" -version $aksHciConfigVersion -cloudServiceIP "192.168.0.4"

$SecuredPassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Env:spnClientId, $SecuredPassword
# Connect-AzAccount -ServicePrincipal -TenantId $Env:spnTenantId -Credential $Credential
Set-AksHciRegistration -TenantId $Env:spnTenantId -SubscriptionId $Env:subscriptionId -ResourceGroupName $Env:resourceGroup -Credential $Credential

Install-AksHci

# Generate pre-requisite YAML files needed to deploy Azure Arc Resource Bridge
New-ArcHciAksConfigFiles -subscriptionID $Env:subscriptionId -location $Env:location -resourceGroup $Env:resourceGroup -resourceName $arcAppName -workDirectory $workingDir -vnetName "appliance-vnet" -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.11" -k8snodeippoolend "192.168.0.11" -controlPlaneIP "192.168.0.161"

# Deploy Azure Arc Resource Bridge
az arcappliance validate hci --config-file $configFilePath
az arcappliance prepare hci --config-file $configFilePath
az arcappliance deploy hci --config-file $configFilePath --outfile $workingDir\config
az arcappliance create hci --config-file $configFilePath --kubeconfig $workingDir\config

# The Arc Resource Bridge must be in Running status
Do {
    Write-Host "Waiting for Arc Resource Bridge (Connecting Arc Resource Bridge to Azure may take up to 10 minutes to finish), hold tight..."
    Start-Sleep -Seconds 660 # Error!!! it retrieves status Running but it is Connected, so it will fail in next steps, so sleep 11min
    $status = az arcappliance show --resource-group $Env:resourceGroup --name $arcAppName --query "status" -o tsv
    $status = $(if($status = "Running"){"Ready!"}Else{"Nope"})
} while ($status -eq "Nope")


# Install the AKS hybrid extension on the Arc Resource Bridge
az k8s-extension create -g $Env:resourceGroup -c $arcAppName --cluster-type appliances --name $arcExtnName  --extension-type Microsoft.HybridAKSOperator --config Microsoft.CustomLocation.ServiceAccount="default" --no-wait

# AKS hybrid extension installation on the Arc Resource Bridge must be in Succeeded state
Do {
    Write-Host "Waiting for the AKS hybrid extension installation on the Arc Resource Bridge (May take up to 10 minutes to install), hold tight...(60s sleeping loop)"
    Start-Sleep -Seconds 900 # Error!!! it retrieves state Succeeded, but InstallState of Cluster Extension is Unknown, so it will fail in next steps, so sleep 11min
    $state = az k8s-extension show --resource-group $Env:resourceGroup --cluster-name $arcAppName --cluster-type appliances --name $arcExtnName --query "provisioningState" -o tsv
    $state = $(if($state = "Succeeded"){"Ready!"}Else{"Nope"})
} while ($state -eq "Nope")

# Create a Custom Location on top of the Azure Arc Resource Bridge
$ArcApplianceResourceId=az arcappliance show --resource-group $Env:resourceGroup --name $arcAppName --query id -o tsv
$ClusterExtensionResourceId=az k8s-extension show --resource-group $Env:resourceGroup --cluster-name $arcAppName --cluster-type appliances --name $arcExtnName --query id -o tsv
az customlocation create --name $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $ClusterExtensionResourceId --resource-group $Env:resourceGroup

# Custom Location on top of the Azure Arc Resource Bridge must be in Succeeded state
Do {
    Write-Host "Custom Location on top of the Azure Arc Resource Bridge must be in Succeeded state (May take up to 10 minutes), hold tight...(60s sleeping loop)"
    Start-Sleep -Seconds 60
    $state = az customlocation show --name $customLocationName --resource-group $Env:resourceGroup --query "provisioningState" -o tsv
    $state = $(if($state = "Succeeded"){"Ready!"}Else{"Nope"})
} while ($state -eq "Nope")

# Create a local network for AKS hybrid clusters and connect it to Azure
New-KvaVirtualNetwork -name hybridaks-vnet -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.15" -k8snodeippoolend "192.168.0.25" -vipPoolStart "192.168.0.162" -vipPoolEnd "192.168.0.170" -kubeconfig $workingDir\config
$clid = az customlocation show --name $customLocationName --resource-group $Env:resourceGroup --query "id" -o tsv
az hybridaks vnet create -n "azvnet" -g $Env:resourceGroup --custom-location $clId --moc-vnet-name "hybridaks-vnet"
$vnetId = az hybridaks vnet show -n "azvnet" -g $Env:resourceGroup --query id -o tsv

# Download the Kubernetes VHD image to your Azure VM
Add-KvaGalleryImage -kubernetesVersion $kubernetesVersion

# Create an Azure AD group and add Azure AD members (AKS admins) to it
$suffix=-join ((97..122) | Get-Random -Count 4 | % {[char]$_})
$groupId = az ad group create --display-name "adminGroupAksHybrid-$suffix" --mail-nickname "adminGroupAksHybrid-$suffix" --query id -o tsv
$spnObjectId = az ad sp show --id $Env:spnClientId --query id -o tsv
az ad group member add --group $groupId --member-id $spnObjectId

# Create an AKS hybrid cluster using Azure CLI
az hybridaks create --name akshybridcluster --resource-group $Env:resourceGroup --custom-location $clid --vnet-ids $vnetId --kubernetes-version "v$kubernetesVersion" --aad-admin-group-object-ids $groupId --generate-ssh-keys

# Add a Linux nodepool to the AKS hybrid cluster
az hybridaks nodepool add -n linuxNodepool --resource-group $Env:resourceGroup --cluster-name akshybridcluster

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5

Stop-Process -Name powershell -Force

Stop-Transcript