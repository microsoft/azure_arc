Import-Module ".\NetworkControllerRESTWrappers.ps1" -Force

function New-ACL
{
    param(
        [Parameter(mandatory=$false)]
        [String] $ResourceId=[System.Guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object[]] $aclRules
    )

    $ar = @()
    foreach ($rule in $aclRules) {
        $ar += New-NCAccessControlListRule -Protocol $rule.Protocol -SourcePortRange $rule.SourcePortRange -DestinationPortRange $rule.DestinationPortRange -sourceAddressPrefix $rule.sourceAddressPrefix -destinationAddressPrefix $rule.destinationAddressPrefix -Action $rule.Action -ACLType $rule.Type -Logging $true -Priority $rule.Priority
    }
    
    $acl1 = New-NCAccessControlList -resourceId $ResourceId -AccessControlListRules $ar
    return $acl1
}

function Get-PortProfileId
{
    param(
        [Parameter(mandatory=$true)]
        [String] $VMName,
        [Parameter(mandatory=$false)]
        [String] $VMNetworkAdapterName=$null,
        [Parameter(mandatory=$false)]
        [String] $ComputerName="localhost"
        )
    write-verbose ("Getting port profile for [$vmname] on [$computername]" )
            
    try 
    {
        $pssession = new-pssession -ComputerName $computername 

        invoke-command -session $pssession -ScriptBlock {
            if ([String]::IsNullOrEmpty($using:VMNetworkAdapterName))
            {
                $vmNics = Get-VMNetworkAdapter -VMName $using:VMName 
            }
            else
            { 
                $vmNics = @(Get-VMNetworkAdapter -VMName $using:VMName -Name $using:VMNetworkAdapterName) 
            }

            $result = @()

            foreach ($vmNic in $vmNics) {
                $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId "9940cd46-8b06-43bb-b9d5-93d50381fd56" -VMNetworkAdapter $vmNic
                if ( $currentProfile -eq $null)
                {
                    $result += $null
                }        
                else
                {
                    $result += [system.guid]::parse($currentProfile.SettingData.ProfileId).tostring()
                }
            }
            return $result
        }
    }
    catch
    {
        Write-Error "Failed with error: $_" 
    }
    finally
    {
        Remove-PSSession $pssession
    }
}

function get-MacAddress
{
    param(
        [Parameter(mandatory=$true)]
        [String] $VMName,
        [Parameter(mandatory=$false)]
        [String] $VMNetworkAdapterName=$null,
        [Parameter(mandatory=$false)]
        [String] $ComputerName="localhost"
        )
    write-verbose ("Getting mac address for [$vmname] on [$computername]" )
            
    try 
    {
        $pssession = new-pssession -ComputerName $computername 

        invoke-command -session $pssession -ScriptBlock {
            if ([String]::IsNullOrEmpty($using:VMNetworkAdapterName))
            {
                $vmNics = Get-VMNetworkAdapter -VMName $using:VMName 
            }
            else
            { 
                $vmNics = @(Get-VMNetworkAdapter -VMName $using:VMName -Name $using:VMNetworkAdapterName) 
            }

            $result = @()

            foreach ($vmNic in $vmNics) {
                    $result += $VMNic.MacAddress
            }
            return $result
        }
    }
    catch
    {
        Write-Error "Failed with error: $_" 
    }
    finally
    {
        Remove-PSSession $pssession
    }
}

function Add-NetworkAdapterToNetwork
{
    param(
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $VMName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [String] $VMNetworkAdapterName = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $ComputerName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$true,ParameterSetName="ByResourceId")]
        [String] $NetworkInterfaceResourceId="",
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$true,ParameterSetName="ByResourceId")]
        [Object] $LogicalNetworkResourceId="",
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$true,ParameterSetName="ByResourceId")]
        [String] $SubnetAddressPrefix="",
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$false,ParameterSetName="ByResourceId")]
        [String] $ACLResourceId=$null,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$false,ParameterSetName="ByResourceId")]
        [String] $IPAddress=""
    )
    
    if ($psCmdlet.ParameterSetName -eq "ByVNIC") {
        $NetworkInterfaceInstanceId = Get-PortProfileId -vmname $vmname -vmnetworkadaptername $VMNetworkAdapterName -computername $computername
        $NetworkInterfaceResourceId = Get-NCNetworkInterfaceResourceId -InstanceId $NetworkInterfaceInstanceId
    }     

    $mac = get-macaddress -vmname $vmname -VMNetworkAdapterName $VMNetworkAdapterName -ComputerName $ComputerName

    if ($mac.count -gt 1) {
        throw "More than one MACaddress found on VM. You must specify VMNetworkAdapterName if more than one network adapter is present on the VM."
    }

    $ln = Get-NCLogicalNetwork -ResourceId $LogicalNetworkResourceId 
    
    foreach ($lnsubnet in $ln.properties.subnets) {
        if ($subnetaddressprefix -eq $lnsubnet.properties.Addressprefix) {
            $subnet = $lnsubnet
        }
    }                
        
    if (([String]::IsNullOrEmpty($NetworkInterfaceResourceId)) -or ($NetworkInterfaceResourceId -eq "") -or ($NetworkInterfaceResourceId -eq [System.Guid]::Empty)) {
        $NetworkInterfaceResourceId = [System.Guid]::NewGuid()
    }
    $nic = get-ncnetworkinterface -resourceID $NetworkInterfaceResourceId

    if ($nic -ne $null -and !$Force) {
        throw "Network interface [$networkinterfaceresourceid] already exists.  Use -Force to replace it."
    }

    #TODO: add acl if specified
    if (![String]::IsNullOrEmpty($ACLResourceId)) {
        $acl = Get-NCAccessControlList -resourceID $ACLResourceId
        if ($acl -eq $null) {
            throw "ACL with resource id $aclresourceid was not found on the network controller."
        }
        $nic = New-NCNetworkInterface -resourceId $NetworkInterfaceResourceId -Subnet $subnet -MACAddress $mac -acl $acl -ipaddress $ipaddress
    } else {
        $nic = New-NCNetworkInterface -resourceId $NetworkInterfaceResourceId -Subnet $subnet -MACAddress $mac -ipaddress $ipaddress
    }    
    set-portprofileid -resourceID $nic.instanceid -VMName $vmname -VMNetworkAdapterName $vmnetworkadaptername -computername $computername -Force

    return $nic

    #TODO: add virtual server for topology
}

