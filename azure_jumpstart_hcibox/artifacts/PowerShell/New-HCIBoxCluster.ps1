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

# Formerly a parameter
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'


Start-Transcript -Path $Env:HCIBoxLogsDir\New-HCIBoxCluster.log
$starttime = Get-Date

# Import Configuration data file
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

#region functions

function BITSRequest {
    param (
        [Parameter(Mandatory=$True)]
        [hashtable]$Params
    )
    $url = $Params['Uri']
    $filename = $Params['Filename']
    $download = Start-BitsTransfer -Source $url -Destination $filename -Asynchronous
    $ProgressPreference = "Continue"
    while ($download.JobState -ne "Transferred") {
        if ($download.JobState -eq "TransientError"){
            Get-BitsTransfer $download.name | Resume-BitsTransfer -Asynchronous
        }
        [int] $dlProgress = ($download.BytesTransferred / $download.BytesTotal) * 100;
        Write-Progress -Activity "Downloading File $filename..." -Status "$dlProgress% Complete:" -PercentComplete $dlProgress; 
    }
    Complete-BitsTransfer $download.JobId
    Write-Progress -Activity "Downloading File $filename..." -Status "Ready" -Completed
    $ProgressPreference = "SilentlyContinue"
}
    
function New-InternalSwitch {
    param (
        $pswitchname, 
        $HCIBoxConfig
    )
    
    $querySwitch = Get-VMSwitch -Name $pswitchname -ErrorAction Ignore
    if (!$querySwitch) {
        New-VMSwitch -SwitchType Internal -MinimumBandwidthMode None -Name $pswitchname | Out-Null
    
        #Assign IP to Internal Switch
        $InternalAdapter = Get-Netadapter -Name "vEthernet ($pswitchname)"
        $IP = $HCIBoxConfig.PhysicalHostInternalIP
        $Prefix = ($HCIBoxConfig.AzSMGMTIP.Split("/"))[1]
        $Gateway = $HCIBoxConfig.SDNLABRoute
        $DNS = $HCIBoxConfig.SDNLABDNS
        
        $params = @{
            AddressFamily  = "IPv4"
            IPAddress      = $IP
            PrefixLength   = $Prefix
            DefaultGateway = $Gateway
        }
    
        $InternalAdapter | New-NetIPAddress @params | Out-Null
        $InternalAdapter | Set-DnsClientServerAddress -ServerAddresses $DNS | Out-Null
    }
    else { 
        Write-Verbose "Internal Switch $pswitchname already exists. Not creating a new internal switch." 
    } 
}

function GenerateAnswerFile {
    Params(
        $Hostname,
        $IsMgmtVM,
        $IPAddress,
        $VMMac,
        $HCIBoxConfig
    )
    $azsmgmtProdKey = ""
    if ($IsMgmtVM) {
        $azsmgmtProdKey = "<ProductKey>$($HCIBoxConfig.GUIProductKey)</ProductKey>"
    }
    $UnattendXML = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
<settings pass="specialize">
<component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
<PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
<PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
</component>
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<ComputerName>$Hostname</ComputerName>
$azsmgmtProdKey
</component>
<component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<fDenyTSConnections>false</fDenyTSConnections>
</component>
<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<UserLocale>en-us</UserLocale>
<UILanguage>en-us</UILanguage>
<SystemLocale>en-us</SystemLocale>
<InputLocale>en-us</InputLocale>
</component>
<component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<IEHardenAdmin>false</IEHardenAdmin>
<IEHardenUser>false</IEHardenUser>
</component>
<component name="Microsoft-Windows-TCPIP" processorArchitecture="wow64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<Interfaces>
<Interface wcm:action="add">
<Identifier>$VMMac</Identifier>
<Ipv4Settings>
<DhcpEnabled>false</DhcpEnabled>
</Ipv4Settings>
<UnicastIpAddresses>
<IpAddress wcm:action="add" wcm:keyValue="1">$IPAddress</IpAddress>
</UnicastIpAddresses>
<Routes>
<Route wcm:action="add">
<Identifier>1</Identifier>
<NextHopAddress>$($HCIBoxConfig.SDNLABRoute)</NextHopAddress>
<Prefix>0.0.0.0/0</Prefix>
<Metric>100</Metric>
</Route>
</Routes>
</Interface>
</Interfaces>
</component>
<component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<DNSSuffixSearchOrder>
<DomainName wcm:action="add" wcm:keyValue="1">$($HCIBoxConfig.SDNDomainFQDN)</DomainName>
</DNSSuffixSearchOrder>
<Interfaces>
<Interface wcm:action="add">
<DNSServerSearchOrder>
<IpAddress wcm:action="add" wcm:keyValue="1">$($HCIBoxConfig.SDNLABDNS)</IpAddress>
</DNSServerSearchOrder>
<Identifier>$VMMac</Identifier>
<DisableDynamicUpdate>false</DisableDynamicUpdate>
<DNSDomain>$($HCIBoxConfig.SDNDomainFQDN)</DNSDomain>
<EnableAdapterDomainNameRegistration>true</EnableAdapterDomainNameRegistration>
</Interface>
</Interfaces>
</component>
</settings>
<settings pass="oobeSystem">
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<OOBE>
<HideEULAPage>true</HideEULAPage>
<SkipMachineOOBE>true</SkipMachineOOBE>
<SkipUserOOBE>true</SkipUserOOBE>
<HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
    </OOBE>
<UserAccounts>
<AdministratorPassword>
<Value>$($HCIBoxConfig.SDNAdminPassword)</Value>
<PlainText>true</PlainText>
</AdministratorPassword>
</UserAccounts>
</component>
</settings>
<cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@
    return $UnattendXML
}


function New-ManagementVM {
    Param (
        $Name,
        $VHDXPath,
        $VMSwitch,
        $HCIBoxConfig
    )
    Write-Host "Creating VM $Name"
    # Create disks
    $VHDX1 = New-VHD -ParentPath $VHDXPath -Path "$($HCIBoxConfig.HostVMPath)\$Name.vhdx" -Differencing 
    $VHDX2 = New-VHD -Path "$($HCIBoxConfig.HostVMPath)\$Name-Data.vhdx" -SizeBytes 268435456000 -Dynamic

    # Create VM
    # Create Nested VM
    New-VM -Name $Name -MemoryStartupBytes $HCIBoxConfig.AzSMGMTMemoryinGB -VHDPath $VHDX1.Path -SwitchName $VMSwitch -Generation 2
    Add-VMHardDiskDrive -VMName $Name -Path $VHDX2.Path
    Set-VM -Name $Name -ProcessorCount $HCIBoxConfig.AzSMGMTProcCount -AutomaticStartAction Start

    Get-VMNetworkAdapter -VMName $Name | Rename-VMNetworkAdapter -NewName "SDN"
    Get-VMNetworkAdapter -VMName $Name | Set-VMNetworkAdapter -DeviceNaming On -StaticMacAddress  ("{0:D12}" -f ( Get-Random -Minimum 0 -Maximum 99999 ))
    Add-VMNetworkAdapter -VMName $Name -Name SDN2 -DeviceNaming On -SwitchName $VMSwitch
    $vmMac = ((Get-VMNetworkAdapter -Name SDN -VMName $Name).MacAddress) -replace '..(?!$)', '$&-'
    Write-Verbose "Virtual Machine FABRIC NIC MAC is = $vmMac"

    Get-VM $Name | Set-VMProcessor -ExposeVirtualizationExtensions $true
    Get-VM $Name | Set-VMMemory -DynamicMemoryEnabled $false
    Get-VM $Name | Get-VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing On

    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName SDN -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200
    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName SDN2 -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200  

    Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"
    Write-Host "VM $Name MAC address is $vmMac"
    return $vmMac
}

function New-HCINodeVM {
    param (
        $Name,
        $VHDXPath,
        $VMSwitch,
        $HCIBoxConfig
    )
    Write-Host "Creating VM $Name"
    # Create disks
    $VHDX1 = New-VHD -ParentPath $VHDXPath -Path "$($HCIBoxConfig.HostVMPath)\$Name.vhdx" -Differencing 
    $VHDX2 = New-VHD -Path "$($HCIBoxConfig.HostVMPath)\$Name-Data.vhdx" -SizeBytes 268435456000 -Dynamic

    # Create S2D Storage       
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk1.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk2.vhdx.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk3.vhdx.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk4.vhdx.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk5.vhdx.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null
    New-VHD -Path "$HostVMPath\$Name-S2D_Disk6.vhdx.vhdx" -SizeBytes $HCIBoxConfig.S2D_Disk_Size -Dynamic | Out-Null  

    # Create Nested VM
    New-VM -Name $Name -MemoryStartupBytes $HCIBoxConfig.NestedVMMemoryinGB -VHDPath $VHDXPath -SwitchName $VMSwitch -Generation 2 | Out-Null
    Add-VMHardDiskDrive -VMName $Name -Path $VHDX2.Path
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk1.vhdx" -VMName $Name | Out-Null
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk2.vhdx" -VMName $Name | Out-Null
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk3.vhdx" -VMName $Name | Out-Null
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk4.vhdx" -VMName $Name | Out-Null
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk5.vhdx" -VMName $Name | Out-Null
    Add-VMHardDiskDrive -Path "$HostVMPath\$Name-S2D_Disk6.vhdx" -VMName $Name | Out-Null

    Set-VM -Name $Name -ProcessorCount 20 -AutomaticStartAction Start
    Get-VMNetworkAdapter -VMName $Name | Rename-VMNetworkAdapter -NewName "SDN"
    Get-VMNetworkAdapter -VMName $Name | Set-VMNetworkAdapter -DeviceNaming On -StaticMacAddress  ("{0:D12}" -f ( Get-Random -Minimum 0 -Maximum 99999 ))
    Add-VMNetworkAdapter -VMName $Name -Name SDN2 -DeviceNaming On -SwitchName $VMSwitch
    $vmMac = ((Get-VMNetworkAdapter -Name SDN -VMName $Name).MacAddress) -replace '..(?!$)', '$&-'
    Write-Verbose "Virtual Machine FABRIC NIC MAC is = $vmMac"

    Add-VMNetworkAdapter -VMName $AzSHOST -SwitchName $VMSwitch -DeviceNaming On -Name StorageA
    Add-VMNetworkAdapter -VMName $AzSHOST -SwitchName $VMSwitch -DeviceNaming On -Name StorageB

    Get-VM $Name | Set-VMProcessor -ExposeVirtualizationExtensions $true
    Get-VM $Name | Set-VMMemory -DynamicMemoryEnabled $false
    Get-VM $Name | Get-VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing On

    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName SDN -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200
    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName SDN2 -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200  
    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName StorageA -Access -VlanId $HCIBoxConfig.StorageAVLAN 
    Set-VMNetworkAdapterVlan -VMName $Name -VMNetworkAdapterName StorageB -Access -VlanId $HCIBoxConfig.StorageBVLAN 

    Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"
    Write-Host "VM $Name MAC address is $vmMac"
    return $vmMac
}

