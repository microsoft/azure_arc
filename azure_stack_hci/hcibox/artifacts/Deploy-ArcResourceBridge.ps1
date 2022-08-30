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

# Install AZ Resource Bridge
Write-Host "Now Preparing to Install Azure Arc Resource Bridge" -ForegroundColor Black -BackgroundColor Green 

# Install Required Modules
foreach ($VM in $SDNConfig.HostList) { 
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
    }
}

Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Install-PackageProvider -Name NuGet -Force 
    Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck
    Install-Module -Name ArcHci -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense

    #Install Required Extensions
    # az extension remove --name arcappliance
    # az extension remove --name connectedk8s
    # az extension remove --name k8s-configuration
    # az extension remove --name k8s-extension
    # az extension remove --name customlocation
    # az extension remove --name azurestackhci
    az extension add --upgrade --name arcappliance
    az extension add --upgrade --name connectedk8s
    az extension add --upgrade --name k8s-configuration
    az extension add --upgrade --name k8s-extension
    az extension add --upgrade --name customlocation
    az extension add --upgrade --name azurestackhci

    $csv_path = "C:\ClusterStorage\S2D_vDISK1"
    $resource_name = "HCIBox-ResourceBridge"

    New-Item -Path $csv_path -Name "ResourceBridge" -ItemType Directory
}

$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $csv_path = "C:\ClusterStorage\S2D_vDISK1"
    $resource_name = "hcibox-arcbridge"
    New-ArcHciConfigFiles -subscriptionId $using:subId -location eastus -resourceGroup $using:rg -resourceName $resource_name -workDirectory $csv_path\ResourceBridge -controlPlaneIP $using:aksvar.rbCpip  -k8snodeippoolstart $using:aksvar.rbIp -k8snodeippoolend $using:aksvar.rbIp -gateway $using:aksvar.AKSGWIP -dnsservers $using:aksvar.AKSDNSIP -ipaddressprefix $using:aksvar.AKSIPPrefix   
}

Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $csv_path = "C:\ClusterStorage\S2D_vDISK1"
    az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId
    az provider register -n Microsoft.ResourceConnector --wait
    az arcappliance validate hci --config-file $csv_path\ResourceBridge\hci-appliance.yaml
}
    #start-sleep 60
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $csv_path = "C:\ClusterStorage\S2D_vDISK1"
    az arcappliance prepare hci --config-file $csv_path\ResourceBridge\hci-appliance.yaml

    #Start-Sleep 60
    az arcappliance deploy hci --config-file  $csv_path\ResourceBridge\hci-appliance.yaml --outfile $env:USERPROFILE\.kube\config

    #Start-Sleep 60
    az arcappliance create hci --config-file $csv_path\ResourceBridge\hci-appliance.yaml --kubeconfig $env:USERPROFILE\.kube\config

}

Stop-Transcript