Start-Transcript "C:\ArcBox\ArcServersLogonScript.log"

$ArcBoxDir = "C:\ArcBox"
$vmDir = "C:\ArcBox\Virtual Machines"
$agentScript = "C:\ArcBox\agentScript"
$tempDir = "C:\Temp"

Function Set-VMNetworkConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,
                   Position=1,
                   ParameterSetName='DHCP',
                   ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName='Static',
                   ValueFromPipeline=$true)]
        [Microsoft.HyperV.PowerShell.VMNetworkAdapter]$NetworkAdapter,

        [Parameter(Mandatory=$true,
                   Position=1,
                   ParameterSetName='Static')]
        [String[]]$IPAddress=@(),

        [Parameter(Mandatory=$false,
                   Position=2,
                   ParameterSetName='Static')]
        [String[]]$Subnet=@(),

        [Parameter(Mandatory=$false,
                   Position=3,
                   ParameterSetName='Static')]
        [String[]]$DefaultGateway = @(),

        [Parameter(Mandatory=$false,
                   Position=4,
                   ParameterSetName='Static')]
        [String[]]$DNSServer = @(),

        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName='DHCP')]
        [Switch]$Dhcp
    )

    $VM = Get-WmiObject -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' | Where-Object { $_.ElementName -eq $NetworkAdapter.VMName } 
    $VMSettings = $vm.GetRelated('Msvm_VirtualSystemSettingData') | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapters = $VMSettings.GetRelated('Msvm_SyntheticEthernetPortSettingData') 

    $NetworkSettings = @()
    foreach ($NetAdapter in $VMNetAdapters) {
        if ($NetAdapter.Address -eq $NetworkAdapter.MacAddress) {
            $NetworkSettings = $NetworkSettings + $NetAdapter.GetRelated("Msvm_GuestNetworkAdapterConfiguration")
        }
    }

    $NetworkSettings[0].IPAddresses = $IPAddress
    $NetworkSettings[0].Subnets = $Subnet
    $NetworkSettings[0].DefaultGateways = $DefaultGateway
    $NetworkSettings[0].DNSServers = $DNSServer
    $NetworkSettings[0].ProtocolIFType = 4096

    if ($dhcp) {
        $NetworkSettings[0].DHCPEnabled = $true
    } else {
        $NetworkSettings[0].DHCPEnabled = $false
    }

    $Service = Get-WmiObject -Class "Msvm_VirtualSystemManagementService" -Namespace "root\virtualization\v2"
    $setIP = $Service.SetGuestNetworkAdapterConfiguration($VM, $NetworkSettings[0].GetText(1))

    if ($setip.ReturnValue -eq 4096) {
        $job=[WMI]$setip.job 

        while ($job.JobState -eq 3 -or $job.JobState -eq 4) {
            Start-Sleep -Seconds 1
            $job=[WMI]$setip.job
        }

        if ($job.JobState -eq 7) {
            Write-Output "Success"
        }
        else {
            $job.GetError()
        }
    } elseif($setip.ReturnValue -eq 0) {
        Write-Output "Success"
    }
}

# Required for CLI commands
az login --service-principal --username $env:spnClientID --password $env:spnClientSecret --tenant $env:spnTenantId

# Register Azure providers
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.AzureArcData --wait

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Output "Configure DHCP service"
$dnsClient = Get-DnsClient | Where-Object {$_.InterfaceAlias -eq "Ethernet" }
Add-DhcpServerv4Scope -Name "ArcBox" -StartRange 10.10.1.1 -EndRange 10.10.1.254 -SubnetMask 255.0.0.0 -State Active
Add-DhcpServerv4ExclusionRange -ScopeID 10.10.1.0 -StartRange 10.10.1.101 -EndRange 10.10.1.120
Set-DhcpServerv4OptionValue -DnsDomain $dnsClient.ConnectionSpecificSuffix -DnsServer 168.63.129.16
Set-DhcpServerv4OptionValue -OptionID 3 -Value 10.10.1.1 -ScopeID 10.10.1.0
Set-DhcpServerv4Scope -ScopeId 10.10.1.0 -LeaseDuration 1.00:00:00
Set-DhcpServerv4OptionValue -ComputerName localhost -ScopeId 10.10.10.0 -DnsServer 8.8.8.8
Restart-Service dhcpserver

