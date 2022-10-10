# --------------------------------------------------------------
#  Copyright © Microsoft Corporation.  All Rights Reserved.
#  Microsoft Corporation (or based on where you live, one of its affiliates) licenses this sample code for your internal testing purposes only.
#  Microsoft provides the following sample code AS IS without warranty of any kind. The sample code arenot supported under any Microsoft standard support program or services.
#  Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
#  The entire risk arising out of the use or performance of the sample code remains with you.
#  In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the code be liable for any damages whatsoever
#  (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss)
#  arising out of the use of or inability to use the sample code, even if Microsoft has been advised of the possibility of such damages.
# ---------------------------------------------------------------

$VerbosePreference = 'Continue'

<#

ooooo      ooo   .oooooo.          .oooooo.                                    .             
`888b.     `8'  d8P'  `Y8b        d8P'  `Y8b                                 .o8             
 8 `88b.    8  888               888          oooo d8b  .ooooo.   .oooo.   .o888oo  .ooooo.  
 8   `88b.  8  888               888          `888""8P d88' `88b `P  )88b    888   d88' `88b 
 8     `88b.8  888               888           888     888ooo888  .oP"888    888   888ooo888 
 8       `888  `88b    ooo       `88b    ooo   888     888    .o d8(  888    888 . 888    .o 
o8o        `8   `Y8bood8P'        `Y8bood8P'  d888b    `Y8bod8P' `Y888""8o   "888" `Y8bod8P' 
                                                                                             
                                                                                             
                                                                                                                                                                                                                                                                           
#>
function New-SDNExpressNetworkController
{
    param(
        [String[]] $ComputerNames,
        [String] $RESTName,
        [String] $ManagementSecurityGroupName = "",
        [String] $ClientSecurityGroupName = "",
        [PSCredential] $Credential = $null,
        [Switch] $Force
    )
    write-sdnexpresslog "New-SDNExpressNetworkController"
    write-sdnexpresslog "  -ComputerNames: $ComputerNames"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -ManagementSecurityGroup: $ManagementSecurityGroup"
    write-sdnexpresslog "  -ClientSecurityGroup: $ClientSecurityGroup"
    write-sdnexpresslog "  -Force: $Force"

    $RESTName = $RESTNAme.ToUpper()

    write-sdnexpresslog ("Checking if Controller already deployed by looking for REST response.")
    try { 
        get-networkcontrollerCredential -ConnectionURI "https://$RestName" -Credential $Credential  | out-null
        if (!$force) {
            write-sdnexpresslog "Network Controller at $RESTNAME already exists, exiting New-SDNExpressNetworkController."
            return
        }
    }
    catch {
        write-sdnexpresslog "Network Controller does not exist, will continue."
    }

    write-sdnexpresslog "Setting properties and adding NetworkController role on all computers in parallel."
    invoke-command -ComputerName $ComputerNames {
        reg add hklm\system\currentcontrolset\services\tcpip6\parameters /v DisabledComponents /t REG_DWORD /d 255 /f | out-null
        Set-Item WSMan:\localhost\Shell\MaxConcurrentUsers -Value 100 | out-null
        Set-Item WSMan:\localhost\MaxEnvelopeSizekb -Value 7000 | out-null

        add-windowsfeature NetworkController -IncludeAllSubFeature -IncludeManagementTools -Restart | out-null
    }

    write-sdnexpresslog "Creating local temp directory."

    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force
    $TempDir = $TempFile.FullName
    New-Item -ItemType Directory -Force -Path $TempDir | out-null

    write-sdnexpresslog "Temp directory is: $($TempFile.FullName)"
    write-sdnexpresslog "Creating REST cert on: $($computernames[0])"

    $RestCertPfxData = invoke-command -computername $ComputerNames[0] {
        param(
            [String] $RestName
        )
        $verbosepreference=$using:verbosepreference

        $Cert = get-childitem "Cert:\localmachine\my" | where {$_.Subject.ToUpper().StartsWith("CN=$RestName".ToUpper())}

        if ($Cert -eq $Null) {
            write-verbose "Creating new REST certificate." 
            $Cert = New-SelfSignedCertificate -Type Custom -KeySpec KeyExchange -Subject "CN=$RESTName" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\LocalMachine\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2")
        } else {
            write-verbose "Found existing REST certficate." 
            $HasServerEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.1"}) -ne $null
            $HasClientEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.2"}) -ne $null
        
            if (!$HasServerEku) {
                throw "Rest cert exists on $(hostname) but is missing the EnhancedKeyUsage for Server Authentication."
            }
            if (!$HasClientEku) {
                throw "Rest cert exists but $(hostname) is missing the EnhancedKeyUsage for Client Authentication."
            }
            write-verbose "Existing certificate meets criteria.  Exporting." 
        }

        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force | out-null
        [System.io.file]::WriteAllBytes($TempFile.FullName, $cert.Export("PFX", "secret"))
        $CertData = Get-Content $TempFile.FullName -Encoding Byte
        Remove-Item $TempFile.FullName -Force | out-null

        return $CertData
    
    } -ArgumentList $RestName

    write-sdnexpresslog "Temporarily exporting Cert to My store."
    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force
    $RestCertPfxData | set-content $TempFile.FullName -Encoding Byte
    $pwd = ConvertTo-SecureString "secret" -AsPlainText -Force  
    $cert = import-pfxcertificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\my" -password $pwd -exportable
    Remove-Item $TempFile.FullName -Force

    $RESTCertThumbprint = $cert.Thumbprint
    write-sdnexpresslog "REST cert thumbprint: $RESTCertThumbprint"
    write-sdnexpresslog "Exporting REST cert to PFX and CER in temp directory."
    
    [System.io.file]::WriteAllBytes("$TempDir\$RESTName.pfx", $cert.Export("PFX", "secret"))
    Export-Certificate -Type CERT -FilePath "$TempDir\$RESTName" -cert $cert | out-null
    
    write-sdnexpresslog "Importing REST cert (public key only) into Root store."
    import-certificate -filepath "$TempDir\$RESTName" -certstorelocation "cert:\localmachine\root" | out-null

    write-sdnexpresslog "Deleting REST cert from My store."
    remove-item -path cert:\localmachine\my\$RESTCertThumbprint

    write-sdnexpresslog "Installing REST cert to my and root store of each NC node."

    foreach ($ncnode in $ComputerNames) {
        write-sdnexpresslog "Installing REST cert to my and root store of: $ncnode"
        invoke-command -computername $ncnode {
            param(
                [String] $RESTName,
                [byte[]] $RESTCertPFXData,
                [String] $RESTCertThumbprint
            )

            $pwd = ConvertTo-SecureString "secret" -AsPlainText -Force  

            $TempFile = New-TemporaryFile
            Remove-Item $TempFile.FullName -Force
            $RESTCertPFXData | set-content $TempFile.FullName -Encoding Byte

            $Cert = get-childitem "Cert:\localmachine\my" | where {$_.Subject.ToUpper().StartsWith("CN=$RestName".ToUpper())}

            if ($Cert -eq $null) {
                $cert = import-pfxcertificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\my" -password $pwd -Exportable
            } else {
                if ($cert.Thumbprint -ne $RestCertThumbprint) {
                    Remove-Item $TempFile.FullName -Force
                    throw "REST cert already exists in My store on $(hostname), but thumbprint does not match cert on other nodes."
                }
            }
            
            $targetCertPrivKey = $Cert.PrivateKey 
            $privKeyCertFile = Get-Item -path "$ENV:ProgramData\Microsoft\Crypto\RSA\MachineKeys\*"  | where {$_.Name -eq $targetCertPrivKey.CspKeyContainerInfo.UniqueKeyContainerName} 
            $privKeyAcl = Get-Acl $privKeyCertFile
            $permission = "NT AUTHORITY\NETWORK SERVICE","Read","Allow" 
            $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission 
            $privKeyAcl.AddAccessRule($accessRule) 
            Set-Acl $privKeyCertFile.FullName $privKeyAcl

            $Cert = get-childitem "Cert:\localmachine\root\$RestCertThumbprint" -erroraction Ignore
            if ($cert -eq $Null) {
                $cert = import-pfxcertificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\root" -password $pwd
            }

            Remove-Item $TempFile.FullName -Force
        } -Argumentlist $RESTName, $RESTCertPFXData, $RESTCertThumbprint

    }

    # Create Node cert for each NC

    foreach ($ncnode in $ComputerNames) {
        write-sdnexpresslog "Creating node cert for: $ncnode"

        [byte[]] $CertData = invoke-command -computername $ncnode {

            # Set Trusted Hosts
            Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force

            $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
            $Cert = get-childitem "Cert:\localmachine\my" | where {$_.Subject.ToUpper().StartsWith("CN=$NodeFQDN".ToUpper())}

            if ($Cert -eq $null) {
                $cert = New-SelfSignedCertificate -Type Custom -KeySpec KeyExchange -Subject "CN=$NodeFQDN" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\LocalMachine\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2")
            } else {
                $HasServerEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.1"}) -ne $null
                $HasClientEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.2"}) -ne $null
            
                if (!$HasServerEku) {
                    throw "Node cert exists on $(hostname) but is missing the EnhancedKeyUsage for Server Authentication."
                }
                if (!$HasClientEku) {
                    throw "Node cert exists but $(hostname) is missing the EnhancedKeyUsage for Client Authentication."
                }
            }

            $targetCertPrivKey = $Cert.PrivateKey 
            $privKeyCertFile = Get-Item -path "$ENV:ProgramData\Microsoft\Crypto\RSA\MachineKeys\*"  | where {$_.Name -eq $targetCertPrivKey.CspKeyContainerInfo.UniqueKeyContainerName} 
            $privKeyAcl = Get-Acl $privKeyCertFile
            $permission = "NT AUTHORITY\NETWORK SERVICE","Read","Allow" 
            $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission 
            $privKeyAcl.AddAccessRule($accessRule) 
            Set-Acl $privKeyCertFile.FullName $privKeyAcl

            $TempFile = New-TemporaryFile
            Remove-Item $TempFile.FullName -Force | out-null
            [System.io.file]::WriteAllBytes($TempFile.FullName, $cert.Export("PFX", "secret"))
            $CertData = Get-Content $TempFile.FullName -Encoding Byte
            Remove-Item $TempFile.FullName -Force | out-null

            return $CertData
        }

        foreach ($othernode in $ComputerNames) {
            write-sdnexpresslog "Installing node cert for $ncnode into root store of $othernode."

            invoke-command -computername $othernode {
                param(
                    [Byte[]] $CertData
                )
                
                $TempFile = New-TemporaryFile
                Remove-Item $TempFile.FullName -Force
    
                $CertData | set-content $TempFile.FullName -Encoding Byte
                $pwd = ConvertTo-SecureString "secret" -AsPlainText -Force  
                $cert = import-pfxcertificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\root" -password $pwd
                Remove-Item $TempFile.FullName -Force
            } -ArgumentList (,$CertData)                
        }
    }

    write-sdnexpresslog "Configuring Network Controller role using node: $($ComputerNames[0])"
    invoke-command -computername $ComputerNames[0] {
        param(
            [String] $RestName,
            [String] $ManagementSecurityGroup,
            [String] $ClientSecurityGroup,
            [String[]] $ComputerNames,
            [PSCredential] $Credential
        )
        $SelfFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

        try { $controller = get-networkcontroller -erroraction Ignore } catch {}
        if ($controller -ne $null) {
            if ($force) {
                uninstall-networkcontroller -force
                uninstall-networkcontrollercluster -force
            } else {
                return
            }
        } 

        $Nodes = @()

        foreach ($server in $ComputerNames) {
            $NodeFQDN = "$server."+(Get-WmiObject win32_computersystem).Domain

            $cert = get-childitem "Cert:\localmachine\root" | where {$_.Subject.ToUpper().StartsWith("CN=$nodefqdn".ToUpper())}

            $nic = get-netadapter 
            if ($nic.count -gt 1) {
                write-verbose ("WARNING: Invalid number of network adapters found in network Controller node.")    
                write-verbose ("WARNING: Using first adapter returned: $($nic[0].name)")
                $nic = $nic[0]    
            } elseif ($nic.count -eq 0) {
                write-verbose ("ERROR: No network adapters found in network Controller node.")
                throw "Network controller node requires at least one network adapter."
            }

            $nodes += New-NetworkControllerNodeObject -Name $server -Server $NodeFQDN -FaultDomain ("fd:/"+$server) -RestInterface $nic.Name -NodeCertificate $cert -verbose                    
        }

        $RESTCert = get-childitem "Cert:\localmachine\root" | where {$_.Subject.ToUpper().StartsWith("CN=$RESTName".ToUpper())}

        $params = @{
            'Node'=$nodes;
            'CredentialEncryptionCertificate'=$RESTCert;
            'Credential'=$Credential;
        }

        if ([string]::isnullorempty($ManagementSecurityGroupName)) {
            $params.add('ClusterAuthentication', 'X509');
        } else {
            $params.add('ClusterAuthentication', 'Kerberos');
            $params.add('ManagementSecurityGroup', $ManagementSecurityGroup)
        }

        Install-NetworkControllerCluster @Params -Force | out-null

        $params = @{
            'Node'=$nodes;
            'ServerCertificate'=$RESTCert;
            'Credential'=$Credential;
        }

        if ([string]::isnullorempty($ClientSecurityGroupName)) {
            $params.add('ClientAuthentication', 'None');
        } else {
            $params.add('ClusterAuthentication', 'Kerberos');
            $params.add('ClientSecurityGroup', $ClientSecurityGroup)
        }

        if (![string]::isnullorempty($RestIpAddress)) {
            $params.add('RestIPAddress', 'addr/bits');
        } else {
            $params.add('RestName', $RESTName);
        }

        Install-NetworkController @params -force | out-null

    } -ArgumentList $RestName, $ManagementSecurityGroup, $ClientSecurityGroup, $ComputerNames, $Credential
    
    Write-SDNExpressLog "Network Controller cluster creation complete."
    #Verify that SDN REST endpoint is working before returning

    $dnsServers = (Get-DnsClientServerAddress -AddressFamily ipv4).ServerAddresses | select -uniq
    $dnsWorking = $true

    foreach ($dns in $dnsServers)
    {
        $dnsResponse = $null
        $count = 0

        while (($dnsResponse -eq $null) -or ($count -eq 30)) {
            $dnsResponse = Resolve-DnsName -name $RESTName -Server $dns -ErrorAction Ignore
            if ($dnsREsponse -eq $null) {
                sleep 10
            }
            $count++
        }

        if ($count -eq 30) {
            write-sdnexpresslog "REST name not resolving from $dns after 5 minutes."
            $dnsWorking = $false
        } else {
            write-sdnexpresslog "REST name resolved from $dns after $count tries."
        }
    }

    if (!$dnsWorking) {
        return
    }

    write-sdnexpresslog ("Checking for REST response.")
    $NotResponding = $true
    while ($NotResponding) {
        try { 
            $NotResponding = $false
            get-networkcontrollerCredential -ConnectionURI "https://$RestName" -Credential $Credential  | out-null
        }
        catch {
            write-sdnexpresslog "Network Controller is not responding.  Will try again in 10 seconds."
            sleep 10
            $NotResponding = $true
        }
    }

    write-sdnexpresslog ("Network controller setup is complete and ready to use.")
    write-sdnexpresslog "New-SDNExpressNetworkController Exit"
}





<#

ooooo      ooo   .oooooo.          .oooooo.                          .o88o.  o8o             
`888b.     `8'  d8P'  `Y8b        d8P'  `Y8b                         888 `"  `"'             
 8 `88b.    8  888               888           .ooooo.  ooo. .oo.   o888oo  oooo   .oooooooo 
 8   `88b.  8  888               888          d88' `88b `888P"Y88b   888    `888  888' `88b  
 8     `88b.8  888               888          888   888  888   888   888     888  888   888  
 8       `888  `88b    ooo       `88b    ooo  888   888  888   888   888     888  `88bod8P'  
o8o        `8   `Y8bood8P'        `Y8bood8P'  `Y8bod8P' o888o o888o o888o   o888o `8oooooo.  
                                                                                  d"     YD  
                                                                                  "Y88888P'  
                                                                                             
#>
function New-SDNExpressVirtualNetworkManagerConfiguration
{
    param(
        [String] $RestName,
        [String] $MacAddressPoolStart,
        [String] $MacAddressPoolEnd,
        [Object] $NCHostCert,
        [String] $NCUsername,
        [String] $NCPassword,
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressVirtualNetworkManagerConfiguration"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -MacAddressPoolEnd: $MacAddressPoolStart"
    write-sdnexpresslog "  -NCHostCert: $($NCHostCert.Thumbprint)"
    write-sdnexpresslog "  -NCUsername: $NCUsername"
    write-sdnexpresslog "  -NCPassword: ********"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"

    $MacAddressPoolStart = [regex]::matches($MacAddressPoolStart.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
    $MacAddressPoolEnd = [regex]::matches($MacAddressPoolEnd.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"

    $MacPoolProperties = new-object Microsoft.Windows.NetworkController.MacPoolProperties
    $MacPoolProperties.StartMacAddress = $MacAddressPoolStart
    $MacPoolProperties.EndMacAddress = $MacAddressPoolEnd
    $MacPoolObject = New-NetworkControllerMacPool -connectionuri $uri -ResourceId "DefaultMacPool" -properties $MacPoolProperties -Credential $Credential -Force

    $CredentialProperties = new-object Microsoft.Windows.NetworkController.CredentialProperties
    $CredentialProperties.Type = "X509Certificate"
    $CredentialProperties.Value = $NCHostCert.thumbprint
    $HostCertObject = New-NetworkControllerCredential -ConnectionURI $uri -ResourceId "NCHostCert" -properties $CredentialProperties -Credential $Credential -force    

    $CredentialProperties = new-object Microsoft.Windows.NetworkController.CredentialProperties
    $CredentialProperties.Type = "UsernamePassword"
    $CredentialProperties.UserName = $NCUsername
    $CredentialProperties.Value = $NCPassword
    $HostUserObject = New-NetworkControllerCredential -ConnectionURI $uri -ResourceId "NCHostUser" -properties $CredentialProperties -Credential $Credential -force    

    try {
        $LogicalNetworkObject = get-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "HNVPA" -Credential $Credential
    } 
    catch
    {
        $LogicalNetworkProperties = new-object Microsoft.Windows.NetworkController.LogicalNetworkProperties
        $LogicalNetworkProperties.NetworkVirtualizationEnabled = $true
        $LogicalNetworkObject = New-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "HNVPA" -properties $LogicalNetworkProperties -Credential $Credential -Force
    }
    write-sdnexpresslog "New-SDNExpressVirtualNetworkManagerConfiguration Exit"
}





function Add-SDNExpressVirtualNetworkPASubnet
{
    param(
        [String] $RestName,
        [String] $AddressPrefix,
        [String] $VLANID,
        [String[]] $DefaultGateways,
        [Object] $IPPoolStart,
        [String] $IPPoolEnd,
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressVirtualNetworkPASubnet"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -AddressPrefix: $AddressPrefix"
    write-sdnexpresslog "  -VLANID: $VLANID"
    write-sdnexpresslog "  -DefaultGateways: $DefaultGateways"
    write-sdnexpresslog "  -IPPoolStart: $IPPoolStart"
    write-sdnexpresslog "  -IPPoolStart: $IPPoolEnd"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"

    $PALogicalSubnets = get-networkcontrollerLogicalSubnet -Connectionuri $URI -LogicalNetworkId "HNVPA" -Credential $Credential
    $PALogicalSubnet = $PALogicalSubnets | where {$_.properties.AddressPrefix -eq $AddressPrefix}
    
    if ($PALogicalSubnet -eq $null) {
        $LogicalSubnetProperties = new-object Microsoft.Windows.NetworkController.LogicalSubnetProperties
        $logicalSubnetProperties.VLANId = $VLANID
        $LogicalSubnetProperties.AddressPrefix = $AddressPrefix
        $LogicalSubnetProperties.DefaultGateways = $DefaultGateways
    
        $LogicalSubnetObject = New-NetworkControllerLogicalSubnet -ConnectionURI $uri -LogicalNetworkId "HNVPA" -ResourceId $AddressPrefix.Replace("/", "_") -properties $LogicalSubnetProperties -Credential $Credential -Force
    }
    
    $IPpoolProperties = new-object Microsoft.Windows.NetworkController.IPPoolproperties
    $ippoolproperties.startipaddress = $IPPoolStart
    $ippoolproperties.endipaddress = $IPPoolEnd

    $IPPoolObject = New-networkcontrollerIPPool -ConnectionURI $uri -NetworkId "HNVPA" -SubnetId $AddressPrefix.Replace("/", "_") -ResourceID $AddressPrefix.Replace("/", "_") -Properties $IPPoolProperties -force -Credential $Credential

    write-sdnexpresslog "New-SDNExpressVirtualNetworkPASubnet Exit"
}







function New-SDNExpressLoadBalancerManagerConfiguration
{
    param(
        [String] $RestName,
        [String] $PrivateVIPPrefix,
        [String] $PublicVIPPrefix,
        [String] $SLBMVip = (Get-IPv4AddressInSubnet -subnet $PrivateVIPPrefix -offset 1),
        [String] $PrivateVIPPoolStart = (Get-IPv4AddressInSubnet -subnet $PrivateVIPPrefix -offset 1),
        [String] $PrivateVIPPoolEnd = (Get-IPv4LastAddressInSubnet -subnet $PrivateVIPPrefix),
        [String] $PublicVIPPoolStart = (Get-IPv4AddressInSubnet -subnet $PublicVIPPrefix -offset 1),
        [String] $PublicVIPPoolEnd = (Get-IPv4LastAddressInSubnet -subnet $PublicVIPPrefix),
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressLoadBalancerManagerConfiguration"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -PrivateVIPPrefix: $PrivateVipPrefix"
    write-sdnexpresslog "  -PublicVIPPrefix: $PublicVIPPrefix"
    write-sdnexpresslog "  -SLBMVip: $SLBMVip"
    write-sdnexpresslog "  -PrivateVIPPoolStart: $PrivateVIPPoolStart"
    write-sdnexpresslog "  -PrivateVIPPoolEnd: $PrivateVIPPoolEnd"
    write-sdnexpresslog "  -PublicVIPPoolStart: $PublicVIPPoolStart"
    write-sdnexpresslog "  -PublicVIPPoolEnd: $PrivateVIPPoolEnd"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"

    #PrivateVIP LN
    try
    {
        $PrivateVIPLNObject = Get-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "PrivateVIP" -Credential $Credential
    }
    catch 
    {
        $LogicalNetworkProperties = new-object Microsoft.Windows.NetworkController.LogicalNetworkProperties
        $LogicalNetworkProperties.NetworkVirtualizationEnabled = $false
        $LogicalNetworkProperties.Subnets = @()
        $LogicalNetworkProperties.Subnets += new-object Microsoft.Windows.NetworkController.LogicalSubnet
        $logicalNetworkProperties.Subnets[0].ResourceId = $PrivateVIPPrefix.Replace("/", "_")
        $logicalNetworkProperties.Subnets[0].Properties = new-object Microsoft.Windows.NetworkController.LogicalSubnetProperties
        $logicalNetworkProperties.Subnets[0].Properties.AddressPrefix = $PrivateVIPPrefix
        $logicalNetworkProperties.Subnets[0].Properties.DefaultGateways = @(Get-IPv4AddressInSubnet -subnet $PrivateVIPPrefix)

        $PrivateVIPLNObject = New-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "PrivateVIP" -properties $LogicalNetworkProperties -Credential $Credential -Force
    }

    $IPpoolProperties = new-object Microsoft.Windows.NetworkController.IPPoolproperties
    $ippoolproperties.startipaddress = $PrivateVIPPoolStart
    $ippoolproperties.endipaddress = $PrivateVIPPoolEnd

    $PrivatePoolObject = new-networkcontrollerIPPool -ConnectionURI $uri -NetworkId "PrivateVIP" -SubnetId $PrivateVIPPrefix.Replace("/", "_") -ResourceID $PrivateVIPPrefix.Replace("/", "_") -Properties $IPPoolProperties -force
    
    #PublicVIP LN
    try
    {
        $PublicVIPLNObject = get-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "PublicVIP" -Credential $Credential
    }
    catch 
    {
        $LogicalNetworkProperties = new-object Microsoft.Windows.NetworkController.LogicalNetworkProperties
        $LogicalNetworkProperties.NetworkVirtualizationEnabled = $false
        $LogicalNetworkProperties.Subnets = @()
        $LogicalNetworkProperties.Subnets += new-object Microsoft.Windows.NetworkController.LogicalSubnet
        $logicalNetworkProperties.Subnets[0].ResourceId = $PublicVIPPrefix.Replace("/", "_")
        $logicalNetworkProperties.Subnets[0].Properties = new-object Microsoft.Windows.NetworkController.LogicalSubnetProperties
        $logicalNetworkProperties.Subnets[0].Properties.AddressPrefix = $PublicVIPPrefix
        $logicalNetworkProperties.Subnets[0].Properties.DefaultGateways = @(Get-IPv4AddressInSubnet -subnet $PublicVIPPrefix)
        $logicalnetworkproperties.subnets[0].properties.IsPublic = $true

        $PublicVIPLNObject = New-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "PublicVIP" -properties $LogicalNetworkProperties -Credential $Credential -Force
    }

    $IPpoolProperties = new-object Microsoft.Windows.NetworkController.IPPoolproperties
    $ippoolproperties.startipaddress = $PublicVIPPoolStart
    $ippoolproperties.endipaddress = $PublicVIPPoolEnd

    $PublicPoolObject = new-networkcontrollerIPPool -ConnectionURI $uri -NetworkId "PublicVIP" -SubnetId $PublicVIPPrefix.Replace("/", "_") -ResourceID $PublicVIPPrefix.Replace("/", "_") -Properties $IPPoolProperties -force
    
    #SLBManager Config

    $managerproperties = new-object Microsoft.Windows.NetworkController.LoadBalancerManagerProperties
    $managerproperties.LoadBalancerManagerIPAddress = $SLBMVip
    $managerproperties.OutboundNatIPExemptions = @("$SLBMVIP/32")
    $managerproperties.VipIPPools = @($PrivatePoolObject, $PublicPoolObject)

    $SLBMObject = new-networkcontrollerloadbalancerconfiguration -connectionuri $uri -properties $managerproperties -resourceid "config" -Force
    write-sdnexpresslog "New-SDNExpressLoadBalancerManagerConfiguration Exit"
}




function New-SDNExpressiDNSConfiguration
{
    param(
        [String] $RestName,
        [String] $Username,
        [String] $Password,
        [String] $IPAddress,
        [String] $ZoneName,
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressiDNSConfiguration"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -UserName: $UserName"
    write-sdnexpresslog "  -Password: ********"
    write-sdnexpresslog "  -IPAddress: $IPAddress"
    write-sdnexpresslog "  -ZoneName: $ZoneName"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"    

    $CredentialProperties = new-object Microsoft.Windows.NetworkController.CredentialProperties
    $CredentialProperties.Type = "UsernamePassword"
    $CredentialProperties.UserName = $Username
    $CredentialProperties.Value = $Password
    $iDNSUserObject = New-NetworkControllerCredential -ConnectionURI $uri -ResourceId "iDNSUser" -properties $CredentialProperties -Credential $Credential -force    
    
    $iDNSProperties = new-object microsoft.windows.networkcontroller.InternalDNSServerProperties
    $iDNSProperties.Connections += new-object Microsoft.Windows.NetworkController.Connection
    $iDNSProperties.Connections[0].Credential = $iDNSUserObject
    $iDNSProperties.Connections[0].CredentialType = $iDNSUserObject.properties.Type
    $iDNSProperties.Connections[0].ManagementAddresses = $IPAddress

    $iDNSProperties.Zone = $ZoneName

    New-NetworkControllerIDnsServerConfiguration -connectionuri $RestName -ResourceId "configuration" -properties $iDNSProperties -force -credential $Credential    
}





function Enable-SDNExpressVMPort {
    param(
        [String] $ComputerName,
        [String] $VMName,
        [String] $VMNetworkAdapterName
    )

    invoke-command -ComputerName $ComputerName -ScriptBlock {
        param(
            [String] $VMName,
            [String] $VMNetworkAdapterName
        )
        $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
        $NcVendorId  = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"

        $vnic = Get-VMNetworkAdapter -VMName $VMName -Name $VMNetworkAdapterName

        $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMNetworkAdapter $vNic

        if ( $currentProfile -eq $null)
        {
            $portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId
        
            $portProfileDefaultSetting.SettingData.ProfileId = "{$([Guid]::Empty)}"
            $portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{56785678-a0e5-4a26-bc9b-c0cba27311a3}"
            $portProfileDefaultSetting.SettingData.CdnLabelString = "TestCdn"
            $portProfileDefaultSetting.SettingData.CdnLabelId = 1111
            $portProfileDefaultSetting.SettingData.ProfileName = "Testprofile"
            $portProfileDefaultSetting.SettingData.VendorId = $NcVendorId 
            $portProfileDefaultSetting.SettingData.VendorName = "NetworkController"
            $portProfileDefaultSetting.SettingData.ProfileData = 1
            
            Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $vNic | out-null
        }        
        else
        {
            $currentProfile.SettingData.ProfileId = "{$([Guid]::Empty)}"
            $currentProfile.SettingData.ProfileData = 1
            Set-VMSwitchExtensionPortFeature  -VMSwitchExtensionFeature $currentProfile  -VMNetworkAdapter $vNic | out-null
        }
    }    -ArgumentList $VMName, $VMNetworkAdapterName
}







<#

ooooo   ooooo                        .   
`888'   `888'                      .o8   
 888     888   .ooooo.   .oooo.o .o888oo 
 888ooooo888  d88' `88b d88(  "8   888   
 888     888  888   888 `"Y88b.    888   
 888     888  888   888 o.  )88b   888 . 
o888o   o888o `Y8bod8P' 8""888P'   "888" 

#>

Function Add-SDNExpressHost {
    param(
        [String] $RestName,
        [string] $ComputerName,
        [String] $HostPASubnetPrefix,
        [String] $VirtualSwitchName = "",
        [Object] $NCHostCert,
        [String] $iDNSIPAddress = "",
        [String] $iDNSMacAddress = "",
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressHost"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -ComputerName: $ComputerName"
    write-sdnexpresslog "  -HostPASubnetPrefix: $HostPASubnetPrefix"
    write-sdnexpresslog "  -VirtualSwitchName: $VirtualSwitchName"
    write-sdnexpresslog "  -NCHostCert: $($NCHostCert.Thumbprint)"
    write-sdnexpresslog "  -iDNSIPAddress: $iDNSIPAddress"
    write-sdnexpresslog "  -iDNSMacAddress: $iDNSMacAddress"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"
    
    $uri = "https://$RestName"    

    write-sdnexpresslog "Get the SLBM VIP"

    $SLBMConfig = get-networkcontrollerloadbalancerconfiguration -connectionuri $uri -credential $Credential

    $slbmvip = $slbmconfig.properties.loadbalancermanageripaddress

    write-sdnexpresslog "SLBM VIP is $slbmvip"

    if ([String]::IsNullOrEmpty($VirtualSwitchName)) {
        $VirtualSwitchName = invoke-command -ComputerName $ComputerName {
            $vmswitch = get-vmswitch
            if (($vmswitch -eq $null) -or ($vmswitch.count -eq 0)) {
                throw "No virtual switch found on this host.  Please create the virtual switch before adding this host."
            }
            if ($vmswitch.count -gt 1) {
                throw "More than one virtual switch exists on the specified host.  Use the VirtualSwitchName parameter to specify which switch you want configured for use with SDN."
            }

            return $vmswitch.Name
        }
    }

    add-windowsfeature -computername $ComputerName NetworkVirtualization -IncludeAllSubFeature -IncludeManagementTools -Restart -ErrorAction Ignore | out-null
    
    $NodeFQDN = invoke-command -ComputerName $ComputerName {
        param(
            [String] $RestName,
            [String] $iDNSIPAddress,
            [String] $iDNSMacAddress
        )
        $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

        $connections = "ssl:$($RestName):6640","pssl:6640"
        $peerCertCName = $RestName.ToUpper()
        $hostAgentCertCName = $NodeFQDN.ToUpper()

        Set-Item WSMan:\localhost\MaxEnvelopeSizekb -Value 7000 | out-null
        
        new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters" -Name "Connections" -Value $connections -PropertyType "MultiString" -Force | out-null
        new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters" -Name "PeerCertificateCName" -Value $peerCertCName -PropertyType "String" -Force | out-null
        new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters" -Name "HostAgentCertificateCName" -Value $hostAgentCertCName -PropertyType "String" -Force | out-null

        if (![String]::IsNullOrEmpty($iDNSIPAddress) -and ![String]::IsNullOrEmpty($iDNSMacAddress)) {
            new-item -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet" -name "InfraServices" -force | out-null
            new-item -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet\InfraServices" -name "DnsProxyService" -force | out-null
            new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet\InfraServices\DnsProxyService" -Name "Port" -Value 53 -PropertyType "Dword" -Force | out-null
            new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet\InfraServices\DnsProxyService" -Name "ProxyPort" -Value 53 -PropertyType "Dword" -Force | out-null
            new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet\InfraServices\DnsProxyService" -Name "IP" -Value "169.254.169.254" -PropertyType "String" -Force | out-null
            new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\Plugins\Vnet\InfraServices\DnsProxyService" -Name "MAC" -Value $iDNSMacAddress -PropertyType "String" -Force | out-null

            new-item -path "HKLM:\SYSTEM\CurrentControlSet\Services" -name "DnsProxy" -force | out-null
            new-item -path "HKLM:\SYSTEM\CurrentControlSet\Services\DnsProxy" -name "Parameters" -force | out-null
            new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\DNSProxy\Parameters" -Name "Forwarders" -Value $iDNSIPAddress -PropertyType "String" -Force | out-null
        
            Enable-NetFirewallRule -DisplayGroup 'DNS Proxy Service' -ErrorAction Ignore | out-null
        }

        
        $fwrule = Get-NetFirewallRule -Name "Firewall-REST" -ErrorAction SilentlyContinue
        if ($fwrule -eq $null) {
            New-NetFirewallRule -Name "Firewall-REST" -DisplayName "Network Controller Host Agent REST" -Group "NcHostAgent" -Action Allow -Protocol TCP -LocalPort 80 -Direction Inbound -Enabled True | Out-Null
        }

        $fwrule = Get-NetFirewallRule -Name "Firewall-OVSDB" -ErrorAction SilentlyContinue
        if ($fwrule -eq $null) {
            New-NetFirewallRule -Name "Firewall-OVSDB" -DisplayName "Network Controller Host Agent OVSDB" -Group "NcHostAgent" -Action Allow -Protocol TCP -LocalPort 6640 -Direction Inbound -Enabled True | Out-Null
        }

        $fwrule = Get-NetFirewallRule -Name "Firewall-HostAgent-TCP-IN" -ErrorAction SilentlyContinue
        if ($fwrule -eq $null) {
            New-NetFirewallRule -Name "Firewall-HostAgent-TCP-IN" -DisplayName "Network Controller Host Agent (TCP-In)" -Group "Network Controller Host Agent Firewall Group" -Action Allow -Protocol TCP -LocalPort Any -Direction Inbound -Enabled True | Out-Null
        }

        $fwrule = Get-NetFirewallRule -Name "Firewall-HostAgent-WCF-TCP-IN" -ErrorAction SilentlyContinue
        if ($fwrule -eq $null) {
            New-NetFirewallRule -Name "Firewall-HostAgent-WCF-TCP-IN" -DisplayName "Network Controller Host Agent WCF(TCP-In)" -Group "Network Controller Host Agent Firewall Group" -Action Allow -Protocol TCP -LocalPort 80 -Direction Inbound -Enabled True | Out-Null
        }

        $fwrule = Get-NetFirewallRule -Name "Firewall-HostAgent-TLS-TCP-IN" -ErrorAction SilentlyContinue
        if ($fwrule -eq $null) {
            New-NetFirewallRule -Name "Firewall-HostAgent-TLS-TCP-IN" -DisplayName "Network Controller Host Agent WCF over TLS (TCP-In)" -Group "Network Controller Host Agent Firewall Group" -Action Allow -Protocol TCP -LocalPort 443 -Direction Inbound -Enabled True | Out-Null
        }

        return $NodeFQDN
    } -ArgumentList $RestName, $iDNSIPAddress, $iDNSMacAddress

    write-sdnexpresslog "Create and return host certificate."

    $CertData = invoke-command -ComputerName $ComputerName {
        $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

        $cert = get-childitem "cert:\localmachine\my" | where {$_.Subject.ToUpper() -eq "CN=$NodeFQDN".ToUpper()}
        if ($Cert -eq $Null) {
            write-verbose "Creating new host certificate." 
            $Cert = New-SelfSignedCertificate -Type Custom -KeySpec KeyExchange -Subject "CN=$NodeFQDN" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\LocalMachine\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2")
        } else {
            write-verbose "Found existing host certficate." 
            $HasServerEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.1"}) -ne $null
            $HasClientEku = ($cert.EnhancedKeyUsageList | where {$_.ObjectId -eq "1.3.6.1.5.5.7.3.2"}) -ne $null
        
            if (!$HasServerEku) {
                throw "Host cert exists on $(hostname) but is missing the EnhancedKeyUsage for Server Authentication."
            }
            if (!$HasClientEku) {
                throw "Host cert exists but $(hostname) is missing the EnhancedKeyUsage for Client Authentication."
            }
            write-verbose "Existing certificate meets criteria.  Exporting." 
        }

        $targetCertPrivKey = $Cert.PrivateKey 
        $privKeyCertFile = Get-Item -path "$ENV:ProgramData\Microsoft\Crypto\RSA\MachineKeys\*"  | where {$_.Name -eq $targetCertPrivKey.CspKeyContainerInfo.UniqueKeyContainerName} 
        $privKeyAcl = Get-Acl $privKeyCertFile
        $permission = "NT AUTHORITY\NETWORK SERVICE","Read","Allow" 
        $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission 
        $privKeyAcl.AddAccessRule($accessRule) 
        Set-Acl $privKeyCertFile.FullName $privKeyAcl

        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force | out-null
        Export-Certificate -Type CERT -FilePath $TempFile.FullName -cert $cert | out-null

        $CertData = Get-Content $TempFile.FullName -Encoding Byte
        Remove-Item $TempFile.FullName -Force | out-null

        return $CertData
    }
    #Hold on to CertData, we will need it later when adding the host to the NC.

    write-sdnexpresslog "Install NC host cert into Root store on host."
    
    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force | out-null
    Export-Certificate -Type CERT -FilePath $TempFile.FullName -cert $NCHostCert | out-null
    $NCHostCertData = Get-Content $TempFile.FullName -Encoding Byte
    Remove-Item $TempFile.FullName -Force | out-null

    invoke-command -ComputerName $ComputerName {
        param(
            [byte[]] $CertData
        )
        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force

        $CertData | set-content $TempFile.FullName -Encoding Byte
        import-certificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\root" | out-null
        Remove-Item $TempFile.FullName -Force
    } -ArgumentList (,$NCHostCertData)

    write-sdnexpresslog "Restart NC Host Agent and enable VFP."
    
    $VirtualSwitchId = invoke-command -ComputerName $ComputerName {
        param(
            [String] $VirtualSwitchName
        )
        Stop-Service -Name NCHostAgent -Force | out-null
        Set-Service -Name NCHostAgent  -StartupType Automatic | out-null
        Start-Service -Name NCHostAgent  | out-null

        Disable-VmSwitchExtension -VMSwitchName $VirtualSwitchName -Name "Microsoft Windows Filtering Platform" | out-null
        Enable-VmSwitchExtension -VMSwitchName $VirtualSwitchName -Name "Microsoft Azure VFP Switch Extension" | out-null

        return (get-vmswitch -Name $VirtualSwitchName).Id
    } -ArgumentList $VirtualSwitchName

    write-sdnexpresslog "Configure and start SLB Host Agent."

    invoke-command -computername $ComputerNAme {
        param(
            [String] $SLBMVip,
            [String] $RestName
        )
        $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

        $slbhpconfigtemplate = @"
<?xml version=`"1.0`" encoding=`"utf-8`"?>
<SlbHostPluginConfiguration xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">
    <SlbManager>
        <HomeSlbmVipEndpoints>
            <HomeSlbmVipEndpoint>$($SLBMVIP):8570</HomeSlbmVipEndpoint>
        </HomeSlbmVipEndpoints>
        <SlbmVipEndpoints>
            <SlbmVipEndpoint>$($SLBMVIP):8570</SlbmVipEndpoint>
        </SlbmVipEndpoints>
        <SlbManagerCertSubjectName>$RESTName</SlbManagerCertSubjectName>
    </SlbManager>
    <SlbHostPlugin>
        <SlbHostPluginCertSubjectName>$NodeFQDN</SlbHostPluginCertSubjectName>
    </SlbHostPlugin>
    <NetworkConfig>
        <MtuSize>0</MtuSize>
        <JumboFrameSize>4088</JumboFrameSize>
        <VfpFlowStatesLimit>500000</VfpFlowStatesLimit>
    </NetworkConfig>
</SlbHostPluginConfiguration>
"@
    
        set-content -value $slbhpconfigtemplate -path 'c:\windows\system32\slbhpconfig.xml' -encoding UTF8

        Stop-Service -Name SLBHostAgent -Force
        Set-Service -Name SLBHostAgent  -StartupType Automatic
        Start-Service -Name SLBHostAgent 
    } -ArgumentList $SLBMVIP, $RESTName  

    $nchostcertObject = get-networkcontrollerCredential -Connectionuri $URI -ResourceId "NCHostCert" -credential $Credential

    $PALogicalNetwork = get-networkcontrollerLogicalNetwork -Connectionuri $URI -ResourceId "HNVPA" -credential $Credential
    $PALogicalSubnet = $PALogicalNetwork.Properties.Subnets | where {$_.properties.AddressPrefix -eq $HostPASubnetPrefix}

    $ServerProperties = new-object Microsoft.Windows.NetworkController.ServerProperties

    $ServerProperties.Connections = @()
    $ServerProperties.Connections += new-object Microsoft.Windows.NetworkController.Connection
    $ServerProperties.Connections[0].Credential = $nchostcertObject
    $ServerProperties.Connections[0].CredentialType = $nchostcertObject.properties.Type
    $ServerProperties.Connections[0].ManagementAddresses = @($NodeFQDN)

    $ServerProperties.NetworkInterfaces = @()
    $serverProperties.NetworkInterfaces += new-object Microsoft.Windows.NetworkController.NwInterface
    $serverProperties.NetworkInterfaces[0].ResourceId = $VirtualSwitchName
    $serverProperties.NetworkInterfaces[0].Properties = new-object Microsoft.Windows.NetworkController.NwInterfaceProperties
    $ServerProperties.NetworkInterfaces[0].Properties.LogicalSubnets = @($PALogicalSubnet)

    $ServerProperties.Certificate = [System.Convert]::ToBase64String($CertData)

    $Server = New-NetworkControllerServer -ConnectionURI $uri -ResourceId $VirtualSwitchId -Properties $ServerProperties -Credential $Credential -Force

    invoke-command -computername $ComputerName {
        param(
            [String] $InstanceId
        )
        new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters" -Name "HostId" -Value $InstanceId -PropertyType "String" -Force | out-null

        $dnsproxy = get-service DNSProxy -ErrorAction Ignore
        if ($dnsproxy -ne $null) {
            $dnsproxy | Stop-Service -Force
        }

        Stop-Service SlbHostAgent -Force                
        Stop-Service NcHostAgent -Force

        Start-Service NcHostAgent
        Start-Service SlbHostAgent

        if ($dnsproxy -ne $null) {
            Set-Service -Name "DnsProxy" -StartupType Automatic
            $dnsproxy | Start-Service
        }

    } -ArgumentList $Server.InstanceId

    write-sdnexpresslog "New-SDNExpressHost Exit"
}




<#
ooooo     ooo     .    o8o  oooo   o8o      .               
`888'     `8'   .o8    `"'  `888   `"'    .o8               
 888       8  .o888oo oooo   888  oooo  .o888oo oooo    ooo 
 888       8    888   `888   888  `888    888    `88.  .8'  
 888       8    888    888   888   888    888     `88..8'   
 `88.    .8'    888 .  888   888   888    888 .    `888'    
   `YbodP'      "888" o888o o888o o888o   "888"     .8'     
                                                .o..P'      
                                                `Y8P'       
#>
function Write-SDNExpressLog
{
    Param([String] $Message)

    $FormattedDate = date -Format "yyyyMMdd-HH:mm:ss"
    $FormattedMessage = "[$FormattedDate] $Message"
    write-verbose $FormattedMessage

    $formattedMessage | out-file ".\SDNExpressLog.txt" -Append
}
function Get-IPv4AddressInSubnet
{
    param([string] $subnet, [int] $offset)

    $prefix = ($subnet.split("/"))[0]
    $bits = ($subnet.split("/"))[1]

    $sp = $prefix.Split(".", 4)
    $val = [System.Convert]::ToInt64($sp[0])
    $val = $val -shl 8
    $val += [System.Convert]::ToInt64($sp[1])
    $val = $val -shl 8
    $val += [System.Convert]::ToInt64($sp[2])
    $val = $val -shl 8
    $val += [System.Convert]::ToInt64($sp[3])

    $val = $val -shr (32 - $bits)
    $val = $val -shl (32 - $bits)
    $val += $offset

    "{0}.{1}.{2}.{3}" -f (($val -shr 24) -band 0xff), (($val -shr 16) -band 0xff), (($val -shr 8) -band 0xff), ($val -band 0xff )
}
function Get-IPv4LastAddressInSubnet
{
    param([string] $subnet, [Int32]$offset = 0)

    $bits = ($subnet.split("/"))[1]
    $Count = [math]::pow(2, 32-$bits)
    return get-ipv4addressinsubnet $subnet (($count-1)+$offset)
}


function WaitForComputerToBeReady
{
    param(
        [string[]] $ComputerName,
        [Switch]$CheckPendingReboot
    )


    foreach ($computer in $computername) {        
        write-sdnexpresslog "Waiting for $Computer to become active."
        Start-Sleep -Seconds 120
        
        $continue = $true
        while ($continue) {
            try {
                $ps = $null
                $result = ""
                
                klist purge | out-null  #clear kerberos ticket cache 
                Clear-DnsClientCache    #clear DNS cache in case IP address is stale
                
                write-sdnexpresslog "Attempting to contact $Computer."
                $ps = new-pssession -computername $Computer -erroraction ignore
                if ($ps -ne $null) {
                    if ($CheckPendingReboot) {                        
                        $result = Invoke-Command -Session $ps -ScriptBlock { 
                            if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
                                "Reboot pending"
                            } 
                            else {
                                hostname 
                            }
                        }
                    }
                    else {
                        try {
                            $result = Invoke-Command -Session $ps -ScriptBlock { hostname }
                        } catch { }
                    }
                    remove-pssession $ps
                }
                if ($result -eq $Computer) {
                    $continue = $false
                    break
                }
                if ($result -eq "Reboot pending") {
                    write-sdnexpresslog "Reboot pending on $Computer.  Waiting for restart."
                }
            }
            catch 
            {
            }
            write-sdnexpresslog "$Computer is not active, sleeping for 10 seconds."
            sleep 10
        }
    write-sdnexpresslog "$Computer IS ACTIVE.  Continuing with deployment."
    }
}




<#

ooo        ooooo                         
`88.       .888'                         
 888b     d'888  oooo  oooo  oooo    ooo 
 8 Y88. .P  888  `888  `888   `88b..8P'  
 8  `888'   888   888   888     Y888'    
 8    Y     888   888   888   .o8"'88b   
o8o        o888o  `V88V"V8P' o88'   888o 
                                         
                                         
                                         
#>
Function Add-SDNExpressMux {
    param(
        [String] $RestName,
        [string] $ComputerName,
        [Object] $NCHostCert,
        [String] $PAMacAddress,
        [String] $LocalPeerIP,
        [String] $MuxASN,
        [Object] $Routers,
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressMux"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -ComputerName: $ComputerName"
    write-sdnexpresslog "  -NCHostCert: $($NCHostCert.Thumbprint)"
    write-sdnexpresslog "  -PAMacAddress: $PAMacAddress"
    write-sdnexpresslog "  -LocalPeerIP: $LocalPeerIP"
    write-sdnexpresslog "  -MuxASN: $MuxASN"
    write-sdnexpresslog "  -Routers: $Routers"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"    

    #TODO: Add PA Routes

    invoke-command -computername $ComputerName {
        param(
            [String] $PAMacAddress
        )
        reg add hklm\system\currentcontrolset\services\tcpip6\parameters /v DisabledComponents /t REG_DWORD /d 255 /f | out-null
        
        $PAMacAddress = [regex]::matches($PAMacAddress.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
        $nic = Get-NetAdapter -ErrorAction Ignore | where {$_.MacAddress -eq $PAMacAddress}

        if ($nic -eq $null)
        {
            throw "No adapter with the HNVPA MAC $PAMacAddress was found"
        }

        $nicProperty = Get-NetAdapterAdvancedProperty -Name $nic.Name -AllProperties -RegistryKeyword *EncapOverhead -ErrorAction Ignore
        if($nicProperty -eq $null) 
        {
            New-NetAdapterAdvancedProperty -Name $nic.Name -RegistryKeyword *EncapOverhead -RegistryValue 160 | out-null
        }
        else
        {
            Set-NetAdapterAdvancedProperty -Name $nic.Name -AllProperties -RegistryKeyword *EncapOverhead -RegistryValue 160
        }

        add-windowsfeature SoftwareLoadBalancer -Restart | out-null
    } -argumentlist $PAMacAddress
    
    WaitforComputerToBeReady $ComputerName $true

    $MuxFQDN = invoke-command -computername $ComputerName {
            Return (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
    }

    #wait for comptuer to restart.

    $CertData = invoke-command -computername $ComputerName {
        write-verbose "Creating self signed certificate...";

        $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

        $cert = get-childitem "cert:\localmachine\my" | where {$_.Subject.ToUpper() -eq "CN=$NodeFQDN".ToUpper()}
        if ($cert -eq $null) {
            $cert = New-SelfSignedCertificate -Type Custom -KeySpec KeyExchange -Subject "CN=$NodeFQDN" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\LocalMachine\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2")
        }

        $targetCertPrivKey = $Cert.PrivateKey 
        $privKeyCertFile = Get-Item -path "$ENV:ProgramData\Microsoft\Crypto\RSA\MachineKeys\*"  | where {$_.Name -eq $targetCertPrivKey.CspKeyContainerInfo.UniqueKeyContainerName} 
        $privKeyAcl = Get-Acl $privKeyCertFile
        $permission = "NT AUTHORITY\NETWORK SERVICE","Read","Allow" 
        $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission 
        $privKeyAcl.AddAccessRule($accessRule) 
        Set-Acl $privKeyCertFile.FullName $privKeyAcl

        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force | out-null
        Export-Certificate -Type CERT -FilePath $TempFile.FullName -cert $cert | out-null

        $CertData = Get-Content $TempFile.FullName -Encoding Byte
        Remove-Item $TempFile.FullName -Force | out-null

        return $CertData
    }

    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force | out-null
    Export-Certificate -Type CERT -FilePath $TempFile.FullName -cert $NCHostCert | out-null
    $NCHostCertData = Get-Content $TempFile.FullName -Encoding Byte
    Remove-Item $TempFile.FullName -Force | out-null

    invoke-command -ComputerName $ComputerName {
        param(
            [byte[]] $CertData
        )
        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force

        $CertData | set-content $TempFile.FullName -Encoding Byte
        import-certificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\root" | out-null
        Remove-Item $TempFile.FullName -Force
    } -ArgumentList (,$NCHostCertData)
    

    $vmguid = invoke-command -computername $ComputerName {
        param(
            [String] $RestName
        )

        $NodeFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
        $cert = get-childitem "cert:\localmachine\my" | where {$_.Subject.ToUpper() -eq "CN=$NodeFQDN".ToUpper()}
        
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SlbMux" -Force -Name SlbmThumb -PropertyType String -Value $RestName | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SlbMux" -Force -Name MuxCert -PropertyType String -Value $NodeFQDN | out-null

        Get-ChildItem -Path WSMan:\localhost\Listener | Where {$_.Keys.Contains("Transport=HTTPS") } | Remove-Item -Recurse -Force | out-null
        New-Item -Path WSMan:\localhost\Listener -Address * -HostName $NodeFQDN -Transport HTTPS -CertificateThumbPrint $cert.Thumbprint -Force | out-null

        Get-Netfirewallrule -Group "@%SystemRoot%\system32\firewallapi.dll,-36902" | Enable-NetFirewallRule

        start-service slbmux

        return (get-childitem -Path "HKLM:\software\microsoft\virtual machine\guest" | get-itemproperty).virtualmachineid
    } -ArgumentList $RestName

    write-sdnexpresslog "Add VirtualServerToNC";
    $nchostcertObject = get-networkcontrollerCredential -Connectionuri $URI -ResourceId "NCHostCert" -credential $Credential
    
    $VirtualServerProperties = new-object Microsoft.Windows.NetworkController.VirtualServerProperties
    $VirtualServerProperties.Connections = @()
    $VirtualServerProperties.Connections += new-object Microsoft.Windows.NetworkController.Connection
    $VirtualServerProperties.Connections[0].Credential = $nchostcertObject
    $VirtualServerProperties.Connections[0].CredentialType = $nchostcertObject.properties.Type
    $VirtualServerProperties.Connections[0].ManagementAddresses = @($MuxFQDN)
    $VirtualServerProperties.Certificate = [System.Convert]::ToBase64String($CertData)
    $VirtualServerProperties.vmguid = $vmGuid

    $VirtualServer = new-networkcontrollervirtualserver -connectionuri $uri -credential $Credential -MarkServerReadOnly $false -ResourceId $MuxFQDN -Properties $VirtualServerProperties -force
    
    $MuxProperties = new-object Microsoft.Windows.NetworkController.LoadBalancerMuxProperties
    $muxProperties.RouterConfiguration = new-object Microsoft.Windows.NetworkController.RouterConfiguration
    $muxProperties.RouterConfiguration.LocalASN = $MuxASN
    $muxProperties.RouterConfiguration.PeerRouterConfigurations = @()
    foreach ($router in $routers) {
        $peerRouter = new-object Microsoft.Windows.NetworkController.PeerRouterConfiguration
        $peerRouter.LocalIPAddress = $LocalPeerIP
        $peerRouter.PeerASN = $Router.RouterASN
        $peerRouter.RouterIPAddress = $Router.RouterIPAddress
        $peerRouter.RouterName = $Router.RouterIPAddress.Replace(".", "_")
        $muxProperties.RouterConfiguration.PeerRouterConfigurations += $PeerRouter
    }
    $muxProperties.VirtualServer = $VirtualServer
    
    $Mux = new-networkcontrollerloadbalancermux -connectionuri $uri -credential $Credential -ResourceId $MuxFQDN -Properties $MuxProperties -force
    write-sdnexpresslog "New-SDNExpressMux Exit"
}

<#

  .oooooo.                  .                                                             
 d8P'  `Y8b               .o8                                                             
888            .oooo.   .o888oo  .ooooo.  oooo oooo    ooo  .oooo.   oooo    ooo  .oooo.o 
888           `P  )88b    888   d88' `88b  `88. `88.  .8'  `P  )88b   `88.  .8'  d88(  "8 
888     ooooo  .oP"888    888   888ooo888   `88..]88..8'    .oP"888    `88..8'   `"Y88b.  
`88.    .88'  d8(  888    888 . 888    .o    `888'`888'    d8(  888     `888'    o.  )88b 
 `Y8bood8P'   `Y888""8o   "888" `Y8bod8P'     `8'  `8'     `Y888""8o     .8'     8""888P' 
                                                                     .o..P'               
                                                                     `Y8P'                
                                                                                          
#>
function New-SDNExpressGatewayPool
{
    param(
        [String] $RestName,
        [PSCredential] $Credential,
        [String] $PoolName,
        [Parameter(Mandatory=$true,ParameterSetName="TypeAll")]
        [Switch] $IsTypeAll,
        [Parameter(Mandatory=$true,ParameterSetName="TypeIPSec")]
        [Switch] $IsTypeIPSec,
        [Parameter(Mandatory=$true,ParameterSetName="TypeGre")]
        [Switch] $IsTypeGre,
        [Parameter(Mandatory=$true,ParameterSetName="TypeForwarding")]
        [Switch] $IsTypeForwarding,
        [Parameter(Mandatory=$false,ParameterSetName="TypeAll")]
        [Parameter(Mandatory=$false,ParameterSetName="TypeGre")]
        [String] $PublicIPAddress,  
        [Parameter(Mandatory=$false,ParameterSetName="TypeAll")]
        [Parameter(Mandatory=$true,ParameterSetName="TypeGre")]
        [String] $GreSubnetAddressPrefix,
        [Parameter(Mandatory=$false,ParameterSetName="TypeGre")]
        [String] $GrePoolStart = (Get-IPv4AddressInSubnet -subnet $GreSubnetAddressPrefix -offset 1),
        [Parameter(Mandatory=$false,ParameterSetName="TypeGre")]
        [String] $GrePoolEnd = (Get-IPv4LastAddressInSubnet -subnet $GreSubnetAddressPrefix),
        [String] $Capacity,
        [String] $RedundantCount=1
        )

    write-sdnexpresslog "New-SDNExpressGatewayPool"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"
    write-sdnexpresslog "  -PoolName: $PoolName"
    write-sdnexpresslog "  -IsTypeAll: $IsTypeAll"
    write-sdnexpresslog "  -IsTypeIPSec: $IsTypeIPSec"
    write-sdnexpresslog "  -IsTypeGre: $IsTypeGre"
    write-sdnexpresslog "  -IsTypeForwarding: $IsTypeForwarding"
    write-sdnexpresslog "  -PublicIPAddress: $PublicIPAddress"
    write-sdnexpresslog "  -GRESubnetAddressPrefix: $GRESubnetAddressPrefix"
    write-sdnexpresslog "  -GrePoolStart: $GrePoolStart"
    write-sdnexpresslog "  -GrePoolEnd: $GrePoolEnd"
    write-sdnexpresslog "  -Capacity: $Capacity"
    write-sdnexpresslog "  -RedundantCount: $RedundantCount"
    
    $uri = "https://$RestName"

    $gresubnet = $null
    
    if ($IsTypeAll -or $IsTypeIPSec) {
        $PublicIPProperties = new-object Microsoft.Windows.NetworkController.PublicIPAddressProperties
        $publicIPProperties.IdleTimeoutInMinutes = 4

        if ([String]::IsNullOrEmpty($PublicIPAddress)) {
            $PublicIPProperties.PublicIPAllocationMethod = "Dynamic"
        } else {
            $PublicIPProperties.PublicIPAllocationMethod = "Static"
            $PublicIPProperites.IPAddress = $PublicIPAddress
        }
        $PublicIPAddressObject = New-NetworkControllerPublicIPAddress -connectionURI $uri -ResourceId $PoolName -Properties $PublicIPProperties -Force -Credential $Credential
    }

    if ($IsTypeGre -or $IsTypeAll) {
        $logicalNetwork = try { get-networkcontrollerlogicalnetwork -ResourceId "GreVIP" -connectionuri $uri -credential $Credential } catch {}
    
        if ($logicalNetwork -eq $null) {
            $LogicalNetworkProperties = new-object Microsoft.Windows.NetworkController.LogicalNetworkProperties
            $LogicalNetworkProperties.NetworkVirtualizationEnabled = $false
            $LogicalNetwork = New-NetworkControllerLogicalNetwork -ConnectionURI $uri -ResourceID "GreVIP" -properties $LogicalNetworkProperties -Credential $Credential -Force
        }

        foreach ($subnet in $logicalnetwork.properties.subnets) {
            if ($Subnet.properties.AddressPrefix -eq $GreSubnetAddressPrefix) {
                $GreSubnet = $subnet
            }
        }

        if ($GreSubnet -eq $Null) {
            $LogicalSubnetProperties = new-object Microsoft.Windows.NetworkController.LogicalSubnetProperties
            $LogicalSubnetProperties.AddressPrefix = $GreSubnetAddressPrefix
            $logicalSubnetProperties.DefaultGateways = @(Get-IPv4AddressInSubnet -subnet $GreSubnetAddressPrefix)
        
            $greSubnet = New-NetworkControllerLogicalSubnet -ConnectionURI $uri -LogicalNetworkId "GreVIP" -ResourceId $GreSubnetAddressPrefix.Replace("/", "_") -properties $LogicalSubnetProperties -Credential $Credential -Force
        
            $IPpoolProperties = new-object Microsoft.Windows.NetworkController.IPPoolproperties
            $ippoolproperties.startipaddress = $GrePoolStart
            $ippoolproperties.endipaddress = $GrePoolEnd
        
            $IPPoolObject = New-networkcontrollerIPPool -ConnectionURI $uri -NetworkId "GreVIP" -SubnetId $GreSubnetAddressPrefix.Replace("/", "_") -ResourceID $GreSubnetAddressPrefix.Replace("/", "_") -Properties $IPPoolProperties -Credential $Credential -force
        }
    }

    $GatewayPoolProperties = new-object Microsoft.Windows.NetworkController.GatewayPoolProperties
    $GatewayPoolProperties.RedundantGatewayCount = $RedundantCount
    $GatewayPoolProperties.GatewayCapacityKiloBitsPerSecond = $Capacity

    if ($IsTypeAll) {
        $GatewayPoolProperties.Type = "All"

        $GatewayPoolProperties.IPConfiguration = new-object Microsoft.Windows.NetworkController.IPConfig
        $GatewayPoolProperties.IPConfiguration.PublicIPAddresses = @()
        $GatewayPoolProperties.IPConfiguration.PublicIPAddresses += $PublicIPAddressObject

        $GatewayPoolProperties.IpConfiguration.GreVipSubnets = @()
        $GatewayPoolProperties.IPConfiguration.GreVipSubnets += $GreSubnet
    } elseif ($IsTypeIPSec) {
        $GatewayPoolProperties.Type = "S2sIpSec"

        $GatewayPoolProperties.IPConfiguration = new-object Microsoft.Windows.NetworkController.IPConfig
        $GatewayPoolProperties.IPConfiguration.PublicIPAddresses = @()
        $GatewayPoolProperties.IPConfiguration.PublicIPAddresses += $PublicIPAddressObject
    } elseif ($IsTypeGre) {
        $GatewayPoolProperties.Type = "S2sGre"

        $GatewayPoolProperties.IPConfiguration = new-object Microsoft.Windows.NetworkController.IPConfig
        $GatewayPoolProperties.IpConfiguration.GreVipSubnets = @()
        $GatewayPoolProperties.IPConfiguration.GreVipSubnets += $GreSubnet
    } elseif ($IsForwarding) {
        $GatewayPoolProperties.Type = "Forwarding"
    }

    $GWPoolObject = new-networkcontrollergatewaypool -connectionURI $URI -ResourceId $PoolName -Properties $GatewayPoolProperties -Force -Credential $Credential
    write-sdnexpresslog "New-SDNExpressGatewayPool Exit"
}





Function New-SDNExpressGateway {
    param(
        [String] $RestName,
        [string] $ComputerName,
        [String] $HostName,
        [Object] $NCHostCert,
        [String] $PoolName,
        [String] $FrontEndLogicalNetworkName,
        [String] $FrontEndAddressPrefix,
        [String] $FrontEndIp,
        [String] $FrontEndMac,
        [String] $BackEndMac,
        [String] $RouterASN = $null,
        [String] $RouterIP = $null,
        [String] $LocalASN = $null,
        [PSCredential] $Credential = $null
    )

    write-sdnexpresslog "New-SDNExpressGateway"
    write-sdnexpresslog "  -RestName: $RestName"
    write-sdnexpresslog "  -ComputerName: $ComputerName"
    write-sdnexpresslog "  -HostName: $HostName"
    write-sdnexpresslog "  -NCHostCert: $($NCHostCert.thumbprint)"
    write-sdnexpresslog "  -PoolName: $PoolName"
    write-sdnexpresslog "  -FrontEndLogicalNetworkName: $FrontEndLogicalNetworkName"
    write-sdnexpresslog "  -FrontEndAddressPrefix: $FrontEndAddressPrefix"
    write-sdnexpresslog "  -FrontEndIp: $FrontEndIp"
    write-sdnexpresslog "  -FrontEndMac: $FrontEndMac"
    write-sdnexpresslog "  -BackEndMac: $BackEndMac"
    write-sdnexpresslog "  -RouterASN: $RouterASN"
    write-sdnexpresslog "  -RouterIP: $RouterIP"
    write-sdnexpresslog "  -LocalASN: $LocalASN"
    write-sdnexpresslog "  -Credential: $($Credential.UserName)"

    $uri = "https://$RestName"    

    
    invoke-command -computername $ComputerName {
        param(
            [String] $FrontEndMac,
            [String] $BackEndMac            
        )

        # Get-NetAdapter returns MacAddresses with hyphens '-'
        $FrontEndMac = [regex]::matches($FrontEndMac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
        $BackEndMac = [regex]::matches($BackEndMac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
    
        Set-Item WSMan:\localhost\MaxEnvelopeSizekb -Value 7000

        $adapters = Get-NetAdapter

        $adapter = $adapters | where {$_.MacAddress -eq $BackEndMac}
        $adapter | Rename-NetAdapter -NewName "Internal" -Confirm:$false -ErrorAction Ignore

        $adapter = $adapters | where {$_.MacAddress -eq $FrontEndMac}
        $adapter | Rename-NetAdapter -NewName "External" -Confirm:$false -ErrorAction Ignore

        Add-WindowsFeature -Name RemoteAccess -IncludeAllSubFeature -IncludeManagementTools | out-null

        $RemoteAccess = get-RemoteAccess
        if ($RemoteAccess -eq $null -or $RemoteAccess.VpnMultiTenancyStatus -ne "Installed")
        {
            Install-RemoteAccess -MultiTenancy | out-null
        }

        Get-Netfirewallrule -Group "@%SystemRoot%\system32\firewallapi.dll,-36902" | Enable-NetFirewallRule

        $GatewayService = get-service GatewayService -erroraction Ignore
        if ($gatewayservice -ne $null) {
            Set-Service -Name GatewayService -StartupType Automatic | out-null
            Start-Service -Name GatewayService  | out-null
        }

    } -ArgumentList $FrontEndMac, $BackEndMac

    $GatewayFQDN = invoke-command -computername $ComputerName {
        Return (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
    }

    $vmGuid = invoke-command -computername $ComputerName {
        return (get-childitem -Path "HKLM:\software\microsoft\virtual machine\guest" | get-itemproperty).virtualmachineid
    }

    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force | out-null
    Export-Certificate -Type CERT -FilePath $TempFile.FullName -cert $NCHostCert | out-null
    $NCHostCertData = Get-Content $TempFile.FullName -Encoding Byte
    Remove-Item $TempFile.FullName -Force | out-null

    invoke-command -ComputerName $ComputerName {
        param(
            [byte[]] $CertData
        )
        $TempFile = New-TemporaryFile
        Remove-Item $TempFile.FullName -Force

        $CertData | set-content $TempFile.FullName -Encoding Byte
        import-certificate -filepath $TempFile.FullName -certstorelocation "cert:\localmachine\root" | out-null
        Remove-Item $TempFile.FullName -Force
    } -ArgumentList (,$NCHostCertData)
    
    # Get-VMNetworkAdapter returns MacAddresses without hyphens '-'.  NetworkInterface prefers without hyphens also.

    $FrontEndMac = [regex]::matches($FrontEndMac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join ""
    $BackEndMac = [regex]::matches($BackEndMac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join ""
    
    $LogicalSubnet = get-networkcontrollerlogicalSubnet -LogicalNetworkId $FrontEndLogicalNetworkName -ConnectionURI $uri -Credential $Credential
    $LogicalSubnet = $LogicalSubnet | where {$_.properties.AddressPrefix -eq $FrontEndAddressPrefix }

    $NicProperties = new-object Microsoft.Windows.NetworkController.NetworkInterfaceProperties
    $nicproperties.PrivateMacAddress = $BackEndMac
    $NicProperties.privateMacAllocationMethod = "Static"
    $BackEndNic = new-networkcontrollernetworkinterface -connectionuri $uri -credential $Credential -ResourceId "$($GatewayFQDN)_BackEnd" -Properties $NicProperties -force

    $NicProperties = new-object Microsoft.Windows.NetworkController.NetworkInterfaceProperties
    $nicproperties.PrivateMacAddress = $FrontEndMac
    $NicProperties.privateMacAllocationMethod = "Static"
    $NicProperties.IPConfigurations = @()
    $NicProperties.IPConfigurations += new-object Microsoft.Windows.NetworkController.NetworkInterfaceIpConfiguration
    $NicProperties.IPConfigurations[0].ResourceId = "FrontEnd" 
    $NicProperties.IPConfigurations[0].Properties = new-object Microsoft.Windows.NetworkController.NetworkInterfaceIpConfigurationProperties
    $NicProperties.IPConfigurations[0].Properties.Subnet = new-object Microsoft.Windows.NetworkController.Subnet
    $nicProperties.IpConfigurations[0].Properties.Subnet.ResourceRef = $LogicalSubnet.ResourceRef
    $NicProperties.IPConfigurations[0].Properties.PrivateIPAddress = $FrontEndIp
    $NicProperties.IPConfigurations[0].Properties.PrivateIPAllocationMethod = "Static"
    $FrontEndNic = new-networkcontrollernetworkinterface -connectionuri $uri -credential $Credential -ResourceId "$($GatewayFQDN)_FrontEnd" -Properties $NicProperties -force

    $SetPortProfileBlock = {
        param(
            [String] $VMName,
            [String] $MacAddress,
            [String] $InstanceId
        )
        $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
        $NcVendorId  = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"

        $vnic = Get-VMNetworkAdapter -VMName $VMName | where {$_.MacAddress -eq $MacAddress}

        $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMNetworkAdapter $vNic

        if ( $currentProfile -eq $null)
        {
            $portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId
            $portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{56785678-a0e5-4a26-bc9b-c0cba27311a3}"
            $portProfileDefaultSetting.SettingData.CdnLabelString = "TestCdn"
            $portProfileDefaultSetting.SettingData.CdnLabelId = 1111
            $portProfileDefaultSetting.SettingData.ProfileName = "Testprofile"
            $portProfileDefaultSetting.SettingData.VendorId = $NcVendorId 
            $portProfileDefaultSetting.SettingData.VendorName = "NetworkController"

            $portProfileDefaultSetting.SettingData.ProfileId = "{$InstanceId}"
            $portProfileDefaultSetting.SettingData.ProfileData = 1
            
            Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $vNic | out-null
        }        
        else
        {
            $currentProfile.SettingData.ProfileId = "{$InstanceId}"
            $currentProfile.SettingData.ProfileData = 1
            Set-VMSwitchExtensionPortFeature  -VMSwitchExtensionFeature $currentProfile  -VMNetworkAdapter $vNic | out-null
        }
    }

    invoke-command -ComputerName $HostName -ScriptBlock $SetPortProfileBlock -ArgumentList $ComputerName, $BackEndMac, $BackEndNic.InstanceId
    invoke-command -ComputerName $HostName -ScriptBlock $SetPortProfileBlock -ArgumentList $ComputerName, $FrontEndMac, $FrontEndNic.InstanceId

    $nchostUserObject = get-networkcontrollerCredential -Connectionuri $URI -ResourceId "NCHostUser" -credential $Credential
    $GatewayPoolObject = get-networkcontrollerGatewayPool -Connectionuri $URI -ResourceId $PoolName -credential $Credential
    
    $VirtualServerProperties = new-object Microsoft.Windows.NetworkController.VirtualServerProperties
    $VirtualServerProperties.Connections = @()
    $VirtualServerProperties.Connections += new-object Microsoft.Windows.NetworkController.Connection
    $VirtualServerProperties.Connections[0].Credential = $nchostUserObject
    $VirtualServerProperties.Connections[0].CredentialType = $nchostUserObject.properties.Type
    $VirtualServerProperties.Connections[0].ManagementAddresses = @($GatewayFQDN)
    $VirtualServerProperties.vmguid = $vmGuid

    $VirtualServerObject = new-networkcontrollervirtualserver -connectionuri $uri -credential $Credential -MarkServerReadOnly $false -ResourceId $GatewayFQDN -Properties $VirtualServerProperties -force

    $GatewayProperties = new-object Microsoft.Windows.NetworkController.GatewayProperties
    $GatewayProperties.NetworkInterfaces = new-object Microsoft.Windows.NetworkController.NetworkInterfaces
    $GatewayProperties.NetworkInterfaces.InternalNetworkInterface = $BackEndNic 
    $GatewayProperties.NetworkInterfaces.ExternalNetworkInterface = $FrontEndNic
    $GatewayProperties.Pool = $GatewayPoolObject
    $GatewayProperties.VirtualServer = $VirtualServerObject

    if (($GatewayPoolObject.Properties.Type -eq "All") -or ($GatewayPoolObject.Properties.Type -eq "S2sIpsec" )) {
        $GatewayProperties.BGPConfig = new-object Microsoft.Windows.NetworkController.GatewayBgpConfig

        $GatewayProperties.BGPConfig.BgpPeer = @()
        $GatewayProperties.BGPConfig.BgpPeer += new-object Microsoft.Windows.NetworkController.GatewayBgpPeer
        $GatewayProperties.BGPConfig.BgpPeer[0].PeerExtAsNumber = "0.$RouterASN"
        $GatewayProperties.BGPConfig.BgpPeer[0].PeerIP = $RouterIP

        $GatewayProperties.BgpConfig.ExtASNumber = "0.$LocalASN"
    }

    $Gw = new-networkcontrollerGateway -connectionuri $uri -credential $Credential -ResourceId $GatewayFQDN -Properties $GatewayProperties -force

    write-sdnexpresslog "New-SDNExpressGateway Exit"
}







function New-SDNExpressVM
{
    param(
        [String] $ComputerName,
        [String] $VMLocation,
        [String] $VMName,
        [String] $VHDSrcPath,
        [String] $VHDName,
        [Int64] $VMMemory=3GB,
        [String] $SwitchName="",
        [Object] $Nics,
        [String] $CredentialDomain,
        [String] $CredentialUserName,
        [String] $CredentialPassword,
        [String] $JoinDomain,
        [String] $LocalAdminPassword,
        [String] $DomainAdminDomain,
        [String] $DomainAdminUserName,
        [String] $ProductKey="",
        [int] $VMProcessorCount = 4,
        [String] $Locale = [System.Globalization.CultureInfo]::CurrentCulture.Name,
        [String] $TimeZone = [TimeZoneInfo]::Local.Id,
        [Bool] $InstallRasRoutingProtocols
        )

    write-sdnexpresslog "New-SDNExpressVM"
    write-sdnexpresslog "  -ComputerName: $ComputerName"
    write-sdnexpresslog "  -VMLocation: $VMLocation"
    write-sdnexpresslog "  -VMName: $VMName"
    write-sdnexpresslog "  -VHDSrcPath: $VHDSrcPath"
    write-sdnexpresslog "  -VHDName: $VHDName"
    write-sdnexpresslog "  -VMMemory: $VMMemory"
    write-sdnexpresslog "  -SwitchName: $SwitchName"
    write-sdnexpresslog "  -Nics: $Nics"
    write-sdnexpresslog "  -CredentialDomain: $CredentialDomain"
    write-sdnexpresslog "  -CredentialUserName: $CredentialUserName"
    write-sdnexpresslog "  -CredentialPassword: ********"
    write-sdnexpresslog "  -JoinDomain: $JoinDomain"
    write-sdnexpresslog "  -LocalAdminPassword: ********"
    write-sdnexpresslog "  -DomainAdminDomain: $DomainAdminDomain"
    write-sdnexpresslog "  -DomainAdminUserName: $DomainAdminUserName"
    write-sdnexpresslog "  -ProductKey: ********"
    write-sdnexpresslog "  -VMProcessorCount: $VMProcessorCount"
    write-sdnexpresslog "  -Locale: $Locale"
    write-sdnexpresslog "  -TimeZone: $TimeZone"
    
    $LocalVMPath = "$vmLocation\$VMName"
    $LocalVHDPath = "$localVMPath\$VHDName"
    $VHDFullPath = "$VHDSrcPath\$VHDName" 

    if ($VMLocation.startswith("\\")) {
        $VMPath = "$VMLocation\$VMName"
    } else {
        $VMPath = "\\$ComputerName\VMShare\$VMName"
    }

    $VHDVMPath = "$VMPath\$VHDName"

    write-sdnexpresslog "Checking for previously mounted image."

    $mounted = get-WindowsImage -Mounted
    foreach ($mount in $mounted) 
    {
        if ($mount.ImagePath -eq $VHDVMPath) {
            DisMount-WindowsImage -Discard -path $mount.Path | out-null
        }
    }

    $vm = $null
    try {
        $VM = get-vm -computername $ComputerName -Name $VMName -erroraction Ignore
        if ($VM -ne $Null) {
            write-sdnexpresslog "VM already exists, exiting VM creation."
            return
        }
    } catch 
    {
        #Continue
    }

    if ([String]::IsNullOrEmpty($SwitchName)) {
        write-sdnexpresslog "Finding virtual switch."
        $SwitchName = invoke-command -computername $computername {
            $VMSwitches = Get-VMSwitch
            if ($VMSwitches -eq $Null) {
                throw "No Virtual Switches found on the host.  Can't create VM.  Please create a virtual switch before continuing."
            }
            if ($VMSwitches.count -gt 1) {
                throw "More than one virtual switch found on host.  Please specify virtual switch name using SwitchName parameter."
            }

            return $VMSwitches.Name
        }
    }
    write-sdnexpresslog "Will attach VM to virtual switch: $SwitchName"

    write-sdnexpresslog "Creating VM root directory and share on host."

    invoke-command -computername $computername {
        param(
            [String] $VMLocation,
            [String] $UserName
        )
        New-Item -ItemType Directory -Force -Path $VMLocation | out-null
        if (!$VMLocation.startswith("\\")) {
            get-SmbShare -Name VMShare -ErrorAction Ignore | remove-SMBShare -Force
            New-SmbShare -Name VMShare -Path $VMLocation -FullAccess $UserName -Temporary | out-null
        }
    } -ArgumentList $VMLocation, ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
    
    write-sdnexpresslog "Creating VM directory and copying VHD.  This may take a few minutes."
    
    New-Item -ItemType Directory -Force -Path $VMPath | out-null
    copy-item -Path $VHDFullPath -Destination $VMPath | out-null

    write-sdnexpresslog "Creating mount directory and mounting VHD."

    $TempFile = New-TemporaryFile
    Remove-Item $TempFile.FullName -Force
    $MountPath = $TempFile.FullName

    New-Item -ItemType Directory -Force -Path $MountPath | out-null
    
    Mount-WindowsImage -ImagePath $VHDVMPath -Index 1 -path $MountPath | out-null

    If ($InstallRasRoutingProtocols) {
        write-sdnexpresslog "Installing RasRoutingProtocols Offline"
        Enable-WindowsOptionalFeature -Path $MountPath -FeatureName RasRoutingProtocols -All -LimitAccess | Out-Null
        }

    write-sdnexpresslog "Generating unattend.xml"

    $count = 1
    $TCPIPInterfaces = ""
    $dnsinterfaces = ""
    
    foreach ($nic in $Nics) {
        
        $MacAddress = [regex]::matches($nic.MacAddress.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"


        if (![String]::IsNullOrEmpty($Nic.IPAddress)) {
            $sp = $NIC.IPAddress.Split("/")
            $IPAddress = $sp[0]
            $SubnetMask = $sp[1]
    
            $Gateway = $Nic.Gateway
            $gatewaysnippet = ""
    
            if (![String]::IsNullOrEmpty($gateway)) {
                $gatewaysnippet = @"
                <routes>
                    <Route wcm:action="add">
                        <Identifier>0</Identifier>
                        <Prefix>0.0.0.0/0</Prefix>
                        <Metric>20</Metric>
                        <NextHopAddress>$Gateway</NextHopAddress>
                    </Route>
                </routes>
"@
            }
    
            $TCPIPInterfaces += @"
                <Interface wcm:action="add">
                    <Ipv4Settings>
                        <DhcpEnabled>false</DhcpEnabled>
                    </Ipv4Settings>
                    <Identifier>$MacAddress</Identifier>
                    <UnicastIpAddresses>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$IPAddress/$SubnetMask</IpAddress>
                    </UnicastIpAddresses>
                    $gatewaysnippet
                </Interface>
"@ 
        } else {
            $TCPIPInterfaces += @"
            <Interface wcm:action="add">
                <Ipv4Settings>
                    <DhcpEnabled>true</DhcpEnabled>
                </Ipv4Settings>
                <Identifier>$MacAddress</Identifier>
            </Interface>
"@ 

        }        
        $alldns = ""
        foreach ($dns in $Nic.DNS) {
                $alldns += '<IpAddress wcm:action="add" wcm:keyValue="{1}">{0}</IpAddress>' -f $dns, $count++
        }

        if ($Nic.DNS -eq $null -or $Nic.DNS.count -eq 0) {
            $dnsregistration = "false"
        } else {
            $dnsregistration = "true"
        }

        $dnsinterfaces += @"
            <Interface wcm:action="add">
                <DNSServerSearchOrder>
                $alldns
                </DNSServerSearchOrder>
                <Identifier>$MacAddress</Identifier>
                <EnableAdapterDomainNameRegistration>$DNSRegistration</EnableAdapterDomainNameRegistration>
            </Interface>
"@
    }

    $ProductKeyField = ""
    if (![String]::IsNullOrEmpty($ProductKey)) {
        $ProductKeyField = "<ProductKey>$ProductKey</ProductKey>"
    }

    $unattendfile = @"
    <?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
        <settings pass="specialize">
            <component name="Microsoft-Windows-TCPIP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <Interfaces>
    $TCPIPInterfaces
                </Interfaces>
            </component>
             <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <Interfaces>
    $DNSInterfaces
                </Interfaces>
            </component>
            <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <Identification>
                    <Credentials>
                        <Domain>$CredentialDomain</Domain>
                        <Password>$CredentialPassword</Password>
                        <Username>$CredentialUsername</Username>
                    </Credentials>
                    <JoinDomain>$JoinDomain</JoinDomain>
                </Identification>
            </component>
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <ComputerName>$VMName</ComputerName>
    $ProductKeyField
            </component>
        </settings>
        <settings pass="oobeSystem">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <UserAccounts>
                    <AdministratorPassword>
                        <Value>$LocalAdminPassword</Value>
                        <PlainText>true</PlainText>
                    </AdministratorPassword>
                    <DomainAccounts>
                        <DomainAccountList wcm:action="add">
                            <DomainAccount wcm:action="add">
                                <Name>$DomainAdminUserName</Name>
                                <Group>Administrators</Group>
                            </DomainAccount>
                            <Domain>$DomainAdminDomain</Domain>
                        </DomainAccountList>
                    </DomainAccounts>
                </UserAccounts>
                <TimeZone>$TimeZone</TimeZone>
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
                <UserLocale>$Locale</UserLocale>
                <SystemLocale>$Locale</SystemLocale>
                <InputLocale>$Locale</InputLocale>
                <UILanguage>$Locale</UILanguage>
            </component>
        </settings>
        <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
    </unattend>
"@
    
    write-sdnexpresslog "Writing unattend.xml to $MountPath\unattend.xml"
    Set-Content -value $UnattendFile -path "$MountPath\unattend.xml" | out-null
    
    write-sdnexpresslog "Cleaning up"

    DisMount-WindowsImage -Save -path $MountPath | out-null
    Remove-Item $MountPath -Force
    Invoke-Command -computername $computername {
        Get-SmbShare -Name VMShare -ErrorAction Ignore | remove-SMBShare -Force | out-null
    }

    write-sdnexpresslog "Creating VM: $computername"
    $NewVM = New-VM -ComputerName $computername -Generation 2 -Name $VMName -Path $LocalVMPath -MemoryStartupBytes $VMMemory -VHDPath $LocalVHDPath -SwitchName $SwitchName
    $NewVM | Set-VM -processorcount $VMProcessorCount | out-null

    $first = $true
    foreach ($nic in $Nics) {
        write-sdnexpresslog "Configuring NIC"
        $FormattedMac = [regex]::matches($nic.MacAddress.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
        write-sdnexpresslog "Configuring NIC with MAC $FormattedMac"
        if ($first) {
            $vnic = $NewVM | get-vmnetworkadapter 
            $vnic | rename-vmnetworkadapter -newname $Nic.Name
            $vnic | Set-vmnetworkadapter -StaticMacAddress $FormattedMac
            $first = $false
        } else {
            #Note: add-vmnetworkadapter doesn't actually return the vnic object for some reason which is why this does a get immediately after.
            $vnic = $NewVM | Add-VMNetworkAdapter -SwitchName $SwitchName -Name $Nic.Name -StaticMacAddress $FormattedMac
            $vnic = $NewVM | get-vmnetworkadapter -Name $Nic.Name  
        }

        if ($nic.vlanid) {
            write-sdnexpresslog "Setting VLANID to $($nic.vlanid)"
            $vnic | Set-VMNetworkAdapterIsolation -AllowUntaggedTraffic $true -IsolationMode VLAN -defaultisolationid $nic.vlanid | out-null
        }

        if ($nic.IsMuxPA) {
            write-sdnexpresslog "This is a mux PA nic, so ProfileData set to 2."
            $ProfileData = 2
        } else {
            $ProfileData = 1
        }

        write-sdnexpresslog "Applying Null Guid to ensure initial ability to communicate with VFP enabled."

        invoke-command -ComputerName $ComputerName -ScriptBlock {
            param(
                [String] $VMName,
                [String] $VMNetworkAdapterName,
                [Int] $ProfileData
            )
            $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
            $NcVendorId  = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"
    
            $vnic = Get-VMNetworkAdapter -VMName $VMName -Name $VMNetworkAdapterName
    
            $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMNetworkAdapter $vNic
    
            if ( $currentProfile -eq $null)
            {
                $portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId
            
                $portProfileDefaultSetting.SettingData.ProfileId = "{$([Guid]::Empty)}"
                $portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{56785678-a0e5-4a26-bc9b-c0cba27311a3}"
                $portProfileDefaultSetting.SettingData.CdnLabelString = "TestCdn"
                $portProfileDefaultSetting.SettingData.CdnLabelId = 1111
                $portProfileDefaultSetting.SettingData.ProfileName = "Testprofile"
                $portProfileDefaultSetting.SettingData.VendorId = $NcVendorId 
                $portProfileDefaultSetting.SettingData.VendorName = "NetworkController"
                $portProfileDefaultSetting.SettingData.ProfileData = $ProfileData
                
                Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $vNic | out-null
            }        
            else
            {
                $currentProfile.SettingData.ProfileId = "{$([Guid]::Empty)}"
                $currentProfile.SettingData.ProfileData = $ProfileData
                Set-VMSwitchExtensionPortFeature  -VMSwitchExtensionFeature $currentProfile  -VMNetworkAdapter $vNic | out-null
            }
        } -ArgumentList $VMName, $nic.Name, $ProfileData
    }
    
    write-sdnexpresslog "Starting VM."

    $NewVM | Start-VM | out-null
    write-sdnexpresslog "New-SDNExpressVM is complete."
}
