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
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$context = Get-AzContext # Azure credential

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes -Confirm:$false
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration -Confirm:$false

# Install latest versions of Nuget and PowershellGet
Write-Header "Install latest versions of Nuget and PowershellGet"
Invoke-Command -VMName $HCIBoxConfig.HostList -Credential $adcred -ScriptBlock {
    Enable-PSRemoting -Force
    $ProgressPreference = "SilentlyContinue"
    Install-PackageProvider -Name NuGet -Force 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module -Name PowershellGet -Force
    $ProgressPreference = "Continue"
}

# Install necessary AZ modules and initialize akshci on each node
Write-Header "Install necessary AZ modules plus AksHCI module and initialize akshci on each node"

Invoke-Command -VMName $HCIBoxConfig.HostList  -Credential $adcred -ScriptBlock {
    Write-Host "Installing Required Modules"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"
    Install-Module -Name AksHci -Force -AcceptLicense
    Import-Module Az.Accounts -DisableNameChecking
    Import-Module Az.Resources -DisableNameChecking
    Import-Module AzureAD -DisableNameChecking
    Import-Module AksHci -DisableNameChecking
    Initialize-AksHciNode
    $ProgressPreference = "Continue"
}

# Generate unique name for workload cluster
$rand = New-Object System.Random
$prefixLen = 5
[string]$namingPrefix = ''
for($i = 0; $i -lt $prefixLen; $i++)
{
    $namingPrefix += [char]$rand.Next(97,122)
}
$clusterName = $HCIBoxConfig.AKSworkloadClusterName + "-" + $namingPrefix
#$azureLocation = $env:azureLocation
[System.Environment]::SetEnvironmentVariable('AKSClusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)

# Install AksHci - only need to perform the following on one of the nodes
$rg = $env:resourceGroup
Write-Header "Prepping AKS Install"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    $vnet = New-AksHciNetworkSetting -name $using:HCIBoxConfig.AKSvnetname -vSwitchName $using:HCIBoxConfig.ClusterVSwitchName -k8sNodeIpPoolStart $using:HCIBoxConfig.AKSNodeStartIP -k8sNodeIpPoolEnd $using:HCIBoxConfig.AKSNodeEndIP -vipPoolStart $using:HCIBoxConfig.AKSVIPStartIP -vipPoolEnd $using:HCIBoxConfig.AKSVIPEndIP -ipAddressPrefix $using:HCIBoxConfig.AKSIPPrefix -gateway $using:HCIBoxConfig.AKSGWIP -dnsServers $using:HCIBoxConfig.AKSDNSIP -vlanID $using:HCIBoxConfig.AKSVlanID        
    Set-AksHciConfig -imageDir $using:HCIBoxConfig.AKSImagedir -workingDir $using:HCIBoxConfig.AKSWorkingdir -cloudConfigLocation $using:HCIBoxConfig.AKSCloudConfigdir -vnet $vnet -cloudservicecidr $using:HCIBoxConfig.AKSCloudSvcidr -controlPlaneVmSize Standard_D4s_v3
    $azurecred = Connect-AzAccount -ServicePrincipal -Subscription $using:context.Subscription.Id -Tenant $using:context.Subscription.TenantId -Credential $using:azureAppCred
    Set-AksHciRegistration -subscriptionId $azurecred.Context.Subscription.Id -resourceGroupName $using:rg -Tenant $azurecred.Context.Tenant.Id -Credential $using:azureAppCred -Region "eastus"
    Write-Host "Ready to Install AKS on HCI Cluster"
    Install-AksHci
}

# Create new AKS target cluster and connect it to Azure
Write-Header "Creating AKS target cluster"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    New-AksHciCluster -name $using:clusterName -nodePoolName linuxnodepool -nodecount 2 -osType linux -nodeVmSize Standard_D8s_v3
    Enable-AksHciArcConnection -name $using:clusterName
}

Write-Header "Checking AKS-HCI nodes and running pods"
Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl get nodes
    kubectl get pods -A
}

# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', 'true',[System.EnvironmentVariableTarget]::Machine)

Stop-Transcript