function Unblock-NetworkAdapter
{
    param(
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $VMName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [String] $VMNetworkAdapterName = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $ComputerName
    )
    
    if ($psCmdlet.ParameterSetName -eq "ByVNIC") {
        $NetworkInterfaceInstanceId = Get-PortProfileId $vmname $VMNetworkAdapterName $computername
        $NetworkInterfaceResourceId = Get-NCNetworkInterfaceResourceId -InstanceId $NetworkInterfaceInstanceId
    }     

    #if networkadapter exists, remove it
    remove-ncnetworkinterface -resourceid $NetworkInterfaceResourceId

    #remove-ncvirtualserver -resourceid $vsresourceid

    set-portprofileid -resourceID ([guid]::empty) -VMName $vmname -ComputerName $computername -Force
}


function Remove-NetworkAdapterFromNetwork
{
    param(
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $VMName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [String] $VMNetworkAdapterName = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $ComputerName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [Parameter(mandatory=$true,ParameterSetName="ByResourceId")]
        [String] $NetworkInterfaceResourceId=""
    )
    
    if ($psCmdlet.ParameterSetName -eq "ByVNIC") {
        $NetworkInterfaceInstanceId = Get-PortProfileId $vmname $VMNetworkAdapterName $computername
        $NetworkInterfaceResourceId = Get-NCNetworkInterfaceResourceId -InstanceId $NetworkInterfaceInstanceId
    }     

    if($NetworkInterfaceResourceId)
    {
        remove-ncnetworkinterface -resourceid $NetworkInterfaceResourceId
    }
    
    $nullguid = $([System.Guid]::Empty)
    set-portprofileid -ResourceID $nullguid -vmname $vmname -VMNetworkAdapterName $VMNetworkAdapterName -ComputerName $computername -force
    #remove-ncvirtualserver -resourceid $vsresourceid
}

function Set-NetworkAdapterACL
{
    param(
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $VMName,
        [Parameter(mandatory=$false,ParameterSetName="ByVNIC")]
        [String] $VMNetworkAdapterName = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByVNIC")]
        [String] $ComputerName,
        [Parameter(mandatory=$true,ParameterSetName="ByResourceId")]
        [String] $NetworkInterfaceResourceId,
        [Parameter(mandatory=$true)]
        [String] $ACLResourceId
    )
    
    if ($psCmdlet.ParameterSetName -eq "ByVNIC") {
        $NetworkInterfaceInstanceId = Get-PortProfileId $vmname $VMNetworkAdapterName $computername
        if ($NetworkInterfaceInstanceId -eq $null) {
            throw "Could not find port profile id.  Either $vmname does not exist on $computername, or it does not have a port profile defined which would indicate that it has not been added to the network controller."
        }

        if ($NetworkInterfaceInstanceId -ne [System.Guid]::Empty)
        {
           $NetworkInterfaceResourceId = Get-NCNetworkInterfaceResourceId -InstanceId $NetworkInterfaceInstanceId
        }
    }

    $nic = get-ncnetworkinterface -resourceid $NetworkInterfaceResourceId
    
    if ($nic -eq $null) {
        throw "ACL can't be set because a network interface was not found for port profile id $NetworkInterfaceResourceId in the network controller."
    }

    $acl = Get-NCAccessControlList -resourceID $ACLResourceId
    if ($acl -eq $null) {
        throw "ACL with resource id $aclresourceid was not found on the network controller."
    }

    $nic.properties.ipConfigurations[0].properties | add-member -Name "accessControlList" -MemberType NoteProperty -Value @{ resourceRef = $acl.resourceRef }

    JSONPost -path "/NetworkInterfaces" -bodyObject $nic
}

