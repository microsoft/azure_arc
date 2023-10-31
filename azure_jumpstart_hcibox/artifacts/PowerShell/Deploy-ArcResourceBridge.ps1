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

Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-ArcResourceBridge.log

# Import Configuration Module
$ConfigurationDataFile = "$Env:HCIBoxDir\HCIBox-Config.psd1"
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile
$csv_path = "C:\ClusterStorage\S2D_vDISK1"

# Set AD Domain cred
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

# Install AZ Resource Bridge and prerequisites
Write-Host "Now Preparing to Install Azure Arc Resource Bridge"

if ($env:deployAKSHCI -eq $false) {
    Write-Header "Install latest versions of Nuget and PowershellGet"
    Invoke-Command -VMName $HCIBoxConfig.HostList -Credential $adcred -ScriptBlock {
        Enable-PSRemoting -Force
        Install-PackageProvider -Name NuGet -Force 
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Install-Module -Name PowershellGet -Force
    }
}

Invoke-Command -VMName $HCIBoxConfig.HostList  -Credential $adcred -ScriptBlock {
    Install-Module -Name Moc -Repository PSGallery -AcceptLicense -Force
    Initialize-MocNode
    Install-Module -Name ArcHci -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense
}

Invoke-Command -VMName $HCIBoxConfig.HostList -Credential $adcred -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\",[System.EnvironmentVariableTarget]::Machine)
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    az extension add --upgrade --version 0.2.31 --name arcappliance --only-show-errors
    az extension add --upgrade --name connectedk8s --only-show-errors
    az extension add --upgrade --name k8s-configuration --only-show-errors
    az extension add --upgrade --name k8s-extension --only-show-errors
    az extension add --upgrade --name customlocation --only-show-errors
    az extension add --upgrade --name azurestackhci --only-show-errors
}

Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
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
$cloudServiceIP = $HCIBoxConfig.AKSCloudSvcidr.Substring(0, $HCIBoxConfig.AKSCloudSvcidr.IndexOf('/'))

if ($env:deployAKSHCI -eq $false) {
    Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
        #$vnet = New-MocNetworkSetting -Name $using:HCIBoxConfig.AKSvnetname -vswitchName $using:HCIBoxConfig.ClusterVSwitchName -vipPoolStart $using:HCIBoxConfig.AKSVIPStartIP -vipPoolEnd $using:HCIBoxConfig.AKSVIPEndIP -vlanID $using:HCIBoxConfig.AKSVlanID
        #Set-MocConfig -workingDir $using:csv_path\ResourceBridge -vnet $vnet -imageDir $using:csv_path\imageStore -skipHostLimitChecks -cloudConfigLocation $using:csv_path\cloudStore -catalog aks-hci-stable-catalogs-ext -ring stable -CloudServiceIP $using:cloudServiceIP -createAutoConfigContainers $false
        Set-MocConfig -workingDir $using:csv_path\ResourceBridge -imageDir $using:csv_path\imageStore -skipHostLimitChecks -cloudConfigLocation $using:csv_path\cloudStore -catalog aks-hci-stable-catalogs-ext -ring stable -CloudServiceIP $using:cloudServiceIP -createAutoConfigContainers $false
        Install-Moc
    }
}

Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-ArcHciConfigFiles -subscriptionID $using:subId -location eastus -resourceGroup $using:rg -resourceName $using:resource_name -workDirectory $using:csv_path\ResourceBridge -vnetName $using:HCIBoxConfig.ClusterVSwitchName -vswitchName $using:HCIBoxConfig.ClusterVSwitchName -ipaddressprefix $using:HCIBoxConfig.AKSIPPrefix -gateway $using:HCIBoxConfig.AKSGWIP -dnsservers $using:HCIBoxConfig.AKSDNSIP -controlPlaneIP $using:HCIBoxConfig.rbCpip -k8snodeippoolstart $using:HCIBoxConfig.rbIp -k8snodeippoolend $using:HCIBoxConfig.rbIp2 -vlanID $using:HCIBoxConfig.AKSVlanID
}

