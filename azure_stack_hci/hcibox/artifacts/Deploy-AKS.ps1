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

Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-AKS.log

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$context = Get-AzContext # Azure credential

# Install latest versions of Nuget and PowershellGet
Write-Header "Install latest versions of Nuget and PowershellGet"
Invoke-Command -VMName $SDNConfig.HostList -Credential $adcred -ScriptBlock {
    Enable-PSRemoting -Force
    Install-PackageProvider -Name NuGet -Force 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module -Name PowershellGet -Force
}

# Install necessary AZ modules and initialize akshci on each node
Write-Header "Install necessary AZ modules plus AksHCI module and initialize akshci on each node"

Invoke-Command -VMName $SDNConfig.HostList  -Credential $adcred -ScriptBlock {
    Write-Host "Installing Required Modules" -ForegroundColor Green -BackgroundColor Black
    
    $ModuleNames="Az.Resources","Az.Accounts", "AzureAD", "AKSHCI"
    foreach ($ModuleName in $ModuleNames){
        if (!(Get-InstalledModule -Name $ModuleName -ErrorAction Ignore)){
            Install-Module -Name $ModuleName -Force -AcceptLicense 
        }
    }
    Import-Module Az.Accounts
    Import-Module Az.Resources
    Import-Module AzureAD
    Import-Module AksHci
    Initialize-AksHciNode
}

# Install AksHci - only need to perform the following on one of the nodes
$rg = $env:resourceGroup
Write-Header "Prepping AKS Install"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    $vnet = New-AksHciNetworkSetting -name $using:SDNConfig.AKSvnetname -vSwitchName $using:SDNConfig.AKSvSwitchName -k8sNodeIpPoolStart $using:SDNConfig.AKSNodeStartIP -k8sNodeIpPoolEnd $using:SDNConfig.AKSNodeEndIP -vipPoolStart $using:SDNConfig.AKSVIPStartIP -vipPoolEnd $using:SDNConfig.AKSVIPEndIP -ipAddressPrefix $using:SDNConfig.AKSIPPrefix -gateway $using:SDNConfig.AKSGWIP -dnsServers $using:SDNConfig.AKSDNSIP -vlanID $using:SDNConfig.AKSVlanID        
    Set-AksHciConfig -imageDir $using:SDNConfig.AKSImagedir -workingDir $using:SDNConfig.AKSWorkingdir -cloudConfigLocation $using:SDNConfig.AKSCloudConfigdir -vnet $vnet -cloudservicecidr $using:SDNConfig.AKSCloudSvcidr -controlPlaneVmSize Standard_D4s_v3
    $azurecred = Connect-AzAccount -ServicePrincipal -Subscription $using:context.Subscription.Id -Tenant $using:context.Subscription.TenantId -Credential $using:azureAppCred
    Set-AksHciRegistration -subscriptionId $azurecred.Context.Subscription.Id -resourceGroupName $using:rg -Tenant $azurecred.Context.Tenant.Id -Credential $using:azureAppCred -environmentName "hciboxcloudenv"
    Write-Host "Ready to Install AKS on HCI Cluster"
    Uninstall-AksHci 
}

# Create new AKS workload cluster and connect it to Azure
Write-Header "Creating AKS workload cluster"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    New-AksHciCluster -name "hcibox-aks" -nodePoolName linuxnodepool -nodecount 1 -osType linux
    Enable-AksHciArcConnection -name "hcibox-aks"
}

# Commenting until we can workaround the lack of -Force/confirm
Write-Header "Checking AKS-HCI nodes and running pods"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Get-AksHciCredential -name "hcibox-aks" -Confirm:$false
    kubectl get nodes
    kubectl get pods -A
}

Stop-Transcript