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

# Downloading and extracting the 3 VMs
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
$sourceFolder = 'https://jumpstartarcbox.blob.core.windows.net/vms'
$sas = "?sv=2020-08-04&ss=bfqt&srt=sco&sp=rlptfx&se=2022-08-30T04:11:11Z&st=2021-07-22T20:11:11Z&spr=https&sig=HfLlCXODFjdANJj%2FIh4ZG%2FQ22x7IIMFp6yoxoiDQp7E%3D"
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFolder/*$sas $vmDir --recursive

# Create the nested VMs
Write-Output "Create Hyper-V VMs"
New-VM -Name ArcBox-Win -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Win.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-Win -Count 2

New-VM -Name ArcBox-SQL -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-SQL.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-SQL -Count 2

New-VM -Name ArcBox-Ubuntu -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "$vmdir\ArcBox-Ubuntu.vhdx" -Path $vmdir -Generation 2 -Switch $switchName
Set-VMFirmware -VMName ArcBox-Ubuntu -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VMProcessor -VMName ArcBox-Ubuntu -Count 2

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Output "Set VM auto start/stop"
Set-VM -Name ArcBox-Win -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-SQL -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name ArcBox-Ubuntu -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Output "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Output "Start VMs"
Start-VM -Name ArcBox-Win
Start-VM -Name ArcBox-SQL
Start-VM -Name ArcBox-Ubuntu

Start-Sleep -Seconds 20
$username = "Administrator"
$password = "ArcDemo123!!"
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr
Invoke-Command -VMName ArcBox-Win -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $cred
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $cred

Start-Sleep -Seconds 5

# Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc enabled servers
Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc enabled servers"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"
$nestedLinuxUsername = "arcdemo"
$nestedLinuxPassword = "ArcDemo123!!"

# Getting the Ubuntu nested VM IP address
Get-VM -Name ArcBox-Ubuntu | Select-Object -ExpandProperty NetworkAdapters | Select-Object IPAddresses | Format-List | Out-File "$agentScript\IP.txt"
$ipFile = "$agentScript\IP.txt"
(Get-Content $ipFile | Select-Object -Skip 2) | Set-Content $ipFile
$string = Get-Content "$ipFile"
$string.split(',')[0] | Set-Content $ipFile
$string = Get-Content "$ipFile"
$string.split('{')[-1] | Set-Content $ipFile
$vmIp = Get-Content "$ipFile"

# Copying the Azure Arc Connected Agent to nested VMs
Write-Output "Copying the Azure Arc onboarding script to the nested VMs"
(Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$resourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModified.ps1"
(Get-Content -path "$agentScript\installArcAgentSQL.ps1" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$myResourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$logAnalyticsWorkspaceName',"'$env:workspaceName'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
(Get-Content -path "$agentScript\installArcAgent.sh" -Raw) -replace '\$spnClientId',"'$env:spnClientId'" -replace '\$spnClientSecret',"'$env:spnClientSecret'" -replace '\$resourceGroup',"'$env:resourceGroup'" -replace '\$spnTenantId',"'$env:spnTenantId'" -replace '\$azureLocation',"'$env:azureLocation'" -replace '\$subscriptionId',"'$env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModified.sh"

Copy-VMFile ArcBox-Win -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath C:\Temp\installArcAgent.ps1 -CreateFullPath -FileSource Host
Copy-VMFile ArcBox-SQL -SourcePath "$agentScript\installArcAgentSQLModified.ps1" -DestinationPath C:\Temp\installArcAgentSQL.ps1 -CreateFullPath -FileSource Host
echo y | pscp -P 22 -pw $nestedLinuxPassword "$agentScript\installArcAgentModified.sh" $nestedLinuxUsername@"$vmIp":/home/"$nestedLinuxUsername"

# Onboarding the nested VMs as Azure Arc enabled servers
Write-Output "Onboarding the nested Windows VMs as Azure Arc enabled servers"
$secstr = New-Object -TypeName System.Security.SecureString
$nestedWindowsPassword.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $nestedWindowsUsername, $secstr

Invoke-Command -VMName ArcBox-Win -ScriptBlock { powershell -File C:\Temp\installArcAgent.ps1 } -Credential $cred
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { powershell -File C:\Temp\installArcAgentSQL.ps1 } -Credential $cred

Write-Output "Onboarding the nested Linux VM as an Azure Arc enabled server"
$secpasswd = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($nestedLinuxUsername, $secpasswd)
$SessionID = New-SSHSession -ComputerName $vmIp -Credential $Credentials -Force #Connect Over SSH
$Command = "sudo chmod +x /home/$nestedLinuxUsername/installArcAgentModified.sh;sudo sh /home/$nestedLinuxUsername/installArcAgentModified.sh"

Invoke-SSHCommand -Index $sessionid.sessionid -Command $Command | Out-Null

# Creating Hyper-V Manager desktop shortcut
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false
