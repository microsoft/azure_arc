$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$connectedClusterName=$Env:capiArcDataClusterName

Start-Transcript -Path $Env:ArcBoxLogsDir\DataOpsLogonScript.log

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".dataops" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Header "Downloading CAPI K8s Kubeconfig"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config"
$context = (Get-AzStorageAccount -ResourceGroupName $Env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$Env:USERNAME\.kube\config"

# Downloading 'installCAPI.log' log file
Write-Header "Downloading CAPI Install Logs"
$sourceFile = "https://$Env:stagingStorageAccountName.blob.core.windows.net/staging-capi/installCAPI.log"
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$Env:ArcBoxLogsDir\installCAPI.log"

# Merging kubeconfig files from CAPI and AKS
Write-Header "Merging CAPI & AKS Kubeconfigs"
Copy-Item -Path "C:\Users\$Env:USERNAME\.kube\config" -Destination "C:\Users\$Env:USERNAME\.kube\config.backup"
$Env:KUBECONFIG="C:\Users\$Env:USERNAME\.kube\config;"
kubectl config view --raw > C:\users\$Env:USERNAME\.kube\config_tmp
kubectl config get-clusters --kubeconfig=C:\users\$Env:USERNAME\.kube\config_tmp
Remove-Item -Path "C:\Users\$Env:USERNAME\.kube\config"
Move-Item -Path "C:\Users\$Env:USERNAME\.kube\config_tmp" -Destination "C:\users\$Env:USERNAME\.kube\config"
$Env:KUBECONFIG="C:\users\$Env:USERNAME\.kube\config"
### ************** Get AKS clusters' kubeconfigs
kubectx


# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait


################################################
# - Created Nested SQL VM
################################################

Write-Header "Creating Nested SQL VM"

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Host "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object {$_.InterfaceAlias -eq "Ethernet" }
Add-DhcpServerv4Scope -Name "ArcBox" `
                      -StartRange 10.10.1.100 `
                      -EndRange 10.10.1.200 `
                      -SubnetMask 255.255.255.0 `
                      -LeaseDuration 1.00:00:00 `
                      -State Active
Set-DhcpServerv4OptionValue -ComputerName localhost `
                            -DnsDomain $dnsClient.ConnectionSpecificSuffix `
                            -DnsServer 10.16.2.100 `
                            -Router 10.10.1.1
Restart-Service dhcpserver

# Create the NAT network
Write-Host "Creating Internal NAT"
$natName = "InternalNat"
New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24

# Create an internal switch with NAT
Write-Host "Creating Internal vSwitch"
$switchName = 'InternalNATSwitch'
New-VMSwitch -Name $switchName -SwitchType Internal
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*"+$switchName+"*" }

# Create an internal network (gateway first)
Write-Host "Creating Gateway"
New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Enable Enhanced Session Mode on Host
Write-Host "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

Write-Host "Fetching Nested VMs"
$sourceFolder = 'https://jumpstart.blob.core.windows.net/v2images'
$sas = "?sp=rl&st=2022-01-27T01:47:01Z&se=2025-01-27T09:47:01Z&spr=https&sv=2020-08-04&sr=c&sig=NB8g7f4JT3IM%2FL6bUfjFdmnGIqcc8WU015socFtkLYc%3D"
$Env:AZCOPY_BUFFER_GB=4
Write-Output "Downloading nested VMs VHDX file for SQL. This can take some time, hold tight..."
azcopy cp "$sourceFolder/ArcBox-SQL.vhdx$sas" "$Env:ArcBoxVMDir\ArcBox-SQL.vhdx" --check-length=false --log-level=ERROR


# Create the nested SQL VM
Write-Host "Create Hyper-V VMs"
New-VM -Name ArcBox-SQL -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$Env:ArcBoxVMDir\ArcBox-SQL.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-SQL -Count 2

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Host "Set VM Auto Start/Stop"
Set-VM -Name ArcBox-SQL -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Host "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Host "Starting SQL VM"
Start-VM -Name ArcBox-SQL


Write-Host "Creating VM Credentials"
# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

# Restarting Windows VM Network Adapters
Write-Host "Restarting Network Adapters"
Start-Sleep -Seconds 20
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Start-Sleep -Seconds 5

# Configuring the local SQL VM
Write-Host "Setting local SQL authentication and adding a SQL login"
$localSQLUser= $Env:AZDATA_USERNAME
$localSQLPassword = $Env:AZDATA_PASSWORD
Invoke-Command -VMName ArcBox-SQL -Credential $winCreds -ScriptBlock {
    Install-Module -Name SqlServer -AllowClobber -Force
    $server = "localhost"
    $user = $Using:localSQLUser
    $LoginType = "SqlLogin"
    $pass = ConvertTo-SecureString -String $Using:localSQLPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pass
    Add-SqlLogin -ServerInstance $Server -LoginName $User -LoginType $LoginType -DefaultDatabase AdventureWorksLT2019 -Enable -GrantConnectSql -LoginPSCredential $Credential
    $svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
    $svr.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
    $svr.Alter()
    Restart-Service -Force MSSQLSERVER
    $svrole = $svr.Roles | where {$_.Name -eq 'sysadmin'}
    $svrole.AddMember($user)
    }

# Creating Hyper-V Manager desktop shortcut
Write-Host "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force