function New-LoadBalancerVIP
{
param(
    [Parameter(mandatory=$false)]
    [Microsoft.HyperV.PowerShell.VirtualMachine[]]$VMPool = $n,
    [Parameter(mandatory=$true)]
    [string]$Vip,
    [Parameter(mandatory=$false)]
    [string]$protocol="TCP",
    [Parameter(mandatory=$true)]
    [int] $frontendPort,
    [Parameter(mandatory=$false)]
    [int] $backendPort=$frontendport,
    [Parameter(mandatory=$false)]
    [Switch] $EnableOutboundNat,
    [parameter(mandatory=$false)]
    [string] $LoadBalancerResourceID=[system.guid]::NewGuid()
)
    $slbm = get-ncloadbalancermanager 

    if ($slbm.properties.vipippools.count -lt 1) {
        throw "New-LoadBalancerVIP requires at least one VIP pool in the NC Load balancer manager."
    }

    $vipPools = $slbm.properties.vipippools
    
    # check if the input VIP is within range of one of the VIP pools
    foreach ($vippool in $vipPools) {
        # IP pool's resourceRef is in this format: 
        # /logicalnetworks/f8f67956-3906-4303-94c5-09cf91e7e311/subnets/aaf28340-30fe-4f27-8be4-40eca97b052d/ipPools/ed48962b-2789-41bf-aa7b-3e6d5b247384
        $sp = $vippool.resourceRef.split("/")
        
        $ln = Get-NCLogicalNetwork -resourceId $sp[2] #LN resourceid is always the first ID (after /logicalnetwork/)
        if (-not $ln) {
            throw "Can't find logical network with resourceId $($sp[2]) from NC."
        }

        $subnet = $ln.properties.subnets | ? {$_.resourceId -eq $sp[4]}
        if (-not $subnet) {
            throw "can't find subnet with resourceId $($sp[4]) from NC."
        }
        
        $pool = $subnet.properties.ipPools | ? {$_.resourceId -eq $sp[6]}
        if (-not $pool) {
            throw "can't find IP pool with resourceId $($sp[6]) from NC."
        }
        
        $startIp = $pool.properties.startIpAddress
        $endIp = $pool.properties.endIpAddress
        if (IsIpWithinPoolRange -targetIp $Vip -startIp $startIp -endIp $endIp) {
            $isPoolPublic = $subnet.properties.isPublic
            $vipLn = $ln
            break;
        }
    }
    
    if (-not $vipLn) {
        throw "$Vip is not within range of any of the VIP pools managed by SLB manager."
    }
    
    # if the VIP is within the range of a pool whose subnet is public, we should create a PublicIPAddress in NC for the VIP
    # so that NC won't accidentially allocate same VIP for tenant use
    if ($isPoolPublic) {
        $publicIp = Get-NCPublicIPAddress | ? {$_.properties.ipaddress -eq $Vip}
        if ($publicIp -eq $null) {
            New-NCPublicIPAddress -PublicIPAddress $Vip
        }
    }
         
    $lbfe = @(New-NCLoadBalancerFrontEndIPConfiguration -PrivateIPAddress $Vip -Subnet ($vipLn.properties.Subnets[0]))
    
    $ips = @()  
    foreach ($VM in $VMPool) {
      $vm_name = $VM.Name
      $vm_computer = $VM.ComputerName
      $vm_nic = $VM.NetworkAdapters[0].Name
      $instanceid = Get-PortProfileId -VMName $vm_name -VMNetworkAdapterName $vm_nic -ComputerName $vm_computer

      #convert port profile id to from instance id to resource id
      $ppid = $NetworkInterfaceResourceId = Get-NCNetworkInterfaceResourceId -InstanceId $instanceid
      
      $vnic = get-ncnetworkinterface -resourceId $ppid
      $ips += $vnic.properties.ipConfigurations[0]
    } 

    $lbbe = @(New-NCLoadBalancerBackendAddressPool -IPConfigurations $ips)
    $rules = @(New-NCLoadBalancerLoadBalancingRule -protocol $protocol -frontendPort $frontendPort -backendport $backendPort -enableFloatingIP $False -frontEndIPConfigurations $lbfe -backendAddressPool $lbbe)

    if ($EnableOutboundNat) {
        $onats = @(New-NCLoadBalancerOutboundNatRule -frontendipconfigurations $lbfe -backendaddresspool $lbbe)
        $lb = New-NCLoadBalancer -ResourceID $LoadBalancerResourceID -frontendipconfigurations $lbfe -backendaddresspools $lbbe -loadbalancingrules $rules -outboundnatrules $onats
    } else {
        $lb = New-NCLoadBalancer -ResourceID $LoadBalancerResourceID -frontendipconfigurations $lbfe -backendaddresspools $lbbe -loadbalancingrules $rules
    }
    return $lb
}