function Set-MGMTVHDX {
    param (
        $VMMac,
        $HCIBoxConfig
    )
    $DriveLetter = $($HCIBoxConfig.HostVMPath).Split(':')
    $path = (("\\$($HCIBoxConfig.MgmtHostConfig.HostName)\") + ($DriveLetter[0] + "$") + ($DriveLetter[1]) + "\" + $($HCIBoxConfig.MgmtHostConfig.HostName) + ".vhdx") 
    Write-Host "Performing offline installation of Hyper-V to management VM at path $path"
    Install-WindowsFeature -Vhd $path -Name Hyper-V, RSAT-Hyper-V-Tools, Hyper-V-Powershell -Confirm:$false | Out-Null
    Start-Sleep -Seconds 20

    # Mount VHDX - bunch of kludgey logic in here to deal with different partition layouts on the GUI and HCI VHD images
    Write-Verbose "Mounting VHDX file at $path"
    [string]$MountedDrive = ""
    $partition = Mount-VHD -Path $path -Passthru | Get-Disk | Get-Partition -PartitionNumber 3
    if (!$partition.DriveLetter) {
        $MountedDrive = "X"
        $partition | Set-Partition -NewDriveLetter $MountedDrive
    }  
    else {
        $MountedDrive = $partition.DriveLetter
    }

    # Inject Answer File
    Write-Host "Injecting answer file to $path"
    $UnattendXML = GenerateAnswerFile -HostName $($HCIBoxConfig.MgmtHostConfig.HostName) -IsMgmtVM $true -IPAddress $HCIBoxConfig.AzSMGMTIP -VMMac $VMMac -HCIBoxConfig $HCIBoxConfig
    
    Write-Host "Mounted Disk Volume is: $MountedDrive" 
    $PantherDir = Get-ChildItem -Path ($MountedDrive + ":\Windows")  -Filter "Panther"
    if (!$PantherDir) { New-Item -Path ($MountedDrive + ":\Windows\Panther") -ItemType Directory -Force | Out-Null }

    Set-Content -Value $UnattendXML -Path ($MountedDrive + ":\Windows\Panther\Unattend.xml") -Force

    # Creating folder structure on AzSMGMT
    Write-Host "Creating VMs\Base folder structure on $($HCIBoxConfig.MgmtHostConfig.HostName)"
    New-Item -Path ($MountedDrive + ":\VMs\Base") -ItemType Directory -Force | Out-Null

    # Injecting configs into VMs
    Write-Verbose "Injecting files into $path"
    Copy-Item -Path "$Env:HCIBoxDir\HCIBox-Config.psd1" -Destination ($MountedDrive + ":\") -Recurse -Force
    #New-Item -Path ($MountedDrive + ":\") -Name VMConfigs -ItemType Directory -Force | Out-Null
    Copy-Item -Path $guiVHDXPath -Destination ($MountedDrive + ":\VMs\Base\GUI.vhdx") -Force
    Copy-Item -Path $azSHCIVHDXPath -Destination ($MountedDrive + ":\VMs\Base\AzSHCI.vhdx") -Force
    #Copy-Item -Path $Env:HCIBoxSDNDir -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force
    #Copy-Item -Path $Env:HCIBoxSDNDir -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force
    #Copy-Item -Path $Env:HCIBoxWACDir -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force  

    # Dismount VHDX
    Write-Verbose "Dismounting VHDX File at path $path"
    Dismount-VHD $path 
}

function Set-HCINodeVHDX {
    param (
        $Hostname,
        $IPAddress,
        $VMMac,
        $HCIBoxConfig
    )
    $DriveLetter = $($HCIBoxConfig.HostVMPath).Split(':')
    $path = (("\\$Hostname\") + ($DriveLetter[0] + "$") + ($DriveLetter[1]) + "\" + $Hostname + ".vhdx") 
    Write-Host "Mounting VHDX file at $path"
    $partition = Mount-VHD -Path $path -Passthru | Get-Disk | Get-Partition -PartitionNumber 3
    if (!$partition.DriveLetter) {
        $MountedDrive = "Y"
        $partition | Set-Partition -NewDriveLetter $MountedDrive
    }   
    else {
        $MountedDrive = $partition.DriveLetter
    }

    Write-Host "Injecting answer file to $path"
    $UnattendXML = GenerateAnswerFile -HostName $Hostname -IsMgmtVM $false -IPAddress $IPAddress -VMMac $VMMac -HCIBoxConfig $HCIBoxConfig
    Write-Host "Mounted Disk Volume is: $MountedDrive" 
    $PantherDir = Get-ChildItem -Path ($MountedDrive + ":\Windows")  -Filter "Panther"
    if (!$PantherDir) { New-Item -Path ($MountedDrive + ":\Windows\Panther") -ItemType Directory -Force | Out-Null }
    Set-Content -Value $UnattendXML -Path ($MountedDrive + ":\Windows\Panther\Unattend.xml") -Force

    New-Item -Path ($MountedDrive + ":\VHD") -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$Env:HCIBoxVHDDir\GUI.vhdx" -Destination ($MountedDrive + ":\VHD") -Recurse -Force            
    Copy-Item -Path "$Env:HCIBoxVHDDir\Ubuntu.vhdx" -Destination ($MountedDrive + ":\VHD") -Recurse -Force

    # Dismount VHDX
    Write-Verbose "Dismounting VHDX File at path $path"
    Dismount-VHD $path  
}
    
function New-DataDrive {
    param (
        $VMPlacement, 
        $HCIBoxConfig
    )

    foreach ($SDNVM in $VMPlacement) {      
        Invoke-Command -ComputerName $SDNVM.VMHost  -ScriptBlock {
            $VerbosePreference = "Continue"
            Write-Verbose "Onlining, partitioning, and formatting Data Drive on $($Using:SDNVM.AzSHOST)"
            $localCred = new-object -typename System.Management.Automation.PSCredential -argumentlist "Administrator" `
                , (ConvertTo-SecureString $using:SDNConfig.SDNAdminPassword   -AsPlainText -Force)   

            Invoke-Command -VMName $using:SDNVM.AzSHOST -Credential $localCred -ScriptBlock {
                Set-Disk -Number 1 -IsOffline $false | Out-Null
                Initialize-Disk -Number 1 | Out-Null
                New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter | Out-Null
                Format-Volume -DriveLetter D | Out-Null         
            }                      
        }
    }    
}

function Set-DataDrives {
    param (
        $HCIBoxConfig,
        [PSCredential]$Credential
    )
    $VMs = @()
    $VMs += $HCIBoxConfig.MgmtHostName
    foreach ($node in $HCIBoxConfig.HCIHostList) {
        $VMs += $node
    }
    foreach ($VM in $VMs) {
        Invoke-Command -VMName $VM -Credential $Credential -ScriptBlock {
            Set-Disk -Number 1 -IsOffline $false | Out-Null
                Initialize-Disk -Number 1 | Out-Null
                New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter | Out-Null
                Format-Volume -DriveLetter D | Out-Null  
        }
    }
}

function Test-VMAvailable {
    param (
        $VMName,
        [PSCredential]$Credential
    )
    Invoke-Command -VMName $VMName -ScriptBlock { 
        $ErrorOccurred = $false
        do { 
            try { 
                $ErrorActionPreference = 'Stop'
                Get-VMHost
            } 
            catch { 
                $ErrorOccurred = $true
            } 
        } while ($ErrorOccurred -eq $true)
    } -Credential $Credential -ErrorAction Ignore
    Write-Host "VM $VMName is now online"
}

function Test-AllVMsAvailable
 {
    param (
        $HCIBoxConfig,
        [PSCredential]$Credential
    )
    Write-Host "Testing whether VMs are available..."
    Test-VMAvailable -VMName $HCIBoxConfig.MgmtHostConfig.HostName -Credential $Credential
    foreach ($VM in $HCIBoxConfig.NodeHostConfig) {
        Test-VMAvailable -Name $VM.Hostname -Credential $Credential
    }
}
    
function Test-AzSHOSTVMConnection {
    param (
        $VMPlacement, 
        $localCred
    )

    foreach ($SDNVM in $VMPlacement) {
        Invoke-Command -ComputerName $SDNVM.VMHost  -ScriptBlock {
            $VerbosePreference = "Continue"            
            $localCred = $using:localCred   
            $testconnection = $null
            While (!$testconnection) {
                $testconnection = Invoke-Command -VMName $using:SDNVM.AzSHOST -ScriptBlock { 
                    $ErrorOccurred = $false
                    do { 
                        try { 
                            $ErrorActionPreference = 'Stop'
                            Get-VMHost
                        } 
                        catch { 
                            $ErrorOccurred = $true
                        } 
                    } while ($ErrorOccurred -eq $true)
                } -Credential $localCred -ErrorAction Ignore
            }
        }
    }    
}
    
function New-NATSwitch {
    Param (
        $VMPlacement,
        $SwitchName,
        $HCIBoxConfig
    )
    
    $natSwitchTarget = $VMPlacement | Where-Object { $_.AzSHOST -eq "AzSMGMT" }
    
    Add-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -ComputerName $natSwitchTarget.VMHost -DeviceNaming On 

    $params = @{
        VMName       = $natSwitchTarget.AzSHOST
        ComputerName = $natSwitchTarget.VMHost
    }

    Get-VMNetworkAdapter @params | Where-Object { $_.Name -match "Network" } | Connect-VMNetworkAdapter -SwitchName $HCIBoxConfig.natHostVMSwitchName
    Get-VMNetworkAdapter @params | Where-Object { $_.Name -match "Network" } | Rename-VMNetworkAdapter -NewName "NAT"
    
    Get-VM @params | Get-VMNetworkAdapter -Name NAT | Set-VMNetworkAdapter -MacAddressSpoofing On

    Add-VMNetworkAdapter @params -Name PROVIDER -DeviceNaming On -SwitchName $SwitchName
    Get-VM @params | Get-VMNetworkAdapter -Name PROVIDER | Set-VMNetworkAdapter -MacAddressSpoofing On
    Get-VM @params | Get-VMNetworkAdapter -Name PROVIDER | Set-VMNetworkAdapterVlan -Access -VlanId $HCIBoxConfig.providerVLAN | Out-Null    
    
    #Create VLAN 200 NIC in order for NAT to work from L3 Connections
    Add-VMNetworkAdapter @params -Name VLAN200 -DeviceNaming On -SwitchName $SwitchName
    Get-VM @params | Get-VMNetworkAdapter -Name VLAN200 | Set-VMNetworkAdapter -MacAddressSpoofing On
    Get-VM @params | Get-VMNetworkAdapter -Name VLAN200 | Set-VMNetworkAdapterVlan -Access -VlanId $HCIBoxConfig.vlan200VLAN | Out-Null    
    
    #Create Simulated Internet NIC in order for NAT to work from L3 Connections
    Add-VMNetworkAdapter @params -Name simInternet -DeviceNaming On -SwitchName $SwitchName
    Get-VM @params | Get-VMNetworkAdapter -Name simInternet | Set-VMNetworkAdapter -MacAddressSpoofing On
    Get-VM @params | Get-VMNetworkAdapter -Name simInternet | Set-VMNetworkAdapterVlan -Access -VlanId $HCIBoxConfig.simInternetVLAN | Out-Null
}  

function Set-NICs {
    Param (
        $HCIBoxConfig,
        [PSCredential]$Credential
    )

    Invoke-Command -VMName $HCIBoxConfig.MgmtHostName -Credential $Credential -ScriptBlock {
        Get-NetAdapter ((Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayValue -eq "SDN"}).Name) | Rename-NetAdapter -NewName FABRIC
        Get-Netadapter ((Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayValue -eq "SDN2"}).Name) | Rename-NetAdapter -NewName FABRIC2
    }

    $int = 9
    foreach ($VM in $HCIBoxConfig.HCIHostList) {
        $int++
        Invoke-Command -VMName $VM -Credential $localCred -ScriptBlock {
            # Create IP Address of Storage Adapters
            $storageAIP = $HCIBoxConfig.storageAsubnet.Replace("0/24", $int)
            $storageBIP = $HCIBoxConfig.storageBsubnet.Replace("0/24", $int)

            # Set Name and IP Addresses on Storage Interfaces
            $storageNICs = Get-NetAdapterAdvancedProperty | Where-Object { $_.DisplayValue -match "Storage" }
            foreach ($storageNIC in $storageNICs) {
                Rename-NetAdapter -Name $storageNIC.Name -NewName  $storageNIC.DisplayValue        
            }
            $storageNICs = Get-Netadapter | Where-Object { $_.Name -match "Storage" }
            foreach ($storageNIC in $storageNICs) {
                If ($storageNIC.Name -eq 'StorageA') { New-NetIPAddress -InterfaceAlias $storageNIC.Name -IPAddress $storageAIP -PrefixLength 24 | Out-Null }  
                If ($storageNIC.Name -eq 'StorageB') { New-NetIPAddress -InterfaceAlias $storageNIC.Name -IPAddress $storageBIP -PrefixLength 24 | Out-Null }  
            }

            # Enable WinRM
            Write-Verbose "Enabling Windows Remoting in $env:COMPUTERNAME"
            Set-Item WSMan:\localhost\Client\TrustedHosts *  -Confirm:$false -Force
            Enable-PSRemoting | Out-Null

            Start-Sleep -Seconds 60

            # Rename non-storage adapters
            Get-NetAdapter ((Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayValue -eq "SDN"}).Name) | Rename-NetAdapter -NewName FABRIC
            Get-Netadapter ((Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayValue -eq "SDN2"}).Name) | Rename-NetAdapter -NewName FABRIC2

            # I dont think this is necessary with HCI
            #Write-Verbose "Installing and Configuring Failover Clustering on $env:COMPUTERNAME"
            #Install-WindowsFeature -Name Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools -ComputerName $env:COMPUTERNAME -Credential $localCred | Out-Null 

            # Enable CredSSP and MTU Settings
            Invoke-Command -ComputerName localhost -Credential $localCred -ScriptBlock {
                $fqdn = $Using:SDNConfig.SDNDomainFQDN

                Write-Verbose "Enabling CredSSP on $env:COMPUTERNAME"
                Enable-WSManCredSSP -Role Server -Force
                Enable-WSManCredSSP -Role Client -DelegateComputer localhost -Force
                Enable-WSManCredSSP -Role Client -DelegateComputer $env:COMPUTERNAME -Force
                Enable-WSManCredSSP -Role Client -DelegateComputer $fqdn -Force
                Enable-WSManCredSSP -Role Client -DelegateComputer "*.$fqdn" -Force
                New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation `
                    -Name AllowFreshCredentialsWhenNTLMOnly -Force
                New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly `
                    -Name 1 -Value * -PropertyType String -Force 
            } -InDisconnectedSession | Out-Null
        }
    }
}

function Set-AzSMGMT {
    param (
        $HCIBoxConfig,
        $localCred,
        $domainCred

    )

    # Sleep to get around race condition on fast systems
    Start-Sleep -Seconds 10
    $VerbosePreference = "Continue"

    Invoke-Command -ComputerName azsmgmt -Credential $localCred  -ScriptBlock {
        # Creds
        $localCred = $using:localCred
        $domainCred = $using:domainCred
        $HCIBoxConfig = $using:SDNConfig

        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"
        $WarningPreference = "SilentlyContinue"

        # Disable Fabric2 Network Adapter
        $fabTwo = $null
        while ($fabTwo -ne 'Disabled') {
            Write-Verbose "Disabling Fabric2 Adapter"
            Get-Netadapter FABRIC2 | Disable-NetAdapter -Confirm:$false | Out-Null
            $fabTwo = (Get-Netadapter -Name FABRIC2).Status 

        }
        # Enable WinRM on AzSMGMT
        $VerbosePreference = "Continue"
        Write-Verbose "Enabling PSRemoting on $env:COMPUTERNAME"
        $VerbosePreference = "SilentlyContinue"
        Set-Item WSMan:\localhost\Client\TrustedHosts *  -Confirm:$false -Force
        Enable-PSRemoting | Out-Null
        

        #Disable ServerManager Auto-Start
        Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null

        # Create Hyper-V Networking for AzSMGMT
        Import-Module Hyper-V 

        Try {

            $VerbosePreference = "Continue"
            Write-Verbose "Creating VM Switch on $env:COMPUTERNAME"

            New-VMSwitch  -AllowManagementOS $true -Name "vSwitch-Fabric" -NetAdapterName FABRIC -MinimumBandwidthMode None | Out-Null

            # Configure NAT on AzSMGMT

            if ($HCIBoxConfig.natConfigure) {

                Write-Verbose "Configuring NAT on $env:COMPUTERNAME"

                $VerbosePreference = "SilentlyContinue"

                $natSubnet = $HCIBoxConfig.natSubnet
                $Prefix = ($natSubnet.Split("/"))[1]
                $natIP = ($natSubnet.TrimEnd("0./$Prefix")) + (".1")
                $provIP = $HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24") + "254"
                $vlan200IP = $HCIBoxConfig.BGPRouterIP_VLAN200.TrimEnd("1/24") + "250"
                $provGW = $HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("/24")
                $provpfx = $HCIBoxConfig.BGPRouterIP_ProviderNetwork.Split("/")[1]
                $vlanpfx = $HCIBoxConfig.BGPRouterIP_VLAN200.Split("/")[1]
                $simInternetIP = $HCIBoxConfig.BGPRouterIP_SimulatedInternet.TrimEnd("1/24") + "254"
                $simInternetPFX = $HCIBoxConfig.BGPRouterIP_SimulatedInternet.Split("/")[1]

                New-VMSwitch -SwitchName NAT -SwitchType Internal -MinimumBandwidthMode None | Out-Null
                New-NetIPAddress -IPAddress $natIP -PrefixLength $Prefix -InterfaceAlias "vEthernet (NAT)" | Out-Null
                New-NetNat -Name NATNet -InternalIPInterfaceAddressPrefix $natSubnet | Out-Null

                $VerbosePreference = "Continue"
                Write-Verbose "Configuring Provider NIC on $env:COMPUTERNAME"
                $VerbosePreference = "SilentlyContinue"

                $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "PROVIDER" }
                Rename-NetAdapter -name $NIC.name -newname "PROVIDER" | Out-Null
                New-NetIPAddress -InterfaceAlias "PROVIDER" -IPAddress $provIP -PrefixLength $provpfx | Out-Null

                $VerbosePreference = "Continue"
                Write-Verbose "Configuring VLAN200 NIC on $env:COMPUTERNAME"
                $VerbosePreference = "SilentlyContinue"

                $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "VLAN200" }
                Rename-NetAdapter -name $NIC.name -newname "VLAN200" | Out-Null
                New-NetIPAddress -InterfaceAlias "VLAN200" -IPAddress $vlan200IP -PrefixLength $vlanpfx | Out-Null

                $VerbosePreference = "Continue"
                Write-Verbose "Configuring simulatedInternet NIC on $env:COMPUTERNAME"
                $VerbosePreference = "SilentlyContinue"


                $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "simInternet" }
                Rename-NetAdapter -name $NIC.name -newname "simInternet" | Out-Null
                New-NetIPAddress -InterfaceAlias "simInternet" -IPAddress $simInternetIP -PrefixLength $simInternetPFX | Out-Null

                Write-Verbose "Making NAT Work"

                $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" `
                | Where-Object { $_.RegistryValue -eq "Network Adapter" -or $_.RegistryValue -eq "NAT" }

                Rename-NetAdapter -name $NIC.name -newname "Internet" | Out-Null 

                $internetIP = $HCIBoxConfig.natHostSubnet.Replace("0/24", "5")
                $internetGW = $HCIBoxConfig.natHostSubnet.Replace("0/24", "1")

                Start-Sleep -Seconds 30

                $internetIndex = (Get-NetAdapter | Where-Object { $_.Name -eq "Internet" }).ifIndex

                Start-Sleep -Seconds 30

                New-NetIPAddress -IPAddress $internetIP -PrefixLength 24 -InterfaceIndex $internetIndex -DefaultGateway $internetGW -AddressFamily IPv4 | Out-Null
                Set-DnsClientServerAddress -InterfaceIndex $internetIndex -ServerAddresses ($HCIBoxConfig.natDNS) | Out-Null

                #Enable Large MTU

                $VerbosePreference = "Continue"
                Write-Verbose "Configuring MTU on all Adapters"
                $VerbosePreference = "SilentlyContinue"
                Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -ne "Ethernet" } | Set-NetAdapterAdvancedProperty `
                    -RegistryValue $HCIBoxConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"
                $VerbosePreference = "Continue"

                Start-Sleep -Seconds 30

                #Provision Public and Private VIP Route
 
                New-NetRoute -DestinationPrefix $HCIBoxConfig.PublicVIPSubnet -NextHop $provGW -InterfaceAlias PROVIDER | Out-Null

                # Remove Gateway from Fabric NIC
                Write-Verbose "Removing Gateway from Fabric NIC" 
                $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -match "vSwitch-Fabric" }).InterfaceIndex
                Remove-NetRoute -InterfaceIndex $index -DestinationPrefix "0.0.0.0/0" -Confirm:$false

            }

        }

        Catch {

            throw $_

        }

    }

    # Provision BGP TOR Router
    New-RouterVM -SDNConfig $HCIBoxConfig -localCred $localCred -domainCred $domainCred | Out-Null

    # Provision Domain Controller 
    Write-Verbose "Provisioning Domain Controller VM"
    New-DCVM -SDNConfig $HCIBoxConfig -localCred $localCred -domainCred $domainCred | Out-Null

    # Join AzSHOSTs to Domain 
    Invoke-Command -VMName AzSMGMT -Credential $localCred -ScriptBlock {

        $HCIBoxConfig = $using:SDNConfig
        $VerbosePreference = "Continue"

        function AddAzSHOSTToDomain {

            Param (

                $IP,
                $localCred, 
                $domainCred, 
                $AzSHOSTName, 
                $HCIBoxConfig

            )

            Write-Verbose "Joining host $AzSHOSTName ($ip) to domain"

            Try {

                $AzSHOSTTest = Test-Connection $IP -Quiet

                While (!$AzSHOSTTest) {
                    Write-Host "Unable to contact computer $AzSHOSTname at $IP. Please make sure the system is contactable before continuing and the Press Enter to continue." `
                        -ForegroundColor Red
                    pause
                    $AzSHOSTTest = Test-Connection $AzSHOSTName -Quiet -Count 1                      
                }

                While ($DomainJoined -ne $HCIBoxConfig.SDNDomainFQDN) {

                    $params = @{

                        ComputerName = $IP
                        Credential   = $localCred
                        ArgumentList = ($domainCred, $HCIBoxConfig.SDNDomainFQDN)
                    }


                    $job = Invoke-Command @params -ScriptBlock { add-computer -DomainName $args[1] -Credential $args[0] } -AsJob 

                    While ($Job.JobStateInfo.State -ne "Completed") { Start-Sleep -Seconds 10 }
                    $DomainJoined = (Get-WmiObject -ComputerName $ip -Class win32_computersystem).domain
                }

                Restart-Computer -ComputerName $IP -Credential $localCred -Force

            }

            Catch { 

                throw $_

            }

        }

        # Set VM Path for Physical Hosts
        try {

            $AzSHOST1 = $HCIBoxConfig.AzSHOST1IP.Split("/")[0]
            $AzSHOST2 = $HCIBoxConfig.AzSHOST2IP.Split("/")[0]

            Write-Verbose "Setting VMStorage Path for all Hosts"
          
            Invoke-Command -ComputerName $AzSHOST1 -ArgumentList $VMStoragePathforOtherHosts `
                -ScriptBlock { Set-VMHost -VirtualHardDiskPath $args[0] -VirtualMachinePath $args[0] } `
                -Credential $using:localCred -AsJob | Out-Null
            Invoke-Command -ComputerName $AzSHOST2  -ArgumentList $VMStoragePathforOtherHosts `
                -ScriptBlock { Set-VMHost -VirtualHardDiskPath $args[0] -VirtualMachinePath $args[0] } `
                -Credential $using:localCred -AsJob | Out-Null

            # 2nd pass
            Invoke-Command -ComputerName $AzSHOST1 -ArgumentList $VMStoragePathforOtherHosts `
                -ScriptBlock { Set-VMHost -VirtualHardDiskPath $args[0] -VirtualMachinePath $args[0] } `
                -Credential $using:localCred -AsJob | Out-Null
            Invoke-Command -ComputerName $AzSHOST2 -ArgumentList $VMStoragePathforOtherHosts `
                -ScriptBlock { Set-VMHost -VirtualHardDiskPath $args[0] -VirtualMachinePath $args[0] } `
                -Credential $using:localCred -AsJob | Out-Null

        }

        catch {

            throw $_

        }

        # Add AzSHOSTS to domain
        try {

            Write-Verbose "Adding HCIBox Hosts to the Domain"
            AddAzSHOSTToDomain -IP $AzSHOST1 -localCred $using:localCred -domainCred $using:domainCred -AzSHOSTName AzSHOST1 -SDNConfig $HCIBoxConfig
            AddAzSHOSTToDomain -IP $AzSHOST2 -localCred $using:localCred -domainCred $using:domainCred -AzSHOSTName AzSHOST2 -SDNConfig $HCIBoxConfig
        }
        catch {
            throw $_
        }
    } | Out-Null

    # Provision Admincenter
    Write-Verbose "Provisioning admincenter VM"
    $domainCred = new-object -typename System.Management.Automation.PSCredential -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\$env:adminUsername"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword  -AsPlainText -Force)
    New-AdminCenterVM -SDNConfig $HCIBoxConfig -localCred $localCred -domainCred $domainCred | Out-Null

}

function New-DCVM {
    Param (
        $HCIBoxConfig,
        $localCred,
        $domainCred
    )

    $ErrorActionPreference = "Continue"
    $adminUser = $env:adminUsername
    Invoke-Command -VMName AzSMGMT -Credential $localCred -ScriptBlock {
        $adminUser = $using:adminUser
        $HCIBoxConfig = $using:SDNConfig
        $localcred = $using:localcred
        $domainCred = $using:domainCred
        $ParentDiskPath = "C:\VMs\Base\"
        $vmpath = "D:\VMs\"
        $OSVHDX = "GUI.vhdx"
        $VMName = $HCIBoxConfig.DCName

        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"
        $WarningPreference = "SilentlyContinue"

        # Create Virtual Machine
        Write-Verbose "Creating $VMName differencing disks"  
        $params = @{
            ParentPath = ($ParentDiskPath + $OSVHDX)
            Path       = ($vmpath + $VMName + '\' + $VMName + '.vhdx')
        }
        New-VHD  @params -Differencing | Out-Null

        Write-Verbose "Creating $VMName virtual machine"
        $params = @{
            Name       = $VMName
            VHDPath    = ($vmpath + $VMName + '\' + $VMName + '.vhdx')
            Path       = ($vmpath + $VMName)
            Generation = 2
        }
        New-VM @params | Out-Null

        Write-Verbose "Setting $VMName Memory"
        $params = @{
            VMName               = $VMName
            DynamicMemoryEnabled = $true
            StartupBytes         = $HCIBoxConfig.MEM_DC
            MaximumBytes         = $HCIBoxConfig.MEM_DC
            MinimumBytes         = 500MB
        }
        Set-VMMemory @params | Out-Null

        Write-Verbose "Configuring $VMName's networking"
        Remove-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" | Out-Null
        $params = @{
            VMName       = $VMName
            Name         = $HCIBoxConfig.DCName
            SwitchName   = 'vSwitch-Fabric'
            DeviceNaming = 'On'
        }
        Add-VMNetworkAdapter @params | Out-Null
        Write-Verbose "Configuring $VMName's settings"
        Set-VMProcessor -VMName $VMName -Count 2 | Out-Null
        Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown | Out-Null

        # Add NIC for VLAN200 for DHCP server
        Add-VMNetworkAdapter -VMName $VMName -Name "VLAN200" -SwitchName "vSwitch-Fabric" -DeviceNaming "On"
        Get-VMNetworkAdapter -VMName $VMName -Name "VLAN200" | Set-VMNetworkAdapterVLAN -Access -VlanId $HCIBoxConfig.AKSVlanID

        # Inject Answer File
        Write-Verbose "Mounting and injecting answer file into the $VMName VM."        
        $VerbosePreference = "SilentlyContinue"

        New-Item -Path "C:\TempMount" -ItemType Directory | Out-Null
        Mount-WindowsImage -Path "C:\TempMount" -Index 1 -ImagePath ($vmpath + $VMName + '\' + $VMName + '.vhdx') | Out-Null

        $VerbosePreference = "Continue"
        Write-Verbose "Applying Unattend file to Disk Image..."

        $password = $HCIBoxConfig.SDNAdminPassword
        $Unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing>
        <package action="configure">
            <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
            <selection name="ADCertificateServicesRole" state="true" />
            <selection name="CertificateServices" state="true" />
        </package>
    </servicing>
    <settings pass="specialize">
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
            <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
            <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$VMName</ComputerName>
        </component>
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>en-us</UserLocale>
            <UILanguage>en-us</UILanguage>
            <SystemLocale>en-us</SystemLocale>
            <InputLocale>en-us</InputLocale>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@

        New-Item -Path C:\TempMount\windows -ItemType Directory -Name Panther -Force | Out-Null
        Set-Content -Value $Unattend -Path "C:\TempMount\Windows\Panther\Unattend.xml"  -Force

        Write-Verbose "Dismounting Windows Image"
        Dismount-WindowsImage -Path "C:\TempMount" -Save | Out-Null
        Remove-Item "C:\TempMount" | Out-Null

        # Start Virtual Machine

        Write-Verbose "Starting Virtual Machine" 
        Start-VM -Name $VMName | Out-Null
        
        # Wait until the VM is restarted
        while ((Invoke-Command -VMName $VMName -Credential $using:domainCred { "Test" } `
                    -ea SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 1 }

        Write-Verbose "Configuring Domain Controller VM and Installing Active Directory."
        
        $ErrorActionPreference = "SilentlyContinue"

        Invoke-Command -VMName $VMName -Credential $localCred -ArgumentList $HCIBoxConfig -ScriptBlock {

            $HCIBoxConfig = $args[0]

            $VerbosePreference = "Continue"
            $WarningPreference = "SilentlyContinue"
            $ErrorActionPreference = "Stop"
            $DCName = $HCIBoxConfig.DCName
            $IP = $HCIBoxConfig.SDNLABDNS
            $PrefixLength = ($HCIBoxConfig.AzSMGMTIP.split("/"))[1]
            $SDNLabRoute = $HCIBoxConfig.SDNLABRoute
            $DomainFQDN = $HCIBoxConfig.SDNDomainFQDN
            $DomainNetBiosName = $DomainFQDN.Split(".")[0]

            Write-Verbose "Configuring NIC Settings for Domain Controller"
            $VerbosePreference = "SilentlyContinue"
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq $DCName }
            Rename-NetAdapter -name $NIC.name -newname $DCName | Out-Null 
            New-NetIPAddress -InterfaceAlias $DCName -IPAddress $ip -PrefixLength $PrefixLength -DefaultGateway $SDNLabRoute | Out-Null
            Set-DnsClientServerAddress -InterfaceAlias $DCName -ServerAddresses $IP | Out-Null
            Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools | Out-Null
            $VerbosePreference = "Continue"

            Write-Verbose "Configuring NIC settings for DC VLAN200"
            $VerbosePreference = "SilentlyContinue"
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "VLAN200" }
            Rename-NetAdapter -name $NIC.name -newname VLAN200 | Out-Null
            New-NetIPAddress -InterfaceAlias VLAN200 -IPAddress $HCIBoxConfig.dcVLAN200IP -PrefixLength ($HCIBoxConfig.AKSIPPrefix.split("/"))[1] -DefaultGateway $HCIBoxConfig.AKSGWIP | Out-Null
            $VerbosePreference = "Continue"

            Write-Verbose "Configuring Trusted Hosts"
            Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force

            Write-Verbose "Installing Active Directory Forest. This will take some time..."
        
            $SecureString = ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
            Write-Verbose "Installing Active Directory..." 
            $params = @{
                DomainName                    = $DomainFQDN
                DomainMode                    = 'WinThreshold'
                DatabasePath                  = "C:\Domain"
                DomainNetBiosName             = $DomainNetBiosName
                SafeModeAdministratorPassword = $SecureString
            }
            Write-Output $params
            
            $VerbosePreference = "SilentlyContinue"
            Install-ADDSForest  @params -InstallDns -Confirm -Force -NoRebootOnCompletion # | Out-Null
        }
        $ErrorActionPreference = "Stop"

        Write-Verbose "Stopping $VMName"
        Get-VM $VMName | Stop-VM
        Write-Verbose "Starting $VMName"
        Get-VM $VMName | Start-VM 

        # Wait until DC is created and rebooted

        while ((Invoke-Command -VMName $VMName -Credential $using:domainCred `
                    -ArgumentList $HCIBoxConfig.DCName { (Get-ADDomainController $args[0]).enabled } -ea SilentlyContinue) -ne $true) { Start-Sleep -Seconds 1 }

        $VerbosePreference = "Continue"
        Write-Verbose "Configuring User Accounts and Groups in Active Directory"
        

        $ErrorActionPreference = "Continue"
        $HCIBoxConfig.adminUser = $using:adminUser
        Invoke-Command -VMName $VMName -Credential $using:domainCred -ArgumentList $HCIBoxConfig -ScriptBlock {

            $HCIBoxConfig = $args[0]
            $SDNDomainFQDN = $HCIBoxConfig.SDNDomainFQDN

            $VerbosePreference = "Continue"
            $ErrorActionPreference = "Stop"

            $SecureString = ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force

            $params = @{
                ComplexityEnabled = $false
                Identity          = $HCIBoxConfig.SDNDomainFQDN
                MinPasswordLength = 0
            }

            Set-ADDefaultDomainPasswordPolicy @params

            $params = @{
                Name                  = 'NC Admin'
                GivenName             = 'NC'
                Surname               = 'Admin'
                SamAccountName        = 'NCAdmin'
                UserPrincipalName     = "NCAdmin@$SDNDomainFQDN"
                AccountPassword       = $SecureString
                Enabled               = $true
                ChangePasswordAtLogon = $false
                CannotChangePassword  = $true
                PasswordNeverExpires  = $true
            }

            New-ADUser @params
            $params = @{
                Name                  = $HCIBoxConfig.adminUser
                GivenName             = 'Jumpstart'
                Surname               = 'Jumpstart'
                SamAccountName        = $HCIBoxConfig.adminUser
                UserPrincipalName     = "$HCIBoxConfig.adminUser@$SDNDomainFQDN"
                AccountPassword       = $SecureString
                Enabled               = $true
                ChangePasswordAtLogon = $false
                CannotChangePassword  = $true
                PasswordNeverExpires  = $true
            }

            New-ADUser @params

            $params.Name = 'NC Client'
            $params.Surname = 'Client'
            $params.SamAccountName = 'NCClient'
            $params.UserPrincipalName = "NCClient@$SDNDomainFQDN" 

            New-ADUser @params

            NEW-ADGroup -name “NCAdmins” -groupscope Global
            NEW-ADGroup -name “NCClients” -groupscope Global

            add-ADGroupMember "Domain Admins" "NCAdmin"
            add-ADGroupMember "NCAdmins" "NCAdmin"
            add-ADGroupMember "NCClients" "NCClient"
            add-ADGroupMember "NCClients" "Administrator"
            add-ADGroupMember "NCAdmins" "Administrator"
            add-ADGroupMember "Domain Admins" $HCIBoxConfig.adminUser
            add-ADGroupMember "NCAdmins" $HCIBoxConfig.adminUser
            add-ADGroupMember "NCClients" $HCIBoxConfig.adminUser

            # Set Administrator Account Not to Expire

            Get-ADUser Administrator | Set-ADUser -PasswordNeverExpires $true  -CannotChangePassword $true

            # Set DNS Forwarder

            Write-Verbose "Adding DNS Forwarders"
            $VerbosePreference = "SilentlyContinue"

            if ($HCIBoxConfig.natDNS) { Add-DnsServerForwarder $HCIBoxConfig.natDNS }
            else { Add-DnsServerForwarder 8.8.8.8 }

            # Create Enterprise CA 

            $VerbosePreference = "Continue"
            Write-Verbose "Installing and Configuring Active Directory Certificate Services and Certificate Templates"
            $VerbosePreference = "SilentlyContinue"

            

            Install-WindowsFeature -Name AD-Certificate -IncludeAllSubFeature -IncludeManagementTools | Out-Null

            $params = @{

                CAtype              = 'EnterpriseRootCa'
                CryptoProviderName  = 'ECDSA_P256#Microsoft Software Key Storage Provider'
                KeyLength           = 256
                HashAlgorithmName   = 'SHA256'
                ValidityPeriod      = 'Years'
                ValidityPeriodUnits = 10
            }

            Install-AdcsCertificationAuthority @params -Confirm:$false | Out-Null

            # Give WebServer Template Enroll rights for Domain Computers

            $filter = "(CN=WebServer)"
            $ConfigContext = ([ADSI]"LDAP://RootDSE").configurationNamingContext
            $ConfigContext = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
            $ds = New-object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$ConfigContext", $filter)  
            $Template = $ds.Findone().GetDirectoryEntry() 

            if ($Template -ne $null) {
                $objUser = New-Object System.Security.Principal.NTAccount("Domain Computers") 
                $objectGuid = New-Object Guid 0e10c968-78fb-11d2-90d4-00c04f79dc55                     
                $ADRight = [System.DirectoryServices.ActiveDirectoryRights]"ExtendedRight"                     
                $ACEType = [System.Security.AccessControl.AccessControlType]"Allow"                     
                $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $objUser, $ADRight, $ACEType, $objectGuid                     
                $Template.ObjectSecurity.AddAccessRule($ACE)                     
                $Template.commitchanges()
            } 
 
            CMD.exe /c "certutil -setreg ca\ValidityPeriodUnits 8" | Out-Null
            Restart-Service CertSvc
            Start-Sleep -Seconds 60
 
            #Issue Certificate Template

            CMD.exe /c "certutil -SetCATemplates +WebServer"
 
        }

        # Set up DHCP scope for Arc resource bridge
        Invoke-Command -VMName $HCIBoxConfig.DCName -Credential $using:domainCred -ArgumentList $HCIBoxConfig -ScriptBlock {
            $HCIBoxConfig = $args[0]

            # Install DHCP feature
            Install-WindowsFeature DHCP -IncludeManagementTools
            CMD.exe /c "netsh dhcp add securitygroups"
            Restart-Service dhcpserver

            # Allow DHCP in domain
            $dnsName = $HCIBoxConfig.DCName
            $fqdnsName = $HCIBoxConfig.DCName + "." + $HCIBoxConfig.SDNDomainFQDN
            Add-DhcpServerInDC -DnsName $fqdnsName -IPAddress $HCIBoxConfig.dcVLAN200IP
            Get-DHCPServerInDC

            # Configure dynamic DNS updates for DHCP records
            #Set-DhcpServerv4DnsSetting -ComputerName "jumpstartdc.jumpstart.local" -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True
            #$Credential = Get-Credential
            #Set-DhcpServerDnsCredential -Credential $Credential -ComputerName "jumpstartdc.jumpstart.local"
            
            # Bind DHCP only to VLAN200 NIC
            Set-DhcpServerv4Binding -ComputerName $dnsName -InterfaceAlias $dnsName -BindingState $false
            Set-DhcpServerv4Binding -ComputerName $dnsName -InterfaceAlias VLAN200 -BindingState $true

            # Add DHCP scope for Resource bridge VMs
            Add-DhcpServerv4Scope -name "ResourceBridge" -StartRange $HCIBoxConfig.rbVipStart -EndRange $HCIBoxConfig.rbVipEnd -SubnetMask 255.255.255.0 -State Active
            $scope = Get-DhcpServerv4Scope
            Add-DhcpServerv4ExclusionRange -ScopeID $scope.ScopeID.IPAddressToString -StartRange $HCIBoxConfig.rbDHCPExclusionStart -EndRange $HCIBoxConfig.rbDHCPExclusionEnd
            #Set-DhcpServerv4OptionValue -OptionID 3 -Value $HCIBoxConfig.BGPRouterIP_VLAN200.Trim("/24") -ScopeID $scope.ScopeID.IPAddressToString -ComputerName $dnsName
            Set-DhcpServerv4OptionValue -ComputerName $dnsName -ScopeId $scope.ScopeID.IPAddressToString -DnsServer $HCIBoxConfig.SDNLABDNS -Router $HCIBoxConfig.BGPRouterIP_VLAN200.Trim("/24")
        }
    }
    $ErrorActionPreference = "Stop"
}

function New-RouterVM {
    Param (
        $HCIBoxConfig,
        $localCred,
        $domainCred
    )

    Invoke-Command -VMName AzSMGMT -Credential $localCred -ScriptBlock {
        $HCIBoxConfig = $using:SDNConfig
        $localcred = $using:localcred
        $domainCred = $using:domainCred
        $ParentDiskPath = "C:\VMs\Base\"
        $vmpath = "D:\VMs\"
        $OSVHDX = "AzSHCI.vhdx"
    
        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"
        $WarningPreference = "SilentlyContinue"    
    
        $VMName = "bgp-tor-router"
    
        # Create Host OS Disk
        Write-Verbose "Creating $VMName differencing disks"
        $params = @{
            ParentPath = ($ParentDiskPath + $OSVHDX)
            Path       = ($vmpath + $VMName + '\' + $VMName + '.vhdx') 
        }
        New-VHD @params -Differencing | Out-Null
    
        # Create VM
        $params = @{
            Name       = $VMName
            VHDPath    = ($vmpath + $VMName + '\' + $VMName + '.vhdx')
            Path       = ($vmpath + $VMName)
            Generation = 2
        }
        Write-Verbose "Creating the $VMName VM."
        New-VM @params | Out-Null
    
        # Set VM Configuration
        Write-Verbose "Setting $VMName's VM Configuration"
        $params = @{
            VMName               = $VMName
            DynamicMemoryEnabled = $true
            StartupBytes         = $HCIBoxConfig.MEM_BGP
            MaximumBytes         = $HCIBoxConfig.MEM_BGP
            MinimumBytes         = 500MB
        }
   
        Set-VMMemory @params | Out-Null
        Remove-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" | Out-Null 
        Set-VMProcessor -VMName $VMName -Count 2 | Out-Null
        set-vm -Name $VMName -AutomaticStopAction TurnOff | Out-Null
    
        # Configure VM Networking
        Write-Verbose "Configuring $VMName's Networking"
        Add-VMNetworkAdapter -VMName $VMName -Name Mgmt -SwitchName vSwitch-Fabric -DeviceNaming On
        Add-VMNetworkAdapter -VMName $VMName -Name Provider -SwitchName vSwitch-Fabric -DeviceNaming On
        Add-VMNetworkAdapter -VMName $VMName -Name VLAN200 -SwitchName vSwitch-Fabric -DeviceNaming On
        Add-VMNetworkAdapter -VMName $VMName -Name SIMInternet -SwitchName vSwitch-Fabric -DeviceNaming On
        Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName Provider -Access -VlanId $HCIBoxConfig.providerVLAN
        Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName VLAN200 -Access -VlanId $HCIBoxConfig.vlan200VLAN
        Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName SIMInternet -Access -VlanId $HCIBoxConfig.simInternetVLAN
           
        # Add NAT Adapter
        if ($HCIBoxConfig.natConfigure) {
            Add-VMNetworkAdapter -VMName $VMName -Name NAT -SwitchName NAT -DeviceNaming On
        }    
    
        # Configure VM
        Set-VMProcessor -VMName $VMName  -Count 2
        Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown | Out-Null      
    
        # Inject Answer File
        Write-Verbose "Mounting Disk Image and Injecting Answer File into the $VMName VM." 
        New-Item -Path "C:\TempBGPMount" -ItemType Directory | Out-Null
        Mount-WindowsImage -Path "C:\TempBGPMount" -Index 1 -ImagePath ($vmpath + $VMName + '\' + $VMName + '.vhdx') | Out-Null
    
        New-Item -Path C:\TempBGPMount\windows -ItemType Directory -Name Panther -Force | Out-Null
    
        $Password = $HCIBoxConfig.SDNAdminPassword
    
        $Unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
        <servicing>
            <package action="configure">
                <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
                <selection name="RemoteAccessServer" state="true" />
                <selection name="RasRoutingProtocols" state="true" />
            </package>
        </servicing>
        <settings pass="specialize">
            <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
                <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
                <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
            </component>
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <ComputerName>$VMName</ComputerName>
            </component>
            <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <fDenyTSConnections>false</fDenyTSConnections>
            </component>
            <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <UserLocale>en-us</UserLocale>
                <UILanguage>en-us</UILanguage>
                <SystemLocale>en-us</SystemLocale>
                <InputLocale>en-us</InputLocale>
            </component>
        </settings>
        <settings pass="oobeSystem">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <OOBE>
                    <HideEULAPage>true</HideEULAPage>
                    <SkipMachineOOBE>true</SkipMachineOOBE>
                    <SkipUserOOBE>true</SkipUserOOBE>
                    <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                </OOBE>
                <UserAccounts>
                    <AdministratorPassword>
                        <Value>$Password</Value>
                        <PlainText>true</PlainText>
                    </AdministratorPassword>
                </UserAccounts>
            </component>
        </settings>
        <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
    </unattend>    
"@
        Set-Content -Value $Unattend -Path "C:\TempBGPMount\Windows\Panther\Unattend.xml" -Force
    
        Write-Verbose "Enabling Remote Access"
        Enable-WindowsOptionalFeature -Path C:\TempBGPMount -FeatureName RasRoutingProtocols -All -LimitAccess | Out-Null
        Enable-WindowsOptionalFeature -Path C:\TempBGPMount -FeatureName RemoteAccessPowerShell -All -LimitAccess | Out-Null
        Write-Verbose "Dismounting Disk Image for $VMName VM." 
        Dismount-WindowsImage -Path "C:\TempBGPMount" -Save | Out-Null
        Remove-Item "C:\TempBGPMount"
    
        # Start the VM

        Write-Verbose "Starting $VMName VM."
        Start-VM -Name $VMName      
    
        # Wait for VM to be started

        while ((Invoke-Command -VMName $VMName -Credential $localcred { "Test" } -ea SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 1 }    
    
        Write-Verbose "Configuring $VMName" 
    
        Invoke-Command -VMName $VMName -Credential $localCred -ArgumentList $HCIBoxConfig -ScriptBlock {
    
            $ErrorActionPreference = "Stop"
            $VerbosePreference = "Continue"
            $WarningPreference = "SilentlyContinue"
    
            $HCIBoxConfig = $args[0]
            $DNS = $HCIBoxConfig.SDNLABDNS
            $natSubnet = $HCIBoxConfig.natSubnet
            $natDNS = $HCIBoxConfig.natSubnet
            $MGMTIP = $HCIBoxConfig.BGPRouterIP_MGMT.Split("/")[0]
            $MGMTPFX = $HCIBoxConfig.BGPRouterIP_MGMT.Split("/")[1]
            $PNVIP = $HCIBoxConfig.BGPRouterIP_ProviderNetwork.Split("/")[0]
            $PNVPFX = $HCIBoxConfig.BGPRouterIP_ProviderNetwork.Split("/")[1]
            $VLANIP = $HCIBoxConfig.BGPRouterIP_VLAN200.Split("/")[0]
            $VLANPFX = $HCIBoxConfig.BGPRouterIP_VLAN200.Split("/")[1]
            $simInternetIP = $HCIBoxConfig.BGPRouterIP_SimulatedInternet.Split("/")[0]
            $simInternetPFX = $HCIBoxConfig.BGPRouterIP_SimulatedInternet.Split("/")[1]
    
            # Renaming NetAdapters and setting up the IPs inside the VM using CDN parameters

            Write-Verbose "Configuring $env:COMPUTERNAME's Networking"
            $VerbosePreference = "SilentlyContinue"  
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "Mgmt" }
            Rename-NetAdapter -name $NIC.name -newname "Mgmt" | Out-Null
            New-NetIPAddress -InterfaceAlias "Mgmt" -IPAddress $MGMTIP -PrefixLength $MGMTPFX | Out-Null
            Set-DnsClientServerAddress -InterfaceAlias “Mgmt” -ServerAddresses $DNS] | Out-Null
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "PROVIDER" }
            Rename-NetAdapter -name $NIC.name -newname "PROVIDER" | Out-Null
            New-NetIPAddress -InterfaceAlias "PROVIDER" -IPAddress $PNVIP -PrefixLength $PNVPFX | Out-Null
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "VLAN200" }
            Rename-NetAdapter -name $NIC.name -newname "VLAN200" | Out-Null
            New-NetIPAddress -InterfaceAlias "VLAN200" -IPAddress $VLANIP -PrefixLength $VLANPFX | Out-Null
            $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "SIMInternet" }
            Rename-NetAdapter -name $NIC.name -newname "SIMInternet" | Out-Null
            New-NetIPAddress -InterfaceAlias "SIMInternet" -IPAddress $simInternetIP -PrefixLength $simInternetPFX | Out-Null      
    
            # if NAT is selected, configure the adapter
       
            if ($HCIBoxConfig.natConfigure) {
    
                $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" `
                | Where-Object { $_.RegistryValue -eq "NAT" }
                Rename-NetAdapter -name $NIC.name -newname "NAT" | Out-Null
                $Prefix = ($natSubnet.Split("/"))[1]
                $natIP = ($natSubnet.TrimEnd("0./$Prefix")) + (".10")
                $natGW = ($natSubnet.TrimEnd("0./$Prefix")) + (".1")
                New-NetIPAddress -InterfaceAlias "NAT" -IPAddress $natIP -PrefixLength $Prefix -DefaultGateway $natGW | Out-Null
                if ($natDNS) {
                    Set-DnsClientServerAddress -InterfaceAlias "NAT" -ServerAddresses $natDNS | Out-Null
                }
            }
    
            # Configure Trusted Hosts

            Write-Verbose "Configuring Trusted Hosts"
            Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force
            
            
            # Installing Remote Access

            Write-Verbose "Installing Remote Access on $env:COMPUTERNAME" 
            $VerbosePreference = "SilentlyContinue"
            Install-RemoteAccess -VPNType RoutingOnly | Out-Null
    
            # Adding a BGP Router to the VM

            $VerbosePreference = "Continue"
            Write-Verbose "Installing BGP Router on $env:COMPUTERNAME"
            $VerbosePreference = "SilentlyContinue"

            $params = @{

                BGPIdentifier  = $PNVIP
                LocalASN       = $HCIBoxConfig.BGPRouterASN
                TransitRouting = 'Enabled'
                ClusterId      = 1
                RouteReflector = 'Enabled'

            }

            Add-BgpRouter @params

            #Add-BgpRouter -BGPIdentifier $PNVIP -LocalASN $HCIBoxConfig.BGPRouterASN `
            # -TransitRouting Enabled -ClusterId 1 -RouteReflector Enabled

            # Configure BGP Peers

            if ($HCIBoxConfig.ConfigureBGPpeering -and $HCIBoxConfig.ProvisionNC) {

                Write-Verbose "Peering future MUX/GWs"

                $Mux01IP = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "4"
                $GW01IP = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "5"
                $GW02IP = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "6"

                $params = @{

                    Name           = 'MUX01'
                    LocalIPAddress = $PNVIP
                    PeerIPAddress  = $Mux01IP
                    PeerASN        = $HCIBoxConfig.SDNASN
                    OperationMode  = 'Mixed'
                    PeeringMode    = 'Automatic'
                }

                Add-BgpPeer @params -PassThru

                $params.Name = 'GW01'
                $params.PeerIPAddress = $GW01IP

                Add-BgpPeer @params -PassThru

                $params.Name = 'GW02'
                $params.PeerIPAddress = $GW02IP

                Add-BgpPeer @params -PassThru    

            }
    
            # Enable Large MTU

            Write-Verbose "Configuring MTU on all Adapters"
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Set-NetAdapterAdvancedProperty -RegistryValue $HCIBoxConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"   
            
#             # Enable DHCP Relay
#             $routerNetAdapterName = "VLAN200"
#             $netshDhcpRelay=@"
# pushd routing ip relay
# install
# set global loglevel=ERROR
# add dhcpserver $($HCIBoxConfig.DCIP)
# add interface name="$routerNetAdapterName"
# set interface name="$routerNetAdapterName" relaymode=enable maxhop=6 minsecs=6
# popd
# "@

#             $netshDhcpRelayPath="$ENV:TEMP\netshDhcpRelay"

            # # Create netsh script file
            # New-Item -Path $netshDhcpRelayPath -Type File -ErrorAction SilentlyContinue | Out-Null

            # # Populate contents of the script 
            # Set-Content -Path $netshDhcpRelayPath -Value $netshDhcpRelay.Split("`r`n") -Encoding ASCII

            # # run it
            # CMD.exe /c "netsh -f $netshDhcpRelayPath"
        }     
    
        $ErrorActionPreference = "Continue"
        $VerbosePreference = "SilentlyContinue"
        $WarningPreference = "Continue"

    } -AsJob

}

function New-AdminCenterVM {
    Param (
        $HCIBoxConfig,
        $localCred,
        $domainCred
    )

    $domainAdminUsername = $env:adminUsername

    Invoke-Command -VMName AzSMGMT -Credential $localCred -ScriptBlock {
        $VMName = "admincenter"
        $ParentDiskPath = "C:\VMs\Base\"
        $VHDPath = "D:\VMs\"
        $OSVHDX = "GUI.vhdx"
        $BaseVHDPath = $ParentDiskPath + $OSVHDX
        $HCIBoxConfig = $using:SDNConfig

        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"
        $WarningPreference = "SilentlyContinue"

        # Set Credentials
        $localCred = $using:localCred
        $domainCred = $using:domainCred

        # Create Host OS Disk
        Write-Verbose "Creating $VMName differencing disks"

        $params = @{

            ParentPath = $BaseVHDPath
            Path       = (($VHDPath) + ($VMName) + (".vhdx")) 
        }

        New-VHD -Differencing @params | out-null

        # MountVHDXFile
        $VerbosePreference = "SilentlyContinue"
        Import-Module DISM
        $VerbosePreference = "Continue"

        Write-Verbose "Mounting $VMName VHD." 
        New-Item -Path "C:\TempWACMount" -ItemType Directory | Out-Null
        Mount-WindowsImage -Path "C:\TempWACMount" -Index 1 -ImagePath (($VHDPath) + ($VMName) + (".vhdx")) | Out-Null

        # Copy Source Files
        Write-Verbose "Copying Application and Script Source Files to $VMName"
        Copy-Item 'C:\VMConfigs\Windows Admin Center' -Destination C:\TempWACMount\ -Recurse -Force
        Copy-Item C:\VMConfigs\SDN -Destination C:\TempWACMount -Recurse -Force
        New-Item -Path C:\TempWACMount\VHDs -ItemType Directory -Force | Out-Null
        Copy-Item C:\VMs\Base\AzSHCI.vhdx -Destination C:\TempWACMount\VHDs -Force
        Copy-Item C:\VMs\Base\GUI.vhdx  -Destination  C:\TempWACMount\VHDs -Force

        # Create VM
        Write-Verbose "Creating the $VMName VM."

        $params = @{

            Name       = $VMName
            VHDPath    = (($VHDPath) + ($VMName) + (".vhdx")) 
            Path       = $VHDPath
            Generation = 2
        }

        New-VM @params | Out-Null

        $params = @{

            VMName               = $VMName
            DynamicMemoryEnabled = $true
            StartupBytes         = $HCIBoxConfig.MEM_WAC
            MaximumBytes         = $HCIBoxConfig.MEM_WAC
            MinimumBytes         = 500mb 
        }

        Set-VMMemory @params | Out-Null
        Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown | Out-Null

        Write-Verbose "Configuring $VMName's Networking"
        Remove-VMNetworkAdapter -VMName $VMName -Name "Network Adapter"
        Add-VMNetworkAdapter -VMName $VMName -Name "Fabric" -SwitchName "vSwitch-Fabric" -DeviceNaming On
        Set-VMNetworkAdapter -VMName $VMName -StaticMacAddress "10155D010B00"

        # Apply Custom Unattend.xml file
        New-Item -Path C:\TempWACMount\windows -ItemType Directory -Name Panther -Force | Out-Null
        $Password = $HCIBoxConfig.SDNAdminPassword
        $ProductKey = $HCIBoxConfig.GUIProductKey
        $Gateway = $HCIBoxConfig.SDNLABRoute
        $DNS = $HCIBoxConfig.SDNLABDNS
        $IPAddress = $HCIBoxConfig.WACIP
        $Domain = $HCIBoxConfig.SDNDomainFQDN

        $Unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ProductKey>$ProductKey</ProductKey>
            <ComputerName>$VMName</ComputerName>
            <RegisteredOwner>$ENV:USERNAME</RegisteredOwner>
        </component>
        <component name="Microsoft-Windows-TCPIP" processorArchitecture="wow64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Interfaces>
                <Interface wcm:action="add">
                    <Ipv4Settings>
                        <DhcpEnabled>false</DhcpEnabled>
                        <Metric>20</Metric>
                        <RouterDiscoveryEnabled>true</RouterDiscoveryEnabled>
                    </Ipv4Settings>
                    <UnicastIpAddresses>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$IPAddress</IpAddress>
                    </UnicastIpAddresses>
                    <Identifier>10-15-5D-01-0B-00</Identifier>
                    <Routes>
                        <Route wcm:action="add">
                            <Identifier>1</Identifier>
                            <NextHopAddress>$Gateway</NextHopAddress>
                        </Route>
                    </Routes>
                </Interface>
            </Interfaces>
        </component>
        <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Interfaces>
                <Interface wcm:action="add">
                    <DNSServerSearchOrder>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$DNS</IpAddress>
                    </DNSServerSearchOrder>
                    <Identifier>10-15-5D-01-0B-00</Identifier>
                    <DNSDomain>$Domain</DNSDomain>
                    <EnableAdapterDomainNameRegistration>true</EnableAdapterDomainNameRegistration>
                </Interface>
            </Interfaces>
        </component>
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
            <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
            <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
        </component>
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Identification>
                <Credentials>
                    <Domain>$Domain</Domain>
                    <Password>$Password</Password>
                    <Username>Administrator</Username>
                </Credentials>
                <JoinDomain>$Domain</JoinDomain>
            </Identification>
        </component>
        <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <IEHardenAdmin>false</IEHardenAdmin>
            <IEHardenUser>false</IEHardenUser>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <TimeZone>Pacific Standard Time</TimeZone>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipUserOOBE>true</SkipUserOOBE>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
            </OOBE>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>en-US</UserLocale>
            <SystemLocale>en-US</SystemLocale>
            <InputLocale>0409:00000409</InputLocale>
            <UILanguage>en-US</UILanguage>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@

        Write-Verbose "Mounting and Injecting Answer File into the $VMName VM." 
        Set-Content -Value $Unattend -Path "C:\TempWACMount\Windows\Panther\Unattend.xml" -Force

        # Save Customizations and then dismount.
        Write-Verbose "Dismounting Disk"
        Dismount-WindowsImage -Path "C:\TempWACMount" -Save | Out-Null
        Remove-Item "C:\TempWACMount"

        Write-Verbose "Setting $VMName's VM Configuration"
        Set-VMProcessor -VMName $VMname -Count 4
        set-vm -Name $VMName  -AutomaticStopAction TurnOff

        Write-Verbose "Starting $VMName VM."
        Start-VM -Name $VMName

        # Refresh Domain Cred
        $domainCred = new-object -typename System.Management.Automation.PSCredential `
            -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\$using:domainAdminUsername"), `
        (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

        # Wait until the VM is restarted
        while ((Invoke-Command -VMName $VMName -Credential $domainCred { "Test" } `
                    -ea SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 1 }

        # Finish Configuration
        Invoke-Command -VMName $VMName -Credential $domainCred -ArgumentList $HCIBoxConfig, $VMName -ScriptBlock {

            $HCIBoxConfig = $args[0]
            $VMName = $args[1]
            $Gateway = $HCIBoxConfig.SDNLABRoute
            $VerbosePreference = "Continue"
            $ErrorActionPreference = "Stop"

            $VerbosePreference = "SilentlyContinue"
            Import-Module NetAdapter
            $VerbosePreference = "Continue"

            # Enabling Remote Access on Admincenter VM
            Write-Verbose "Enabling Remote Access"
            Enable-WindowsOptionalFeature -FeatureName RasRoutingProtocols -All -LimitAccess -Online | Out-Null
            Enable-WindowsOptionalFeature -FeatureName RemoteAccessPowerShell -All -LimitAccess -Online | Out-Null

            Write-Verbose "Configuring WSMAN Trusted Hosts"
            Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force
            Enable-WSManCredSSP -Role Client -DelegateComputer * -Force

            Write-Verbose "Rename Network Adapter in $VMName VM" 
            Get-NetAdapter | Rename-NetAdapter -NewName Fabric

            # Set Gateway
            $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -eq "Fabric" }).InterfaceIndex
            $NetInterface = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.InterfaceIndex -eq $index }     
            $NetInterface.SetGateways($Gateway) | Out-Null

            $fqdn = $HCIBoxConfig.SDNDomainFQDN

            # Enable CredSSP
            $VerbosePreference = "SilentlyContinue" 
            Enable-PSRemoting -force
            Enable-WSManCredSSP -Role Server -Force
            Enable-WSManCredSSP -Role Client -DelegateComputer localhost -Force
            Enable-WSManCredSSP -Role Client -DelegateComputer $env:COMPUTERNAME -Force
            Enable-WSManCredSSP -Role Client -DelegateComputer $fqdn -Force
            Enable-WSManCredSSP -Role Client -DelegateComputer "*.$fqdn" -Force
            New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation `
                -Name AllowFreshCredentialsWhenNTLMOnly -Force
            New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly `
                -Name 1 -Value * -PropertyType String -Force

            $VerbosePreference = "Continue" 

            # Enable Large MTU
            Write-Verbose "Configuring MTU on all Adapters"
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Set-NetAdapterAdvancedProperty -RegistryValue $HCIBoxConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"   

            $WACIP = $HCIBoxConfig.WACIP.Split("/")[0]
    
            # Install RSAT-NetworkController
            $isAvailable = Get-WindowsFeature | Where-Object { $_.Name -eq 'RSAT-NetworkController' }

            if ($isAvailable) {
                Write-Verbose "Installing RSAT-NetworkController"
                
                $VerbosePreference = "SilentlyContinue"
                Import-Module ServerManager
                Install-WindowsFeature -Name RSAT-NetworkController -IncludeAllSubFeature -IncludeManagementTools | Out-Null
                $VerbosePreference = "Continue"
            }

            # Install Hyper-V RSAT
            Write-Verbose "Installing Hyper-V RSAT Tools"
            $VerbosePreference = "SilentlyContinue"
            Install-WindowsFeature -Name RSAT-Hyper-V-Tools -IncludeAllSubFeature -IncludeManagementTools | Out-Null
            $VerbosePreference = "Continue"

            # Install RSAT AD Tools
            Write-Verbose "Installing Active Directory RSAT Tools"
            $VerbosePreference = "SilentlyContinue"
            Install-WindowsFeature -Name  RSAT-ADDS -IncludeAllSubFeature -IncludeManagementTools | Out-Null
            $VerbosePreference = "Continue"

            # Install Failover Cluster RSAT Tools
            Write-Verbose "Installing Failover Clustering RSAT Tools"
            $VerbosePreference = "SilentlyContinue"
            Install-WindowsFeature -Name  RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell -IncludeAllSubFeature -IncludeManagementTools | Out-Null
            $VerbosePreference = "Continue"

            # Install DNS RSAT Tool
            Write-Verbose "Installing DNS Server RSAT Tools"
            $VerbosePreference = "SilentlyContinue"
            Install-WindowsFeature -Name RSAT-DNS-Server  -IncludeAllSubFeature -IncludeManagementTools | Out-Null
            $VerbosePreference = "Continue"

            # Install VPN Routing
            $VerbosePreference = "SilentlyContinue"
            Install-RemoteAccess -VPNType RoutingOnly | Out-Null
            $VerbosePreference = "Continue"

            # Install Nuget
            $VerbosePreference = "SilentlyContinue"
            Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force
            $VerbosePreference = "Continue"

            # Stop Server Manager from starting on boot
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -Value 1
            
            # Request SSL Certificate for Windows Admin Center
            Write-Verbose "Generating SSL Certificate Request"

            # Create BGP Router
            $params = @{
                BGPIdentifier  = $WACIP
                LocalASN       = $HCIBoxConfig.WACASN
                TransitRouting = 'Enabled'
                ClusterId      = 1
                RouteReflector = 'Enabled'
            }

            Add-BgpRouter @params

            $RequestInf = @"
[Version] 
Signature="`$Windows NT$"

[NewRequest] 
Subject = "CN=AdminCenter.$fqdn"
Exportable = True
KeyLength = 2048                    
KeySpec = 1                     
KeyUsage = 0xA0               
MachineKeySet = True 
ProviderName = "Microsoft RSA SChannel Cryptographic Provider" 
ProviderType = 12 
SMIME = FALSE 
RequestType = CMC
FriendlyName = "Nested SDN Windows Admin Cert"

[Strings] 
szOID_SUBJECT_ALT_NAME2 = "2.5.29.17" 
szOID_ENHANCED_KEY_USAGE = "2.5.29.37" 
szOID_PKIX_KP_SERVER_AUTH = "1.3.6.1.5.5.7.3.1" 
szOID_PKIX_KP_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"
[Extensions] 
%szOID_SUBJECT_ALT_NAME2% = "{text}dns=admincenter.$fqdn" 
%szOID_ENHANCED_KEY_USAGE% = "{text}%szOID_PKIX_KP_SERVER_AUTH%,%szOID_PKIX_KP_CLIENT_AUTH%"
[RequestAttributes] 
CertificateTemplate= WebServer
"@

            New-Item C:\WACCert -ItemType Directory -Force | Out-Null
            Set-Content -Value $RequestInf -Path C:\WACCert\WACCert.inf -Force | Out-Null

            $WACdomainCred = new-object -typename System.Management.Automation.PSCredential `
                -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)
            $WACVMName = "admincenter"
            $DCFQDN = $HCIBoxConfig.DCName + '.' + $HCIBoxConfig.SDNDomainFQDN
            $WACport = $HCIBoxConfig.WACport
            $HCIBoxConfig = $Using:SDNConfig
            $fqdn = $HCIBoxConfig.SDNDomainFQDN

            $params = @{
                Name                                = 'microsoft.SDNNested'
                RunAsCredential                     = $Using:domainCred 
                MaximumReceivedDataSizePerCommandMB = 1000
                MaximumReceivedObjectSizeMB         = 1000
            }

            $VerbosePreference = "SilentlyContinue"            
            Register-PSSessionConfiguration @params
            $VerbosePreference = "Continue"

            Write-Verbose "Requesting and installing SSL Certificate" 
            Invoke-Command -ComputerName $WACVMName -ConfigurationName microsoft.SDNNested -ArgumentList $WACVMName, $HCIBoxConfig, $DCFQDN -Credential $WACdomainCred -ScriptBlock {

                $DCFQDN = $args[2]
                $VerbosePreference = "Continue"
                $ErrorActionPreference = "Stop"

                # Get the CA Name
                $CertDump = certutil -dump
                $ca = ((((($CertDump.Replace('`', "")).Replace("'", "")).Replace(":", "=")).Replace('\', "")).Replace('"', "") `
                    | ConvertFrom-StringData).Name
                $CertAuth = $DCFQDN + '\' + $ca

                Write-Verbose "CA is: $ca"
                Write-Verbose "Certificate Authority is: $CertAuth"
                Write-Verbose "Certdump is $CertDump"

                # Request and Accept SSL Certificate
                Set-Location C:\WACCert
                certreq -q -f -new WACCert.inf WACCert.req
                certreq -q -config $CertAuth -attrib "CertificateTemplate:webserver" -submit WACCert.req  WACCert.cer 
                certreq -q -accept WACCert.cer
                certutil -q -store my

                Set-Location 'C:\'
                Remove-Item C:\WACCert -Recurse -Force

            } -Authentication Credssp

            $HCIBoxConfig = Import-PowerShellDataFile -Path C:\SDN\HCIBox-Config.psd1

            # Install Windows Admin Center
            $pfxThumbPrint = (Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object { $_.FriendlyName -match "Nested SDN Windows Admin Cert" }).Thumbprint
            Write-Verbose "Thumbprint: $pfxThumbPrint"
            Write-Verbose "WACPort: $WACPort"
            $WindowsAdminCenterGateway = "https://admincenter." + $fqdn
            Write-Verbose $WindowsAdminCenterGateway
            Write-Verbose "Installing and Configuring Windows Admin Center"
            $PathResolve = Resolve-Path -Path 'C:\Windows Admin Center\*.msi'
            $arguments = "/qn /L*v C:\log.txt SME_PORT=$WACport SME_THUMBPRINT=$pfxThumbPrint SSL_CERTIFICATE_OPTION=installed  SME_URL=$WindowsAdminCenterGateway"
            Start-Process -FilePath $PathResolve -ArgumentList $arguments -PassThru | Wait-Process
           
            # Create a shortcut for Windows PowerShell ISE
            Write-Verbose "Creating Shortcut for PowerShell ISE"
            $TargetFile = "c:\windows\system32\WindowsPowerShell\v1.0\powershell_ise.exe"
            $ShortcutFile = "C:\Users\Public\Desktop\PowerShell ISE.lnk"
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
            $Shortcut.TargetPath = $TargetFile
            $Shortcut.Save()

            # Create a shortcut for Windows PowerShell Console
            Write-Verbose "Creating Shortcut for PowerShell Console"
            $TargetFile = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
            $ShortcutFile = "C:\Users\Public\Desktop\PowerShell.lnk"
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
            $Shortcut.TargetPath = $TargetFile
            $Shortcut.Save()

            # Install Chocolatey
            $ErrorActionPreference = "Continue"
            Write-Verbose "Installing Chocolatey"
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Start-Sleep -Seconds 10

            # Install Azure PowerShell
            Write-Verbose 'Installing Az PowerShell'
            $expression = "choco install az.powershell -y"
            Invoke-Expression $expression
            $ErrorActionPreference = "Stop"
    
            # Create Shortcut for Hyper-V Manager
            Write-Verbose "Creating Shortcut for Hyper-V Manager"
            Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" `
                -Destination "C:\Users\Public\Desktop"

            # Create Shortcut for Failover-Cluster Manager
            Write-Verbose "Creating Shortcut for Failover-Cluster Manager"
            Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Failover Cluster Manager.lnk" `
                -Destination "C:\Users\Public\Desktop"

            # Create Shortcut for DNS
            Write-Verbose "Creating Shortcut for DNS Manager"
            Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DNS.lnk" `
                -Destination "C:\Users\Public\Desktop"

            # Create Shortcut for Active Directory Users and Computers
            Write-Verbose "Creating Shortcut for AD Users and Computers"
            Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Active Directory Users and Computers.lnk" `
                -Destination "C:\Users\Public\Desktop"
    
            # Set the SDNExplorer Script and place on desktop
            Write-Verbose "Configuring SDNExplorer"
            $SENCIP = "nc01." + $HCIBoxConfig.SDNDomainFQDN    
            $SDNEXPLORER = "Set-Location 'C:\VMConfigs\SDN';.\SDNExplorer.ps1 -NCIP $SENCIP"    
            Set-Content -Value $SDNEXPLORER -Path 'C:\users\Public\Desktop\SDN Explorer.ps1' -Force
    
            # Set Network Profiles
            Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq "Public" } `
            | Set-NetConnectionProfile -NetworkCategory Private | Out-Null    
    
            # Disable Automatic Updates
            $WUKey = "HKLM:\software\Policies\Microsoft\Windows\WindowsUpdate"
            New-Item -Path $WUKey -Force | Out-Null
            New-ItemProperty -Path $WUKey -Name AUOptions -PropertyType Dword -Value 2 `
                -Force | Out-Null  

            # Install Kubectl
            Write-Verbose 'Installing kubectl'
            $expression = "choco install kubernetes-cli -y"
            Invoke-Expression $expression
            $ErrorActionPreference = "Stop" 

            # Create a shortcut for Windows Admin Center
            Write-Verbose "Creating Shortcut for Windows Admin Center"
            if ($HCIBoxConfig.WACport -ne "443") { $TargetPath = "https://admincenter." + $HCIBoxConfig.SDNDomainFQDN + ":" + $HCIBoxConfig.WACport }
            else { $TargetPath = "https://admincenter." + $HCIBoxConfig.SDNDomainFQDN }
            $ShortcutFile = "C:\Users\Public\Desktop\Windows Admin Center.url"
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
            $Shortcut.TargetPath = $TargetPath
            $Shortcut.Save()

            # Disable Edge 'First Run' Setup
            $edgePolicyRegistryPath  = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
            $desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
            $firstRunRegistryName  = 'HideFirstRunExperience'
            $firstRunRegistryValue = '0x00000001'
            $savePasswordRegistryName = 'PasswordManagerEnabled'
            $savePasswordRegistryValue = '0x00000000'
            $autoArrangeRegistryName = 'FFlags'
            $autoArrangeRegistryValue = '1075839525'

            if (-NOT (Test-Path -Path $edgePolicyRegistryPath)) {
                New-Item -Path $edgePolicyRegistryPath -Force | Out-Null
            }
            if (-NOT (Test-Path -Path $desktopSettingsRegistryPath)) {
                New-Item -Path $desktopSettingsRegistryPath -Force | Out-Null
            }

            New-ItemProperty -Path $edgePolicyRegistryPath -Name $firstRunRegistryName -Value $firstRunRegistryValue -PropertyType DWORD -Force
            New-ItemProperty -Path $edgePolicyRegistryPath -Name $savePasswordRegistryName -Value $savePasswordRegistryValue -PropertyType DWORD -Force
            Set-ItemProperty -Path $desktopSettingsRegistryPath -Name $autoArrangeRegistryName -Value $autoArrangeRegistryValue -Force
        }
    } 
}

function New-HyperConvergedEnvironment {
    Param (
        $localCred,
        $domainCred
    )

    Invoke-Command -ComputerName Admincenter -Credential $domainCred -ScriptBlock {
        $HCIBoxConfig = $Using:SDNConfig

        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"

        $domainCred = new-object -typename System.Management.Automation.PSCredential `
            -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"), `
        (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

        foreach ($AzSHOST in $HCIBoxConfig.HostList) {
            Write-Verbose "Invoking Command on $AzSHOST"
            Invoke-Command -ComputerName $AzSHOST -ArgumentList $HCIBoxConfig -Credential $using:domainCred  -ScriptBlock {
                function New-sdnSETSwitch {
                    param (
                        $sdnswitchName, 
                        $sdnswitchIP, 
                        $sdnswitchIPpfx, 
                        $sdnswitchVLAN, 
                        $sdnswitchGW, 
                        $sdnswitchDNS, 
                        $sdnswitchteammembers
                    )

                    $VerbosePreference = "Continue"
                    Write-Verbose "Creating SET Hyper-V External Switch $sdnswitchName on host $env:COMPUTERNAME"
                    $params = @{

                        Name                  = $sdnswitchName
                        AllowManagementOS     = $true
                        NetAdapterName        = $sdnswitchteammembers
                        EnableEmbeddedTeaming = $true
                        MinimumBandwidthMode  = "Weight"
                    }
                    New-VMSwitch @params | Out-Null

                    # Set IP Config
                    Write-Verbose "Setting IP Configuration on $sdnswitchName"
                    $sdnswitchNIC = Get-Netadapter | Where-Object { $_.Name -match $sdnswitchName }

                    $params = @{
                        InterfaceIndex = $sdnswitchNIC.InterfaceIndex
                        IpAddress      = $sdnswitchIP 
                        PrefixLength   = $sdnswitchIPpfx 
                        AddressFamily  = 'IPv4'
                        DefaultGateway = $sdnswitchGW
                        ErrorAction    = 'SilentlyContinue'
                    }

                    New-NetIPAddress @params | Out-Null

                    # Set DNS
                    Set-DnsClientServerAddress -InterfaceIndex $sdnswitchNIC.InterfaceIndex -ServerAddresses ($sdnswitchDNS)

                    # Set VLAN 
                    Write-Verbose "Setting VLAN ($sdnswitchVLAN) on host vNIC"
                    $params = @{
                        IsolationMode        = 'Vlan'
                        DefaultIsolationID   = $sdnswitchVLAN 
                        AllowUntaggedTraffic = $true
                        VMNetworkAdapterName = $sdnswitchName
                    }
                    Set-VMNetworkAdapterIsolation -ManagementOS @params

                    # Disable Switch Extensions
                    Get-VMSwitchExtension -VMSwitchName $sdnswitchName | Disable-VMSwitchExtension | Out-Null

                    # Enable Large MTU
                    Write-Verbose "Configuring MTU on all Adapters"
                    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Set-NetAdapterAdvancedProperty -RegistryValue $HCIBoxConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"   

                }

                $ErrorActionPreference = "Stop"

                $HCIBoxConfig = $args[0]
                $sdnswitchteammembers = @("FABRIC", "FABRIC2")
                $sdnswitchIP = $HCIBoxConfig.($env:COMPUTERNAME + "IP").Split("/")[0]
                $sdnswitchIPpfx = $HCIBoxConfig.($env:COMPUTERNAME + "IP").Split("/")[1]
                $sdnswitchGW = $HCIBoxConfig.BGPRouterIP_MGMT.Split("/")[0]

                $sdnswitchCheck = Get-VMSwitch | Where-Object { $_.Name -eq "sdnSwitch" }

                if ($sdnswitchCheck) { Write-Warning "Switch already exists on $env:COMPUTERNAME. Skipping this host." }
                else {
                    $params = @{
                        sdnswitchName        = 'sdnSwitch'
                        sdnswitchIP          = $sdnswitchIP
                        sdnswitchIPpfx       = $sdnswitchIPpfx
                        sdnswitchVLAN        = $HCIBoxConfig.mgmtVLAN
                        sdnswitchGW          = $sdnswitchGW
                        sdnswitchDNS         = $HCIBoxConfig.SDNLABDNS
                        sdnswitchteammembers = $sdnswitchteammembers
                    }
                    New-sdnSETSwitch  @params | out-null
                }         
            } 
            
            Start-Sleep -Seconds 60

        }
    }
    # Wait until all the AzSHOSTs have been restarted
    foreach ($AzSHOST in $HCIBoxConfig.HostList) {
        Write-Verbose "Rebooting HCIBox Host $AzSHOST"
        Restart-Computer $AzSHOST -Force -Confirm:$false -Credential $localCred -Protocol WSMan
        Write-Verbose "Checking to see if $AzSHOST is up and online"
        while ((Invoke-Command -ComputerName $AzSHOST -Credential $localCred { "Test" } -ea SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 60 }
    }
}

function New-SDNEnvironment {
    Param (
        $domainCred,
        $HCIBoxConfig
    )

    Invoke-Command -ComputerName admincenter -Credential $domainCred -ScriptBlock {

        Register-PSSessionConfiguration -Name microsoft.SDNNestedSetup -RunAsCredential $domainCred -MaximumReceivedDataSizePerCommandMB 1000 -MaximumReceivedObjectSizeMB 1000 | Out-Null

        Invoke-Command -ComputerName localhost -Credential $Using:domainCred -ArgumentList $Using:domainCred, $Using:SDNConfig -ConfigurationName microsoft.SDNNestedSetup -ScriptBlock {       
            $NCConfig = @{ }

            $ErrorActionPreference = "Stop"
            $VerbosePreference = "Continue"

            # Set Credential Object
            $domainCred = $args[0]
            $HCIBoxConfig = $args[1]

            # Set fqdn
            $fqdn = $HCIBoxConfig.SDNDomainFQDN

            if ($HCIBoxConfig.ProvisionNC) {
                # Set NC Configuration Data
                $NCConfig.RestName = ("NC01.") + $HCIBoxConfig.SDNDomainFQDN
                $NCConfig.PASubnet = $HCIBoxConfig.ProviderSubnet
                $NCConfig.JoinDomain = $HCIBoxConfig.SDNDomainFQDN
                $NCConfig.ManagementGateway = ($HCIBoxConfig.BGPRouterIP_MGMT).Split("/")[0]
                $NCConfig.PublicVIPSubnet = $HCIBoxConfig.PublicVIPSubnet
                $NCConfig.PrivateVIPSubnet = $HCIBoxConfig.PrivateVIPSubnet
                $NCConfig.GRESubnet = $HCIBoxConfig.GRESubnet
                $NCConfig.LocalAdminDomainUser = ($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"
                $NCConfig.DomainJoinUsername = ($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"
                $NCConfig.NCUsername = ($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"
                $NCConfig.SDNMacPoolStart = "00-1D-D8-B7-1C-09"
                $NCConfig.SDNMacPoolEnd = "00:1D:D8:B7:1F:FF"
                $NCConfig.PAGateway = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "1"
                $NCConfig.PAPoolStart = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "5"
                $NCConfig.PAPoolEnd = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "254"
                $NCConfig.Capacity = "10000"
                $NCConfig.ScriptVersion = "2.0"
                $NCConfig.SDNASN = $HCIBoxConfig.SDNASN
                $NCConfig.ManagementVLANID = $HCIBoxConfig.mgmtVLAN
                $NCConfig.PAVLANID = $HCIBoxConfig.providerVLAN
                $NCConfig.PoolName = "DefaultAll"
                $NCConfig.VMLocation = "D:\SDNVMS"
                $NCConfig.VHDFile = "AzSHCI.vhdx"
                $NCConfig.VHDPath = "C:\VHDS"
                $NCConfig.ManagementSubnet = $HCIBoxConfig.MGMTSubnet
                $NCConfig.ProductKey = $HCIBoxConfig.COREProductKey
                $NCConfig.HyperVHosts = @("AzSHOST1.$fqdn", "AzSHOST2.$fqdn")
                $NCConfig.ManagementDNS = @(
                    ($HCIBoxConfig.BGPRouterIP_MGMT.Split("/")[0].TrimEnd("1")) + "254"
                ) 
                $NCConfig.Muxes = @(
                    @{
                        ComputerName = 'Mux01'
                        HostName     = "AzSHOST2.$($HCIBoxConfig.SDNDomainFQDN)"
                        ManagementIP = ($HCIBoxConfig.BGPRouterIP_MGMT.TrimEnd("1/24")) + "61"
                        MACAddress   = '00-1D-D8-B7-1C-01'
                        PAIPAddress  = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "4"
                        PAMACAddress = '00-1D-D8-B7-1C-02'
                    }
                )

                $NCConfig.Gateways = @(
                    @{
                        ComputerName = "GW01"
                        ManagementIP = ($HCIBoxConfig.BGPRouterIP_MGMT.TrimEnd("1/24")) + "62"
                        HostName     = "AzSHOST2.$($HCIBoxConfig.SDNDomainFQDN)"
                        FrontEndIP   = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "5"
                        MACAddress   = "00-1D-D8-B7-1C-03"
                        FrontEndMac  = "00-1D-D8-B7-1C-04"
                        BackEndMac   = "00-1D-D8-B7-1C-05"
                    },
                    @{
                        ComputerName = "GW02"
                        ManagementIP = ($HCIBoxConfig.BGPRouterIP_MGMT.TrimEnd("1/24")) + "63"
                        HostName     = "AzSHOST1.$($HCIBoxConfig.SDNDomainFQDN)"
                        FrontEndIP   = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "6"
                        MACAddress   = "00-1D-D8-B7-1C-06"
                        FrontEndMac  = "00-1D-D8-B7-1C-07"
                        BackEndMac   = "00-1D-D8-B7-1C-08"
                    }
                )

                $NCConfig.NCs = @{
                    MACAddress   = "00:1D:D8:B7:1C:00"
                    ComputerName = "NC01"
                    HostName     = "AzSHOST2.$($HCIBoxConfig.SDNDomainFQDN)"
                    ManagementIP = ($HCIBoxConfig.BGPRouterIP_MGMT.TrimEnd("1/24")) + "60"
                }

                $NCConfig.Routers = @(
                    @{
                        RouterASN       = $HCIBoxConfig.BGPRouterASN
                        RouterIPAddress = ($HCIBoxConfig.BGPRouterIP_ProviderNetwork).Split("/")[0]
                    }
                )

                # Start SDNExpress (Nested Version) Install
                Set-Location -Path 'C:\SDN'
                $params = @{
                    ConfigurationData    = $NCConfig
                    DomainJoinCredential = $domainCred
                    LocalAdminCredential = $domainCred
                    NCCredential         = $domainCred
                }

                .\SDNExpress.ps1 @params
            }

        } -Authentication Credssp
    } 
}

function New-SDNS2DCluster {
    param (
        $HCIBoxConfig,
        $domainCred,
        $AzStackClusterNode
    )

    $VerbosePreference = "Continue"    
    Invoke-Command -ComputerName $AzStackClusterNode -ArgumentList $HCIBoxConfig, $domainCred -Credential $domainCred -ScriptBlock {
         
        $HCIBoxConfig = $args[0]
        $domainCred = $args[1]
        $VerbosePreference = "SilentlyContinue"
        $ErrorActionPreference = "Stop"

        Register-PSSessionConfiguration -Name microsoft.SDNNestedS2D -RunAsCredential $domainCred -MaximumReceivedDataSizePerCommandMB 1000 -MaximumReceivedObjectSizeMB 1000 | Out-Null

        Invoke-Command -ComputerName $Using:AzStackClusterNode -ArgumentList $HCIBoxConfig, $domainCred -Credential $domainCred -ConfigurationName microsoft.SDNNestedS2D -ScriptBlock {

            $HCIBoxConfig = $args[0]

            # Create S2D Cluster
            $HCIBoxConfig = $args[0]
            $AzSHOSTs = @("AzSHOST1", "AzSHOST2")

            Write-Verbose "Creating Cluster: hciboxcluster"
            $VerbosePreference = "SilentlyContinue"
            Import-Module FailoverClusters 
            Import-Module Storage
            $VerbosePreference = "Continue"

            
            # Create Cluster
            $ClusterIP = ($HCIBoxConfig.MGMTSubnet.TrimEnd("0/24")) + "252"
            $ClusterName = "hciboxcluster"

            $VerbosePreference = "SilentlyContinue"
            New-Cluster -Name $ClusterName -Node $AzSHOSTs -StaticAddress $ClusterIP -NoStorage -WarningAction SilentlyContinue | Out-Null
            $VerbosePreference = "Continue"

            # Invoke Command to enable S2D on hciboxcluster        
            Enable-ClusterS2D -Confirm:$false -Verbose

            # Wait for Cluster Performance History Volume to be Created
            while (!$PerfHistory) {

            Write-Verbose "Waiting for Cluster Performance History volume to come online."
            Start-Sleep -Seconds 10            
            $PerfHistory = Get-ClusterResource | Where-Object {$_.Name -match 'ClusterPerformanceHistory'}
            if ($PerfHistory) {Write-Verbose "Cluster Perfomance History volume online." }            

            }

            Write-Verbose "Setting Physical Disk Media Type"

            Get-PhysicalDisk | Where-Object { $_.Size -lt 127GB } | Set-PhysicalDisk -MediaType HDD | Out-Null

            $params = @{
            
                FriendlyName            = "S2D_vDISK1" 
                FileSystem              = 'CSVFS_ReFS'
                StoragePoolFriendlyName = 'S2D on hciboxcluster'
                ResiliencySettingName   = 'Mirror'
                PhysicalDiskRedundancy  = 1
                AllocationUnitSize = 64KB
                
            }

            Write-Verbose "Creating Physical Disk"
            Start-Sleep -Seconds 60
            New-Volume @params -UseMaximumSize  | Out-Null

            # Set Virtual Environment Optimizations
            Write-Verbose "Setting Virtual Environment Optimizations"

            $VerbosePreference = "SilentlyContinue"
            Get-storagesubsystem clus* | set-storagehealthsetting -name “System.Storage.PhysicalDisk.AutoReplace.Enabled” -value “False”
            Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters -Name HwTimeout -Value 0x00007530
            $VerbosePreference = "Continue"
           
            # Rename Storage Network Adapters

        Write-Verbose "Renaming Storage Network Adapters"

        (Get-Cluster -Name hciboxcluster | Get-ClusterNetwork | Where-Object { $_.Address -eq ($HCIBoxConfig.storageAsubnet.Replace('/24', '')) }).Name = 'StorageA'
        (Get-Cluster -Name hciboxcluster | Get-ClusterNetwork | Where-Object { $_.Address -eq ($HCIBoxConfig.storageBsubnet.Replace('/24', '')) }).Name = 'StorageB'
        (Get-Cluster -Name hciboxcluster | Get-ClusterNetwork | Where-Object { $_.Address -eq ($HCIBoxConfig.MGMTSubnet.Replace('/24', '')) }).Name = 'Public'


        # Set Allowed Networks for Live Migration

        Write-Verbose "Setting allowed networks for Live Migration"

        Get-ClusterResourceType -Name "Virtual Machine" -Cluster hciboxcluster | Set-ClusterParameter -Cluster hciboxcluster -Name MigrationExcludeNetworks `
            -Value ([String]::Join(";", (Get-ClusterNetwork -Cluster hciboxcluster | Where-Object { $_.Name -notmatch "Storage" }).ID))

        } | Out-Null

    } 
}

function Test-InternetConnect {
    $testIP = $HCIBoxConfig.natDNS
    $ErrorActionPreference = "Stop"  
    $intConnect = Test-NetConnection -ComputerName $testip -Port 53

    if (!$intConnect.TcpTestSucceeded) {
        throw "Unable to connect to DNS by pinging $HCIBoxConfig.natDNS - Network access to this IP is required."
    }
}

function Set-HostNAT {
    param (
        $HCIBoxConfig
    )

    $switchExist = Get-NetAdapter | Where-Object { $_.Name -match $HCIBoxConfig.natHostVMSwitchName }
    if (!$switchExist) {
        Write-Verbose "Creating NAT Switch: $($HCIBoxConfig.natHostVMSwitchName)"
        # Create Internal VM Switch for NAT
        New-VMSwitch -Name $HCIBoxConfig.natHostVMSwitchName -SwitchType Internal | Out-Null

        Write-Verbose "Applying IP Address to NAT Switch: $($HCIBoxConfig.natHostVMSwitchName)"
        # Apply IP Address to new Internal VM Switch
        $intIdx = (Get-NetAdapter | Where-Object { $_.Name -match $HCIBoxConfig.natHostVMSwitchName }).ifIndex
        $natIP = $HCIBoxConfig.natHostSubnet.Replace("0/24", "1")
        New-NetIPAddress -IPAddress $natIP -PrefixLength 24 -InterfaceIndex $intIdx | Out-Null

        # Create NetNAT
        Write-Verbose "Creating new Net NAT"
        New-NetNat -Name $HCIBoxConfig.natHostVMSwitchName  -InternalIPInterfaceAddressPrefix $HCIBoxConfig.natHostSubnet | Out-Null
    }
}

function enable-singleSignOn {
    param (
        $HCIBoxConfig
    )

    $domainCred = new-object -typename System.Management.Automation.PSCredential -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"), (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

    Invoke-Command -ComputerName ("$($HCIBoxConfig.DCName).$($HCIBoxConfig.SDNDomainFQDN)") -ScriptBlock {
        Get-ADComputer -Filter * | Set-ADComputer -PrincipalsAllowedToDelegateToAccount (Get-ADComputer AdminCenter)
    } -Credential $domainCred
}

#endregion
   
#region Main
$guiVHDXPath = $HCIBoxConfig.guiVHDXPath
$azSHCIVHDXPath = $HCIBoxConfig.azSHCIVHDXPath
$HostVMPath = $HCIBoxConfig.HostVMPath
$InternalSwitch = $HCIBoxConfig.InternalSwitch
$natDNS = $HCIBoxConfig.natDNS
$natSubnet = $HCIBoxConfig.natSubnet
$natConfigure = $HCIBoxConfig.natConfigure   

Import-Module Hyper-V 

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = 'SilentlyContinue'

# Download HCIBox VHDs
Write-Host "Downloading HCIBox VHDs. This will take a while..."
BITSRequest -Params @{'Uri'='https://aka.ms/AAijhe3'; 'Filename'="$env:HCIBoxVHDDir\AZSHCI.vhdx" }
BITSRequest -Params @{'Uri'='https://aka.ms/AAij9n9'; 'Filename'="$env:HCIBoxVHDDir\GUI.vhdx"}
BITSRequest -Params @{'Uri'='https://partner-images.canonical.com/hyper-v/desktop/focal/current/ubuntu-focal-hyperv-amd64-ubuntu-desktop-hyperv.vhdx.zip'; 'Filename'="$env:HCIBoxVHDDir\Ubuntu.vhdx.zip"}
Expand-Archive -Path $env:HCIBoxVHDDir\Ubuntu.vhdx.zip -DestinationPath $env:HCIBoxVHDDir
Move-Item -Path $env:HCIBoxVHDDir\livecd.ubuntu-desktop-hyperv.vhdx -Destination $env:HCIBoxVHDDir\Ubuntu.vhdx

# Set-Credentials
$localCred = new-object -typename System.Management.Automation.PSCredential -argumentlist "Administrator", (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force)

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\Administrator"), `
    (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword  -AsPlainText -Force)

$NCAdminCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($HCIBoxConfig.SDNDomainFQDN.Split(".")[0]) + "\NCAdmin"), `
    (ConvertTo-SecureString $HCIBoxConfig.SDNAdminPassword  -AsPlainText -Force)
   
# Enable PSRemoting
Write-Host "Enabling PS Remoting on client..."
$VerbosePreference = "SilentlyContinue"
Enable-PSRemoting
Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force

###############################################################################
# Configure hyper-v host
###############################################################################
# Verify Internet Connectivity
Write-Host "Verifying internet connectivity"
Test-InternetConnect

Write-Host "Creating Internal Switch"
New-InternalSwitch -pswitchname $InternalSwitch -HCIBoxConfig $HCIBoxConfig

Write-Host "Creating NAT Switch"
Set-HostNAT -HCIBoxConfig $HCIBoxConfig

Write-Host "Configuring HCIBox-Client Hyper-V host"
Set-VMHost -VirtualHardDiskPath $HostVMPath -VirtualMachinePath $HostVMPath -EnableEnhancedSessionMode $true

# Copy the parent VHDX file to the specified Parent VHDX Path
Write-Host "Copying VHDX Files to Host virtualization drive"
$guipath = "$HostVMPath\GUI.vhdx"
$hcipath = "$HostVMPath\AzSHCI.vhdx"
Copy-Item -Path $HCIBoxConfig.guiVHDXPath -Destination $guipath -Force | Out-Null
Copy-Item -Path $HCIBoxConfig.azSHCIVHDXPath -Destination $hcipath -Force | Out-Null

################################################################################
# Create the three nested Virtual Machines 
################################################################################
# First create the Management VM (AzSMGMT)
$vmMacs = @()
$mgmtMac = New-ManagementVM -Name $($HCIBoxConfig.MgmtHostConfig.HostName) -VHDXPath "$HostVMPath\GUI.vhdx" -VMSwitch $InternalSwitch -HCIBoxConfig $HCIBoxConfig
$vmMacs += [PSCustomObject]@{
    Hostname = $($HCIBoxConfig.MgmtHostConfig.HostName)
    vmMAC    = $mac
}
Set-MGMTVHDX -VMMac $mgmtMac -HCIBoxConfig $HCIBoxConfig

# Create the HCI host node VMs
foreach ($VM in $HCIBoxConfig.NodeHostConfig) {
    $mac = New-HCINodeVM -Name $VM -VHDXPath $hcipath -VMSwitch $InternalSwitch -HCIBoxConfig $HCIBoxConfig
    $vmMacs += [PSCustomObject]@{
        Hostname = $VM.Hostname
        vmMAC    = $mac
    }
    Set-HCINodeVHDX -HostName $VM.Hostname -IPAddress $VM.IP -VMMac $mac  -HCIBoxConfig $HCIBoxConfig
}
    
# Start Virtual Machines
Write-Host "Starting VM: $($HCIBoxConfig.MgmtHostConfig.HostName)"
Start-VM -Name $HCIBoxConfig.MgmtHostConfig.HostName
foreach ($VM in $HCIBoxConfig.NodeHostConfig) {
    Write-Host "Starting VM: $($VM.Hostname)"
    Start-VM -Name $VM.Hostname
}

#######################################################################################
# Prep virtual machines
#######################################################################################
# Wait for AzSHOSTs to come online
Test-AllVMsAvailable -HCIBoxConfig $HCIBoxConfig -Credential $localCred

# Format and partition data drives
Set-DataDrives -HCIBoxConfig -Credential $localCred
    
# Set-SDNserver needs to be looked at - not sure this is necessary for 23h2
Set-NICs -HCIBoxConfig $HCIBoxConfig -Credential $localCred
    
# Restart Machines
foreach ($VM in $HCIBoxConfig.NodeHostConfig) {
    Write-Host "Restarting VM: $($VM.Hostname)"
    Invoke-Command -VMName $VM.Hostname -Credential $localCred -ScriptBlock {
        Restart-Computer -Force
    }
}
Invoke-Command -VMName $HCIBoxConfig.MgmtHostName -Credential $localCred -ScriptBlock {
    Write-Host "Restarting VM: $($HCIBoxConfig.MgmtHostName)"
    Restart-Computer -Force
}
Start-Sleep -Seconds 30
    
# Wait for AzSHOSTs to come online
Test-AllVMsAvailable -HCIBoxConfig $HCIBoxConfig -Credential $localCred

# This step has to be done as during the Hyper-V install as hosts reboot twice.
Test-AllVMsAvailable -HCIBoxConfig $HCIBoxConfig -Credential $localCred
    
# Create NAT Virtual Switch on AzSMGMT
$SwitchName = $HCIBoxConfig.InternalSwitch 
Write-Verbose "Creating NAT Switch on switch $SwitchName"
$VerbosePreference = "SilentlyContinue"
$params = @{
    SwitchName  = $SwitchName
    VMPlacement = $VMPlacement
    SDNConfig   = $HCIBoxConfig
}
New-NATSwitch  @params
$VerbosePreference = "Continue"

# Provision AzSMGMT VMs (DC, Router, and AdminCenter)
Write-Verbose  "Configuring Management VM"
$params = @{
    SDNConfig  = $HCIBoxConfig
    localCred  = $localCred
    domainCred = $domainCred
}
Set-AzSMGMT @params

# Provision Hyper-V Logical Switches and Create S2D Cluster on Hosts
$params = @{
    localCred  = $localCred
    domainCred = $domainCred
}
New-HyperConvergedEnvironment @params

# Create S2D Cluster
$params = @{
    SDNConfig          = $HCIBoxConfig
    DomainCred         = $domainCred
    AzStackClusterNode = 'AzSHOST2'
}
New-SDNS2DCluster @params

# Install and Configure Network Controller if specified
If ($HCIBoxConfig.ProvisionNC) {
    $params = @{
        SDNConfig  = $HCIBoxConfig
        domainCred = $domainCred
    }
    New-SDNEnvironment @params

    # Add Systems to Windows Admin Center
    $fqdn = $HCIBoxConfig.SDNDomainFQDN

    $SDNLabSystems = @("bgp-tor-router", "$($HCIBoxConfig.DCName).$fqdn", "NC01.$fqdn", "MUX01.$fqdn", "GW01.$fqdn", "GW02.$fqdn")

    # Add VMs for Domain Admin

    $params = @{

        SDNLabSystems = $SDNLabSystems 
        SDNConfig     = $HCIBoxConfig
        domainCred    = $domainCred

    }

    #   Add-WACtenants @params


    # Add VMs for NC Admin

    $params.domainCred = $NCAdminCred

    #   Add-WACtenants @params

    # Enable Single Sign On

    Write-Verbose "Enabling Single Sign On in WAC"
    enable-singleSignOn -SDNConfig $HCIBoxConfig 
    
}


# Finally - Add RDP Link to Desktop

Remove-Item C:\Users\Public\Desktop\AdminCenter.lnk -Force -ErrorAction SilentlyContinue
$wshshell = New-Object -ComObject WScript.Shell
$lnk = $wshshell.CreateShortcut("C:\Users\Public\Desktop\AdminCenter.lnk")
$lnk.TargetPath = "%windir%\system32\mstsc.exe"
$lnk.Arguments = "/v:AdminCenter"
$lnk.Description = "AdminCenter link for HCIBox."
$lnk.Save()

$endtime = Get-Date

$timeSpan = New-TimeSpan -Start $starttime -End $endtime

Write-Verbose "`nSuccessfully deployed HCIBox cluster." 
Write-Verbose "Now working on enabling HCIBox features."
Write-Host "Infrastructure deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes." -ForegroundColor Green
 
$ErrorActionPreference = "Continue"
$VerbosePreference = "SilentlyContinue"
$WarningPreference = "Continue"

Stop-Transcript 

#endregion    