$ErrorActionPreference = "Continue"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Write-Host "Deploying Arc Resource Bridge. This will take a while."
    $WarningPreference = "SilentlyContinue"
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\",[System.EnvironmentVariableTarget]::Machine)
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId
    az provider register -n Microsoft.ResourceConnector --wait
    az arcappliance validate hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --only-show-errors
    az arcappliance prepare hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --only-show-errors
    az arcappliance deploy hci --config-file  $using:csv_path\ResourceBridge\hci-appliance.yaml --outfile $env:USERPROFILE\.kube\config --only-show-errors
    az arcappliance create hci --config-file $using:csv_path\ResourceBridge\hci-appliance.yaml --kubeconfig $env:USERPROFILE\.kube\config --only-show-errors

    $rbReady = $false
    Do {
        Write-Host "Waiting on Arc Resource Bridge deployment to complete..."
        Start-Sleep 60
        $readiness = az arcappliance show --resource-group $using:rg --name $using:resource_name --only-show-errors | ConvertFrom-Json
        if (($readiness.provisioningState -eq "Succeeded") -and ($readiness.status -eq "Connected")) {
            $rbReady = $true
        }
    } Until ($rbReady)
    Write-Host "Arc Resource Bridge deployment complete."

    # Configuring custom location
    Write-Host "Creating custom location"
    $hciClusterId= (Get-AzureStackHci).AzureResourceUri
    az k8s-extension create --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name hci-vmoperator --extension-type Microsoft.AZStackHCI.Operator --scope cluster --release-namespace helm-operator2 --configuration-settings Microsoft.CustomLocation.ServiceAccount=hci-vmoperator --configuration-protected-settings-file $using:csv_path\ResourceBridge\hci-config.json --configuration-settings HCIClusterID=$hciClusterId --auto-upgrade true --only-show-errors

    $clReady = $false
    Do {
        Write-Host "Waiting for custom location to provision..."
        Start-Sleep 10
        $readiness = az k8s-extension show --cluster-type appliances --cluster-name $using:resource_name --resource-group $using:rg --name hci-vmoperator --only-show-errors | ConvertFrom-Json
        if ($readiness.provisioningState -eq "Succeeded") {
            $clReady = $true
        }
    } Until ($clReady)

    az customlocation create --resource-group $using:rg --name $using:custom_location_name --cluster-extension-ids "/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ResourceConnector/appliances/$using:resource_name/providers/Microsoft.KubernetesConfiguration/extensions/hci-vmoperator" --namespace hci-vmoperator --host-resource-id "/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ResourceConnector/appliances/$using:resource_name" --location $using:location --only-show-errors
    Write-Host "Custom location created."
    $WarningPreference = "Continue"
}
$ErrorActionPreference = "Continue"

# Copy gallery VHDs to hosts
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-Item -Name "VHD" -Path $using:csv_path -ItemType Directory -Force
    Move-Item -Path "C:\VHD\GUI.vhdx" -Destination "$using:csv_path\VHD\GUI.vhdx" -Force
    Move-Item -Path "C:\VHD\Ubuntu.vhdx" -Destination "$using:csv_path\VHD\Ubuntu.vhdx" -Force
}

Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $vnetName="vlan200"
    # New-MocGroup -name "Default_Group" -location "MocLocation" ## No longer needed with appliance version 0.2.31
    New-MocVirtualNetwork -name "$vnetName" -group "Default_Group" -tags @{'VSwitch-Name' = "sdnSwitch"} -vlanID $using:HCIBoxConfig.AKSVlanID
    [System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\",[System.EnvironmentVariableTarget]::Machine)
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    az azurestackhci virtualnetwork create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --network-type "Transparent" --name $vnetName --vlan $using:HCIBoxConfig.AKSVlanID --only-show-errors
    
    $galleryImageName = "ubuntu20"
    $galleryImageSourcePath="$using:csv_path\VHD\Ubuntu.vhdx"
    $osType="Linux"
    az azurestackhci galleryimage create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --image-path $galleryImageSourcePath --name $galleryImageName --os-type $osType --only-show-errors

    $galleryImageName = "win2k22"
    $galleryImageSourcePath="$using:csv_path\VHD\GUI.vhdx"
    $osType="Windows"
    az azurestackhci galleryimage create --subscription $using:subId --resource-group $using:rg --extended-location name="/subscriptions/$using:subId/resourceGroups/$using:rg/providers/Microsoft.ExtendedLocation/customLocations/$using:custom_location_name" type="CustomLocation" --location $using:location --image-path $galleryImageSourcePath --name $galleryImageName --os-type $osType --only-show-errors
}

# Set env variable deployResourceBridge to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deployResourceBridge', 'true',[System.EnvironmentVariableTarget]::Machine)
Stop-Transcript
