# Set paths
$Env:HciBoxDir = "C:\HciBox"
$Env:HciBoxLogsDir = "C:\HciBox\Logs"
$Env:HciBoxVMDir = "C:\HciBox\Virtual Machines"
$Env:HciBoxKVDir = "C:\HciBox\KeyVault"
$Env:HciBoxGitOpsDir = "C:\HciBox\GitOps"
$Env:HciBoxIconDir = "C:\HciBox\Icons"
$Env:HciBoxVHDDir = "C:\HciBox\VHD"
$Env:HciBoxSDNDir = "C:\HciBox\SDN"
$Env:HciBoxWACDir = "C:\HciBox\Windows Admin Center"
$Env:agentScript = "C:\HciBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

Start-Transcript -Path $Env:HciBoxLogsDir\HciBoxLogonScript.log

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HciBox\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$context = Get-AzContext # Azure credential
$armtoken = Get-AzAccessToken
$graphtoken = Get-AzAccessToken -ResourceTypeName AadGraph

# AKS parameters - recommended to leave default
$aksvar= @{
    HostList="AZSHost1", "AZSHOST2"
    AKSvnetname = "hcibox-vnet"
    AKSvSwitchName = "sdnSwitch"
    AKSNodeStartIP = "192.168.200.25"
    AKSNodeEndIP = "192.168.200.100"
    AKSVIPStartIP = "192.168.200.125"
    AKSVIPEndIP = "192.168.200.200"
    AKSIPPrefix = "192.168.200.0/24"
    AKSGWIP = "192.168.200.1"
    AKSDNSIP = "192.168.1.254"
    AKSCSV="C:\ClusterStorage\S2D_vDISK1"
    AKSImagedir = "C:\ClusterStorage\S2D_vDISK1\aks\Images"
    AKSWorkingdir = "C:\ClusterStorage\S2D_vDISK1\aks\Workdir"
    AKSCloudConfigdir = "C:\ClusterStorage\S2D_vDISK1\aks\CloudConfig"
    AKSCloudSvcidr = "192.168.1.15/24"
    AKSVlanID="200"
    AKSResourceGroupName = "HCIBox-AKS"
}

# Install latest versions of Nuget and PowershellGet
Write-Header "Install latest versions of Nuget and PowershellGet"
Invoke-Command -VMName $aksvar.HostList -Credential $adcred -ScriptBlock {
    Enable-PSRemoting -Force
    Install-PackageProvider -Name NuGet -Force 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module -Name PowershellGet -Force
}

# Install necessary AZ modules and initialize akshci on each node
Write-Header "Install necessary AZ modules plus AksHCI module and initialize akshci on each node"

Invoke-Command -VMName $aksvar.HostList  -Credential $adcred -ScriptBlock {
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
    Initialize-akshcinode
}

# Install AksHci - only need to perform the following on one of the nodes
Write-Header "Prepping AKS Install"
Invoke-Command -VMName $aksvar.HostList[0] -Credential $adcred -ScriptBlock  {
    $vnet = New-AksHciNetworkSetting -name $using:aksvar.AKSvnetname -vSwitchName $using:aksvar.AKSvSwitchName -k8sNodeIpPoolStart $using:aksvar.AKSNodeStartIP -k8sNodeIpPoolEnd $using:aksvar.AKSNodeEndIP -vipPoolStart $using:aksvar.AKSVIPStartIP -vipPoolEnd $using:aksvar.AKSVIPEndIP -ipAddressPrefix $using:aksvar.AKSIPPrefix -gateway $using:aksvar.AKSGWIP -dnsServers $using:aksvar.AKSDNSIP -vlanID $using:aksvar.AKSVlanID        
    Set-AksHciConfig -imageDir $using:aksvar.AKSImagedir -workingDir $using:aksvar.AKSWorkingdir -cloudConfigLocation $using:aksvar.AKSCloudConfigdir -vnet $vnet -cloudservicecidr $using:aksvar.AKSCloudSvcidr 
    $azurecred = Connect-AzAccount -ServicePrincipal -Subscription $using:context.Subscription.Id -Tenant $using:context.Subscription.TenantId -Credential $using:azureAppCred
    Set-AksHciRegistration -subscriptionId $azurecred.Context.Subscription.Id -resourceGroupName $using:aksvar.AKSResourceGroupName -Tenant $azurecred.Context.Tenant.Id -Credential $using:azureAppCred
    Write-Host "Ready to Install AKS on HCI Cluster"
    Install-AksHci 
}

# Create new AKS workload cluster
Write-Header "Creating AKS workload cluster"
Invoke-Command -VMName $aksvar.HostList[0] -Credential $adcred -ScriptBlock  {
    New-AksHciCluster -name "hcibox-aks" -nodePoolName linuxnodepool -nodecount 1 -osType linux
    Get-AksHciCluster
}