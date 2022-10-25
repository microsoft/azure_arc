# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxGitOpsDir = "C:\HCIBox\GitOps"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

# Import Configuration Module
$ConfigurationDataFile = "$Env:HCIBoxDir\HCIBox-Config.psd1"
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-ArcResourceBridge.log

# Set AD Domain cred
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

# Install AZ Resource Bridge and prerequisites
Write-Host "Now Preparing to Install Azure Arc Resource Bridge"

# Install Required Modules
foreach ($VM in $SDNConfig.HostList) { 
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi
    }
}
$csv_path = "C:\ClusterStorage\S2D_vDISK1"
foreach ($VM in $SDNConfig.HostList) {
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        Install-PackageProvider -Name NuGet -Force 
        # Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck
        Install-Module -Name ArcHci -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense
    }
}
foreach ($VM in $SDNConfig.HostList) {
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        $ErrorActionPreference = "SilentlyContinue"
        az extension add --upgrade --name arcappliance
        az extension add --upgrade --name connectedk8s
        az extension add --upgrade --name k8s-configuration
        az extension add --upgrade --name k8s-extension
        az extension add --upgrade --name customlocation
        az extension add --upgrade --name azurestackhci
        $ErrorActionPreference = "Continue"
    }
}

Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-Item -Path $using:csv_path -Name "ResourceBridge" -ItemType Directory
}

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$resource_name = "HCIBox-ResourceBridge"
$location = "eastus"
$custom_location_name = "hcibox-rb-cl"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-ArcHciConfigFiles -subscriptionId $using:subId -location eastus -resourceGroup $using:rg -resourceName $using:resource_name -workDirectory $using:csv_path\ResourceBridge -controlPlaneIP $using:SDNConfig.rbCpip  -k8snodeippoolstart $using:SDNConfig.rbIp -k8snodeippoolend $using:SDNConfig.rbIp -gateway $using:SDNConfig.AKSGWIP -dnsservers $using:SDNConfig.AKSDNSIP -ipaddressprefix $using:SDNConfig.AKSIPPrefix
}
$ErrorActionPreference = "SilentlyContinue"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Write-Host "Deploying Arc Resource Bridge. This will take a while."
    az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId
    az provider register -n Microsoft.ResourceConnector --wait
    az arcappliance validate hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml
    az arcappliance prepare hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml
    az arcappliance deploy hci --config-file  $using:csv_path\ResourceBridge\hci-appliance.yaml --outfile $env:USERPROFILE\.kube\config
    az arcappliance create hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --kubeconfig $env:USERPROFILE\.kube\config

    $rbReady = $false
    Do {
        Write-Host "Waiting on Arc Resource Bridge deployment to complete..."
        Start-Sleep 60
        $readiness = az arcappliance show --resource-group $using:rg --name $using:resource_name | ConvertFrom-Json
        if (($readiness.provisioningState -eq "Succeeded") -and ($readiness.status -eq "Running")) {
            $rbReady = $true
        }
    } Until ($rbReady)
    Write-Host "Arc Resource Bridge deployment complete."

    # Configuring custom location
    Write-Host "Creating custom location"
    $hciClusterId= (Get-AzureStackHci).AzureResourceUri
    az k8s-extension create --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name hci-vmoperator --extension-type Microsoft.AZStackHCI.Operator --scope cluster --release-namespace helm-operator2 --configuration-settings Microsoft.CustomLocation.ServiceAccount=hci-vmoperator --configuration-protected-settings-file $using:csv_path\ResourceBridge\hci-config.json --configuration-settings HCIClusterID=$hciClusterId --auto-upgrade true

    $clReady = $false
    Do {
        Write-Host "Waiting for custom location to provision..."
        Start-Sleep 10
        $readiness = az k8s-extension show --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name hci-vmoperator | ConvertFrom-Json
        if ($readiness.provisioningState -eq "Succeeded") {
            $clReady = $true
        }
    } Until ($clReady)

    az customlocation create --resource-group $using:rg --name $using:custom_location_name --cluster-extension-ids "/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ResourceConnector/appliances/$using:resource_name/providers/Microsoft.KubernetesConfiguration/extensions/hci-vmoperator" --namespace hci-vmoperator --host-resource-id "/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ResourceConnector/appliances/$using:resource_name" --location $using:location
    Write-Host "Custom location created."
}
$ErrorActionPreference = "Continue"

# Copy gallery VHDs to hosts
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-Item -Name "VHD" -Path $using:csv_path -ItemType Directory -Force
    Move-Item -Path "C:\VHD\GUI.vhdx" -Destination "$using:csv_path\VHD\GUI.vhdx" -Force
    Move-Item -Path "C:\VHD\Ubuntu.vhdx" -Destination "$using:csv_path\VHD\Ubuntu.vhdx" -Force
}

$ErrorActionPreference = "SilentlyContinue"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $vnetName="sdnSwitch"
    az azurestackhci virtualnetwork create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --network-type "Transparent" --name $vnetName
    
    $galleryImageName = "ubuntu20"
    $galleryImageSourcePath="$using:csv_path\VHD\Ubuntu.vhdx"
    $osType="Linux"
    az azurestackhci galleryimage create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --image-path $galleryImageSourcePath --name $galleryImageName --os-type $osType

    $galleryImageName = "win2k22"
    $galleryImageSourcePath="$using:csv_path\VHD\GUI.vhdx"
    $osType="Windows"
    az azurestackhci galleryimage create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --image-path $galleryImageSourcePath --name $galleryImageName --os-type $osType
}
$ErrorActionPreference = "Continue"
Stop-Transcript