# Create the NAT network
Write-Output "Create internal NAT"
$natName = "InternalNat"
New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.0.0/16

# Create an internal switch with NAT
Write-Output "Create internal switch"
$switchName = 'InternalNATSwitch'
New-VMSwitch -Name $switchName -SwitchType Internal
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*"+$switchName+"*" }

# Create an internal network (gateway first)
Write-Output "Create gateway"
New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Enable Enhanced Session Mode on Host
Write-Output "Enable Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

# Downloading nested VMs VHDX files
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
$sourceFolder = 'https://jumpstart.blob.core.windows.net/testimages'
$sas = "?sv=2020-08-04&ss=bfqt&srt=sco&sp=rltfx&se=2023-08-01T21:00:19Z&st=2021-08-03T13:00:19Z&spr=https&sig=rNETdxn1Zvm4IA7NT4bEY%2BDQwp0TQPX0GYTB5AECAgY%3D"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFolder/*$sas $vmDir --recursive

# Create the nested VMs
Write-Output "Create Hyper-V VMs"
New-VM -Name ArcBox-Win2K19 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Win2K19.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-Win2K19 -Count 2

New-VM -Name ArcBox-Win2K22 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Win2K22.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-Win2K22 -Count 2

New-VM -Name ArcBox-SQL -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-SQL.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-SQL -Count 2

New-VM -Name ArcBox-Ubuntu -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Ubuntu.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMFirmware -VMName ArcBox-Ubuntu -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VMProcessor -VMName ArcBox-Ubuntu -Count 1

New-VM -Name ArcBox-Debian -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Debian.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMFirmware -VMName ArcBox-Debian -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VMProcessor -VMName ArcBox-Debian -Count 1

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Output "Set VM auto start/stop"
Set-VM -Name ArcBox-Win2K19 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-Win2K22 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-SQL -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-Ubuntu -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-Debian -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Output "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Output "Start VMs"
Start-VM -Name ArcBox-Win2K19
Start-VM -Name ArcBox-Win2K22
Start-VM -Name ArcBox-SQL
Start-VM -Name ArcBox-Ubuntu
Start-VM -Name ArcBox-Debian

Start-Sleep -Seconds 20
$username = "Administrator"
$password = "ArcDemo123!!"
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr
Invoke-Command -VMName ArcBox-Win2K19 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $cred
Invoke-Command -VMName ArcBox-Win2K22 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $cred
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $cred

Start-Sleep -Seconds 5

# Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc-enabled servers"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"
$nestedLinuxUsername = "arcdemo"
$nestedLinuxPassword = "ArcDemo123!!"

# Getting the Ubuntu nested VM IP address
Get-VM -Name ArcBox-Ubuntu | Select-Object -ExpandProperty NetworkAdapters | Select-Object IPAddresses | Format-List | Out-File "$agentScript\Ubuntu-IP.txt"
$UbuntuIP = "$agentScript\Ubuntu-IP.txt"
(Get-Content $UbuntuIP | Select-Object -Skip 2) | Set-Content $UbuntuIP
$string = Get-Content "$UbuntuIP"
$string.split(',')[0] | Set-Content $UbuntuIP
$string = Get-Content "$UbuntuIP"
$string.split('{')[-1] | Set-Content $UbuntuIP
$UbuntuVmIp = Get-Content "$UbuntuIP"

# Getting the Debian nested VM IP address
Get-VM -Name ArcBox-Debian | Select-Object -ExpandProperty NetworkAdapters | Select-Object IPAddresses | Format-List | Out-File "$agentScript\Debian-IP.txt"
$DebianIP = "$agentScript\Debian-IP.txt"
(Get-Content $DebianIP | Select-Object -Skip 2) | Set-Content $DebianIP
$string = Get-Content "$DebianIP"
$string.split(',')[0] | Set-Content $DebianIP
$string = Get-Content "$DebianIP"
$string.split('{')[-1] | Set-Content $DebianIP
$DebianVmIp = Get-Content "$DebianIP"

# Copying the Azure Arc Connected Agent to nested VMs
Write-Output "Copying the Azure Arc onboarding script to the nested VMs"
(Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$resourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModified.ps1"
# (Get-Content -path "$agentScript\installArcAgentSQL.ps1" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$myResourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$logAnalyticsWorkspaceName',"'$env:workspaceName'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
(Get-Content -path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$resourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"
(Get-Content -path "$agentScript\installArcAgentDebian.sh" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$resourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedDebian.sh"

Copy-VMFile ArcBox-Win2K19 -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath C:\Temp\installArcAgent.ps1 -CreateFullPath -FileSource Host
Copy-VMFile ArcBox-Win2K22 -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath C:\Temp\installArcAgent.ps1 -CreateFullPath -FileSource Host
Copy-VMFile ArcBox-SQL -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath C:\Temp\installArcAgent.ps1 -CreateFullPath -FileSource Host
Write-Output y | pscp -P 22 -pw $nestedLinuxPassword "$agentScript\installArcAgentModifiedUbuntu.sh" $nestedLinuxUsername@"$UbuntuVmIp":/home/"$nestedLinuxUsername"
Write-Output y | pscp -P 22 -pw $nestedLinuxPassword "$agentScript\installArcAgentModifiedDebian.sh" $nestedLinuxUsername@"$DebianVmIp":/home/"$nestedLinuxUsername"

# Onboarding the nested VMs as Azure Arc-enabled servers
Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
$secstr = New-Object -TypeName System.Security.SecureString
$nestedWindowsPassword.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $nestedWindowsUsername, $secstr

Invoke-Command -VMName ArcBox-Win2K19 -ScriptBlock { powershell -File C:\Temp\installArcAgent.ps1 } -Credential $cred
Invoke-Command -VMName ArcBox-Win2K22 -ScriptBlock { powershell -File C:\Temp\installArcAgent.ps1 } -Credential $cred
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { powershell -File C:\Temp\installArcAgent.ps1 } -Credential $cred

Write-Output "Onboarding the nested Linux VMs as an Azure Arc-enabled servers"
# Converting Linux credentials to secure string  
$secpasswd = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($nestedLinuxUsername, $secpasswd)

$SessionID = New-SSHSession -ComputerName $UbuntuVmIp -Credential $Credentials -Force -WarningAction SilentlyContinue #Connect Over SSH
$Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
Invoke-SSHCommand -Index $sessionid.sessionid -Command $Command -Timeout 120 -WarningAction SilentlyContinue | Out-Null

# Onboarding nested Debian server VM
$SessionID = New-SSHSession -ComputerName $DebianVmIp -Credential $Credentials -Force -WarningAction SilentlyContinue #Connect Over SSH
$Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedDebian.sh"
Invoke-SSHCommand -Index $sessionid.sessionid -Command $Command -TimeOut 120 -WarningAction SilentlyContinue | Out-Null

# Sending deployement status message to Azure storage account queue
if ($env:flavor -eq "ITPro") {
    # Sleeping for allowing Azure Resource Manager API updates
    Start-Sleep -Seconds 30
    & "C:\ArcBox\DeploymentStatus.ps1"
}

# Creating Hyper-V Manager desktop shortcut
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force


# Changing to Jumpstart ArcBox wallpaper
if ($env:flavor -eq "ITPro") {
$imgPath="C:\ArcBox\wallpaper.png"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)
}
# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false
