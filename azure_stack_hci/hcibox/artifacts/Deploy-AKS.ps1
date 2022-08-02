Write-Host "Install AKS on HCI Sandbox Cluster"

# Import Configuration Module
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

Write-Host -ForegroundColor Green -Object "Register the Cluster to Azure Subscription"
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

# Required for CLI commands
Write-Host "Az Login"
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$armtoken = Get-AzAccessToken
$graphtoken = Get-AzAccessToken -ResourceTypeName AadGraph

#Set Variables for Install
$aksvar= @{
    HostList="AZSHost1", "AZSHOST2"
    AKSvnetname = "vnet1"
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
    AKSResourceGroupName = "ASHCI-Nested-AKS"
}

##Install AKS onto the Cluster ##

#Install latest versions of Nuget and PowershellGet

  Write-Host "Install latest versions of Nuget and PowershellGet" -ForegroundColor Green -BackgroundColor Black

    Invoke-Command -VMName $aksvar.HostList -Credential $adcred -ScriptBlock {
        Enable-PSRemoting -Force
        Install-PackageProvider -Name NuGet -Force 
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Install-Module -Name PowershellGet -Force
    }
 
    Write-Host -ForegroundColor Green -BackgroundColor Black "Install necessary AZ modules plus AksHCI module and initialize akshci on each node"

    #Install necessary AZ modules plus AksHCI module and initialize akshci on each node
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
    
    #Install AksHci - only need to perform the following on one of the nodes
    Write-Host "Prepping AKS Install" -ForegroundColor Green -BackgroundColor Black
    Invoke-Command -VMName $aksvar.HostList[0] -Credential $adcred -ScriptBlock  {
        $vnet = New-AksHciNetworkSetting -name $using:aksvar.AKSvnetname -vSwitchName $using:aksvar.AKSvSwitchName -k8sNodeIpPoolStart $using:aksvar.AKSNodeStartIP -k8sNodeIpPoolEnd $using:aksvar.AKSNodeEndIP -vipPoolStart $using:aksvar.AKSVIPStartIP -vipPoolEnd $using:aksvar.AKSVIPEndIP -ipAddressPrefix $using:aksvar.AKSIPPrefix -gateway $using:aksvar.AKSGWIP -dnsServers $using:aksvar.AKSDNSIP -vlanID $aksvar.vlanid        
        Set-AksHciConfig -imageDir $using:aksvar.AKSImagedir -workingDir $using:aksvar.AKSWorkingdir -cloudConfigLocation $using:aksvar.AKSCloudConfigdir -vnet $vnet -cloudservicecidr $using:aksvar.AKSCloudSvcidr 
        Set-AksHciRegistration -subscriptionId $env:subscriptionId -resourceGroupName $using:aksvar.AKSResourceGroupName -AccountId $env:spnClientID -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token
        Write-Host -ForegroundColor Green -Object "Ready to Install AKS on HCI Cluster"
        Install-AksHci 
    }
