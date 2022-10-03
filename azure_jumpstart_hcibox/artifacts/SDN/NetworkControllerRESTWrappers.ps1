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
[cmdletbinding()]
Param(
    [Parameter(mandatory=$false)]
    [String] $ComputerName=$null,
    [Parameter(mandatory=$false)]
    [String] $Username=$null,
    [Parameter(mandatory=$false)]
    [String] $Password=$null,
    [Parameter(mandatory=$false)]
    [PSCredential] $Credential=[System.Management.Automation.PSCredential]::Empty
    )

$script:urlroot = "https://"
#region Private script variables
$script:NetworkControllerRestIP = $ComputerName
if (![String]::isnullorempty($Username)) {
    $securepass =  convertto-securestring $Password -asplaintext -force
    $script:NetworkControllerCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username,$securepass
}  else {
    $script:NetworkControllerCred = $Credential
}      
#endregion

#region some IPv4 address related helper functions

function Convert-IPv4StringToInt {
    param([string] $addr)

    $ip = $null
    $valid = [System.Net.IPAddress]::TryParse($addr, [ref]$ip)
    if (!$valid -or $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "$addr is not a valid IPv4 address."
    }
    
    $sp = $addr.Split(".", 4)
    $bits = [System.Convert]::ToInt64($sp[0])
    $bits = $bits -shl 8
    $bits += [System.Convert]::ToInt64($sp[1])
    $bits = $bits -shl 8
    $bits += [System.Convert]::ToInt64($sp[2])
    $bits = $bits -shl 8
    $bits += [System.Convert]::ToInt64($sp[3])

    $bits
}

function Convert-IPv4IntToString {
    param([Int64] $addr)

    "{0}.{1}.{2}.{3}" -f (($addr -shr 24) -band 0xff), (($addr -shr 16) -band 0xff), (($addr -shr 8) -band 0xff), ($addr -band 0xff )
        
}

function IsIpPoolRangeValid {
    param(
        [Parameter(Mandatory=$true)][string]$startIp,
        [Parameter(Mandatory=$true)][string]$endIp
        )

    $startIpInt = Convert-IPv4StringToInt -addr $startIp
    $endIpInt = Convert-IPv4StringToInt -addr $endIp

    if( $startIpInt -gt $endIpInt) {
        return $false
    }

    return $true
}

function IsIpWithinPoolRange {
    param(
        [Parameter(Mandatory=$true)][string]$targetIp,
        [Parameter(Mandatory=$true)][string]$startIp,
        [Parameter(Mandatory=$true)][string]$endIp
        )

    $startIpInt = Convert-IPv4StringToInt -addr $startIp
    $endIpInt = Convert-IPv4StringToInt -addr $endIp
    $targetIpInt = Convert-IPv4StringToInt -addr $targetIp
    
    if (($targetIpInt -ge $startIpInt) -and ($targetIpInt -le $endIpInt)) {
        return $true
    }
    
    return $false
}

#endregion

#region Invoke command wrapper
function Invoke-CommandVerify
{
    param (
        [Parameter(mandatory=$true)]
            [ValidateNotNullOrEmpty()][string[]]$ComputerName,
        [Parameter(mandatory=$true)]
            [ValidateNotNullOrEmpty()][PSCredential]$Credential, 
        [Parameter(mandatory=$true)]
            [ValidateNotNullOrEmpty()][ScriptBlock]$ScriptBlock,
        [Parameter(mandatory=$false)]
            [Object[]]$ArgumentList = $null,
        [Parameter(mandatory=$false)]
            [int]$RetryCount = 3
     )

     # find number of targets
     $numberTargets = $ComputerName.Count

     if ($numberTargets -eq 0)
     {
         throw "Please specify >= 1 target"
     }

     do 
     {
        # create sessions
        $sessions = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Ignore

        # ensure number of sessions match target number
        if ($sessions.Count -eq $numberTargets)
        {
            $readyActive = 0
            # ensure that all the sessions are active
            foreach ($session in $sessions)
            {
                if ( ($session.State -eq "Opened") -and ($session.Availability -eq "Available") )
                {
                    $readyActive ++
                }
                else
                {
                    Write-Verbose "Session: $($session.Name) is $($session.State) and $($session.Availability)"
                }
            }

            if ($readyActive -eq $numberTargets)
            {
                Write-Verbose "All sessions are active and ready for $($ComputerName)"
                break
            }
        }
        else
        {
            Write-Verbose "Different number of Session: $($sessions.Count) and  $($numberTargets)"
        }

        # close any active sessions
        Write-Verbose "Not all sessions are active and ready for $($ComputerName), retrying $($RetryCount)"
        if ($sessions)
        {
            $sessions | Remove-PSSession -ErrorAction Ignore
        }
        $RetryCount --
        $session = $null
        Sleep 10
     } while ($RetryCount -gt 0)

     if ($sessions -eq $null)
     {
         Write-Verbose "Cannot establish all PS sessions for $($ComputerName)"
         throw "Cannot establish all PS sessions for $($ComputerName)"
     }

     Write-Verbose "Invoking command"
     if ($ArgumentList)
     {
         $returnObject = Invoke-Command -Session $sessions -Argumentlist $ArgumentList -ScriptBlock $ScriptBlock
     } 
     else {
         $returnObject = Invoke-Command -Session $sessions -ScriptBlock $ScriptBlock
     }

     Write-Verbose "Closing all sessions"
     $sessions | Remove-PSSession -ErrorAction Ignore

     return $returnObject
}

#endregion

#region Private JSON helper functions

function Invoke-WebRequestWithRetries {
    param(
        [System.Collections.IDictionary] $Headers,
        [string] $ContentType,
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,
        [System.Uri] $Uri,
        [object] $Body,
        [Switch] $DisableKeepAlive,
        [Switch] $UseBasicParsing,
        [System.Management.Automation.PSCredential] $Credential,
        [System.Management.Automation.Runspaces.PSSession] $RemoteSession,
        [Parameter(mandatory=$false)]
        [bool] $shouldRetry = $true
    )
        
    $params = @{
        'Headers'=$headers;
        'ContentType'=$content;
        'Method'=$method;
        'uri'=$uri
        }
    
    if($Body -ne $null) {
        $params.Add('Body', $Body)
    }
    if($DisableKeepAlive.IsPresent) {
        $params.Add('DisableKeepAlive', $true)
    }
    if($UseBasicParsing.IsPresent) {
        $params.Add('UseBasicParsing', $true)
    }
    if($Credential -ne [System.Management.Automation.PSCredential]::Empty -and $Credential -ne $null) {
        $params.Add('Credential', $Credential)
    }
    
    $retryIntervalInSeconds = 30
    $maxRetry = 6
    $retryCounter = 0
    
    do {
        try {
            if($RemoteSession -eq $null) {            
                $result = Invoke-WebRequest @params
            }
            else {
                $result = Invoke-Command -Session $RemoteSession -ScriptBlock {
                    Invoke-WebRequest @using:params
                }
            }
            break
        }
        catch {
            Write-Verbose "Invoke-WebRequestWithRetries: $($Method) Exception: $_"
            Write-Verbose "Invoke-WebRequestWithRetries: $($Method) Exception: $($_.Exception.Response)"
            
            if ($_.Exception.Response.statuscode -eq "NotFound") {
                    return $null
            }
            
            $retryCounter++
            if($retryCounter -le $maxRetry) {

                Write-verbose "Invoke-WebRequestWithRetries: retry this operation in $($retryIntervalInSeconds) seconds. Retry count: $($retryCounter)."
                sleep -Seconds $retryIntervalInSeconds
            }
            else {
                # last retry still fails, so throw the exception
                throw $_
            }
        }
    } while ($shouldRetry -and ($retryCounter -le $maxRetry)) 
    
    return $result       
}

function JSONPost {
    param(
        [Parameter(position=0,mandatory=$true,ParameterSetName="WithCreds")]
        [String] $NetworkControllerRestIP=$script:NetworkControllerRestIP,
        [Parameter(position=1,mandatory=$true,ParameterSetName="WithCreds")]
        [Parameter(position=0,mandatory=$true,ParameterSetName="CachedCreds")]
        [String] $path,  #starts with object, does not include server, i.e. "/Credentials"
        [Parameter(position=2,mandatory=$true,ParameterSetName="WithCreds")]
        [Parameter(position=1,mandatory=$true,ParameterSetName="CachedCreds")]
        [Object] $bodyObject,
        [Parameter(position=3,mandatory=$true,ParameterSetName="WithCreds")]
        [Object] $credential=$script:NetworkControllerCred,
        [Parameter(position=4,mandatory=$false,ParameterSetName="WithCreds")]
        [String] $computerName=$null
    )

    if ($NetworkControllerRestIP -eq "")
    {
        write-error "Network controller REST IP not specified.  You must first call Set-NCConnection."
        return
    }

    $headers = @{"Accept"="application/json"}
    $content = "application/json; charset=UTF-8"
    $uriRoot = "$($script:urlroot)$NetworkControllerRestIP/Networking/v1"
    $timeout = 10

    $method = "Put"
    $uri = "$uriRoot$path/$($bodyObject.resourceId)"
    $body = convertto-json $bodyObject -Depth 100
    $pssession = $null

    Write-Verbose "JSON Put [$path]"
    if ($path -notlike '/Credentials*') {
        Write-Verbose "Payload follows:"
        Write-Verbose $body
    }
    
    try {
        # $computerName is here to workaround product limitation for PUT of LoadBalancer, which is > 35KB and must be done from the REST hosting NC Vm.
        if (-not $computerName) {
            if ($credential -eq [System.Management.Automation.PSCredential]::Empty -or $credential -eq $null) {
                Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -Body $body -DisableKeepAlive -UseBasicParsing | out-null
            } else {
                Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -Body $body -DisableKeepAlive -UseBasicParsing -Credential $credential | out-null
            }
        }
        else {       
            $pssession = new-pssession -ComputerName $computerName -Credential $credential
            Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -Body $body -DisableKeepAlive -UseBasicParsing -Credential $credential -RemoteSession $pssession | out-null       
        }
    }
    catch {
       Write-Verbose "PUT Exception: $_"
       Write-Verbose "PUT Exception: $($_.Exception.Response)"
    }
    finally {
        if($pssession -ne $null)
        {
            Remove-PSSession $pssession
        }
    }
}

function JSONGet {
    param(
        [Parameter(mandatory=$true)]
        [String] $NetworkControllerRestIP,
        [Parameter(mandatory=$true)]
        [String] $path,  #starts with object and may include resourceid, does not include server, i.e. "/Credentials" or "/Credentials/{1234-
        [Parameter(mandatory=$false)]
        [Switch] $WaitForUpdate,
        [Switch] $Silent,
        [PSCredential] $credential
    )

    if ($NetworkControllerRestIP -eq "")
    {
        write-error "Network controller REST IP not specified.  You must first call Set-NCConnection."
        return
    }

    $headers = @{"Accept"="application/json"}
    $content = "application/json; charset=UTF-8"
    $uriRoot = "$($script:urlroot)$NetworkControllerRestIP/Networking/v1"

    $method = "Get"
    $uri = "$uriRoot$path"
    
    if (!$Silent) {
        Write-Verbose "JSON Get [$path]"
    }

    try {
        $NotFinished = $true
        do {
            if ($credential -eq [System.Management.Automation.PSCredential]::Empty -or $credential -eq $null) {
                $result = Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -DisableKeepAlive -UseBasicParsing 
            } else {
                $result = Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -DisableKeepAlive -UseBasicParsing -Credential $credential
            }
            
            if($result -eq $null) {
                return $null    
            }
            
            #Write-Verbose "JSON Result: $result"
            $toplevel = convertfrom-json $result.Content
            if ($toplevel.value -eq $null)
            {
                    $obj = $toplevel
            } else {
                    $obj = $toplevel.value
            }

            if ($WaitForUpdate.IsPresent) {
                    if ($obj.properties.provisioningState -eq "Updating")
                    {
                        Write-Verbose "JSONGet: the object's provisioningState is Updating. Wait 1 second and check again."
                        sleep 1 #then retry
                    }
                    else
                    {
                        $NotFinished = $false
                    }
            }
            else
            {
                $notFinished = $false
            }
      } while ($NotFinished)

      if ($obj.properties.provisioningState -eq "Failed") {
         write-error ("Provisioning failed: {0}`nReturned Object: {1}`nObject properties: {2}" -f $uri, $obj, $obj.properties)
      }
      return $obj
    }
    catch
    {
        if (!$Silent)
        {
           Write-Verbose "GET Exception: $_"
           Write-Verbose "GET Exception: $($_.Exception.Response)"
        }
        return $null
    }
}

function JSONDelete {
    param(
        [String] $NetworkControllerRestIP,
        [String] $path, 
        [Parameter(mandatory=$false)]
        [Switch] $WaitForUpdate,
        [PSCredential] $credential
    )
    if ($NetworkControllerRestIP -eq "")
    {
        write-error "Network controller REST IP not specified.  You must first call Set-NCConnection."
        return
    }

    $headers = @{"Accept"="application/json"}
    $content = "application/json; charset=UTF-8"
    $uriRoot = "$($script:urlroot)$NetworkControllerRestIP/Networking/v1"

    $method = "Delete"
    $uri = "$uriRoot$path"
   
    Write-Verbose "JSON Delete [$path]"
    try {
        if ($credential -eq [System.Management.Automation.PSCredential]::Empty -or $credential -eq $null) {
            Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -DisableKeepAlive -UseBasicParsing
        } else {
            Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method $method -Uri $uri -DisableKeepAlive -UseBasicParsing -Credential $credential
        }
    }
    catch {
        Write-Verbose "PUT Exception: $_"
        Write-Verbose "PUT Exception: $($_.Exception.Response)"
    }

    $maxRecheck = 100
    $currentCheck = 0
    if ($WaitForUpdate.IsPresent) {
        try {
            $NotFinished = $true
            do {
                if ($credential -eq [System.Management.Automation.PSCredential]::Empty -or $credential -eq $null) {
                        $result = Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method "GET" -Uri $uri -DisableKeepAlive -UseBasicParsing
                } 
                else {
                        $result = Invoke-WebRequestWithRetries -Headers $headers -ContentType $content -Method "GET" -Uri $uri -DisableKeepAlive -UseBasicParsing -Credential $credential
                }
                
                if($result -ne $null) {
                    Write-Verbose "Object still exists, check again in 1 second"
                    sleep 1 #then retry
                    $currentCheck++
                }
                else {
                    break
                }
            } while ($currentCheck -lt $maxRecheck)
        }
        catch {
            if ($_.Exception.Response.statuscode -eq "NotFound") {
                return
            }
            Write-Verbose "GET Exception: $_"
            Write-Verbose "GET Exception: $($_.Exception.Response)"
        }
    }
}

#endregion

function Get-NCNetworkInterfaceResourceId
{
    param(
        [Parameter(mandatory=$true)]
        [String] $InstanceId
        )
    if (([String]::IsNullOrEmpty($InstanceId)) -or ($InstanceId -eq "") -or ($InstanceId -eq [System.Guid]::Empty)) {
        write-verbose ("Instance id ($InstanceId) either null or empty string or empty guid")
        return $InstanceId
    }

    write-verbose ("Searching resourceId for instance id [$InstanceId]." )
            
    try 
    {
        $interfaces = JSONGet $script:NetworkControllerRestIP "/networkinterfaces" -Credential $script:NetworkControllerCred

        if ($interfaces -ne $null)
        {
            foreach ($interface in $interfaces)
            {
                if ($interface.instanceId -eq $InstanceId)
                {
                    return $interface.resourceId
                }
            }
        }
    }
    catch
    {
        Write-Error "Failed with error: $_" 
    }

    return $null
}

function Get-NCNetworkInterfaceInstanceId
{
    param(
        [Parameter(mandatory=$true)]
        [String] $ResourceId
        )
    if (([String]::IsNullOrEmpty($ResourceId)) -or ($ResourceId -eq "") -or ($ResourceId -eq [System.Guid]::Empty)) {
        write-verbose ("Resource id ($ResourceId) either null or empty string or empty guid")
        return $ResourceId
    }

    write-verbose ("Searching Instance Id for Resource Id [$ResourceId]." )
            
    try 
    {
        $interfaces = JSONGet $script:NetworkControllerRestIP "/networkinterfaces" -Credential $script:NetworkControllerCred

        if ($interfaces -ne $null)
        {
            foreach ($interface in $interfaces)
            {
                if ($interface.resourceId -eq $ResourceId)
                {
                    return $interface.instanceId
                }
            }
        }
    }
    catch
    {
        Write-Error "Failed with error: $_" 
    }

    return $null
}

function Set-NCConnection
{
    param(
        [Parameter(position=0,mandatory=$true,ParameterSetName="Credential")]
        [Parameter(position=0,mandatory=$true,ParameterSetName="NoCreds")]
        [string] $RestIP,
        [Parameter(mandatory=$true,ParameterSetName="Credential")]
        [PSCredential] $Credential=[System.Management.Automation.PSCredential]::Empty
        )

    $script:NetworkControllerRestIP = $RestIP
    $script:NetworkControllerCred = $Credential
}

function New-NCLogicalNetwork                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$false)]
        [object[]] $LogicalNetworkSubnets=$null,
        [Switch] $EnableNetworkVirtualization
    )

    $LogicalNetwork = @{}
    $LogicalNetwork.resourceId = $resourceId
    $logicalNetwork.properties = @{}
    
    if ($LogicalNetworkSubnets -eq $null) 
    {
        $logicalNetwork.properties.subnets = @()
    }
    else
    {
        $logicalNetwork.properties.subnets = $LogicalNetworkSubnets
    }

    if ($EnableNetworkVirtualization.ispresent) {
        $logicalNetwork.properties.networkVirtualizationEnabled = "True"
    } else {
        $logicalNetwork.properties.networkVirtualizationEnabled = "False"
    }
    JSONPost  $script:NetworkControllerRestIP "/logicalnetworks" $logicalnetwork -Credential $script:NetworkControllerCred  | out-null
    return JSONGet $script:NetworkControllerRestIP "/logicalnetworks/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred


}
function Get-NCLogicalNetwork                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=""
     )
     
     return JSONGet $script:NetworkControllerRestIP "/logicalnetworks/$ResourceId" -Credential $script:NetworkControllerCred
}
function Remove-NCLogicalNetwork                      {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/logicalnetworks/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function Get-NCLogicalNetworkSubnet                        {
    param(
        [Parameter(mandatory=$true)]
        [object] $LogicalNetwork,
        [Parameter(mandatory=$false)]
        [string] $ResourceID=""
     )
     
     if ($resourceId -eq "") {
        $uri = "/logicalnetworks/$($LogicalNetwork.ResourceId)/subnets"
    } else {
        $uri = "/logicalnetworks/$($LogicalNetwork.ResourceId)/subnets/$ResourceId"
    }

     return JSONGet $script:NetworkControllerRestIP $uri -Credential $script:NetworkControllerCred
}

function New-NCLogicalNetworkSubnet                   {
#Creates an in-memory object only.  Must pass it into New-NCLogicalNetwork to persist it.
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $AddressPrefix,
        [Parameter(mandatory=$false)]
        [string[]] $DNSServers = @(),
        [Parameter(mandatory=$false)]
        [int] $VLANid = 0,
        [Parameter(mandatory=$true)]
        [string[]] $defaultGateway,
        [Switch] $IsPublic
        )
    $subnet = @{}
    $subnet.resourceId = $ResourceID
    $subnet.properties = @{} 
    $subnet.properties.addressPrefix = $AddressPrefix
    $subnet.properties.vlanid = "$vlanid"
    if ($dnsservers -ne $null -and $dnsservers.count -gt 0) {
        $subnet.properties.dnsServers = $dnsServers
    }
    $subnet.properties.defaultGateways = $defaultGateway
    $subnet.properties.IsPublic = $IsPublic.IsPresent

    return $subnet
}

function New-NCCredential                             {
    param(
        [Parameter(mandatory=$false,parametersetname='username')]
        [Parameter(mandatory=$false,parametersetname='cert')]
        [Parameter(mandatory=$false,parametersetname='snmp')]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true,parametersetname='username')]
        [string] $Username=$null,
        [Parameter(mandatory=$true,parametersetname='username')]
        [String] $password=$null,
        [Parameter(mandatory=$true,parametersetname='snmp')]
        [String] $communitystring=$null,
        [Parameter(mandatory=$true,parametersetname='cert')]
        [string] $Thumbprint
    )

    # create credentials that will be used to talk to host

    $creds = @{}
    $creds.resourceID = $resourceID
    $creds.properties = @{}
    if ($pscmdlet.ParameterSetName -eq 'cert') {
        $creds.properties.Type = "X509Certificate"
        $creds.properties.Value = $thumbprint
    }
    elseif ($pscmdlet.ParameterSetName -eq 'username') {
        $creds.properties.Type = "UsernamePassword"
        $creds.properties.Username = $Username 
        $creds.properties.Value = $password 
    } 
    else {
        $creds.properties.Type = "SnmpCommunityString"
        $creds.properties.Value = $communitystring
    }

    JSONPost $script:NetworkControllerRestIP "/Credentials" $creds  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/Credentials/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCCredential                             {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/Credentials/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCCredential                          {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/Credentials/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function New-NCServerConnection                       {
    #Creates an in-memory object only.  Must pass it into New-NCServer to persist it.
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ComputerNames,
        [Parameter(mandatory=$true)]
        [object] $Credential
    )
    
    $connection = @{}
    $connection.managementAddresses = $ComputerNames
    $connection.credential = @{}
    $connection.credential.resourceRef = "/credentials/$($credential.ResourceID)"
    $connection.credentialType = $credential.properties.Type

    return $connection
}

function New-NCServerNetworkInterface                 {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$false)]
        [boolean] $IsBMC=$false,
        [Parameter(mandatory=$true,ParameterSetName="LogicalSubnet")]
        [object[]] $LogicalNetworkSubnets
    )
    
    $networkInterface = @{}
    $networkInterface.resourceId = $ResourceID
    $networkInterface.instanceId = $ResourceID
    $networkInterface.properties = @{}
    $networkInterface.properties.isBMC = $IsBMC
    
    $networkInterface.properties.logicalSubnets = @()
    foreach ($logicalnetworksubnet in $logicalNetworkSubnets) {
        $logicalSubnetref = @{}
        $logicalSubnetref.resourceRef = $logicalnetworksubnet.resourceRef
        $networkInterface.properties.logicalSubnets += $logicalSubnetref
    }

    return $networkInterface
}
function New-NCServer                                 {
#Must pass in ResourceID since it must match id of virtual switch
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceID,
        [Parameter(mandatory=$true)]
        [object[]] $Connections,
        [Parameter(mandatory=$false)]
        [string] $Certificate = $null,
        [Parameter(mandatory=$true)]
        [object[]] $PhysicalNetworkInterfaces

    )

    $server = @{}
    $server.resourceId = $ResourceID
    $server.instanceId = $ResourceID
    $server.properties = @{}
    
    $server.properties.connections = $Connections
    $server.properties.networkInterfaces = $PhysicalNetworkInterfaces
    if ($certificate -ne $null) {
        $server.properties.certificate = $certificate
    }

    JSONPost  $script:NetworkControllerRestIP "/Servers" $server  -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/Servers/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCServer                                 {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/Servers/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCServer                              {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/Servers/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function New-NCMACPool                                {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $StartMACAddress,
        [Parameter(mandatory=$true)]
        [string] $EndMACAddress
        )

    $macpool = @{}
    $macpool.resourceId = $ResourceId
    $macpool.properties = @{}
    $macpool.properties.startMacAddress = $StartMACAddress
    $macpool.properties.endMacAddress = $EndMACAddress   

    JSONPost  $script:NetworkControllerRestIP "/MacPools" $macPool  -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/MacPools/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCMACPool                                {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/MacPools/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCMACPool                             {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/MacPools/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
     }
}

function New-NCIPPool                                 {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object] $LogicalNetworkSubnet,
        [Parameter(mandatory=$true)]
        [string] $StartIPAddress,
        [Parameter(mandatory=$true)]
        [string] $EndIPAddress,
        [Parameter(mandatory=$false)]
        [string[]] $DNSServers,
        [Parameter(mandatory=$false)]
        [string[]] $DefaultGateways
        )

    #todo: prevalidate that ip addresses and default gateway are within subnet

    $ippool = @{}
    $ippool.resourceId = $ResourceId
    $ippool.properties = @{}
    $ippool.properties.startIpAddress = $StartIPAddress
    $ippool.properties.endIpAddress = $EndIPAddress
    
    $refpath = "$($logicalnetworksubnet.resourceRef)/ippools"
    JSONPost  $script:NetworkControllerRestIP $refpath $ippool  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "$refpath/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCIPPool                                {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = "",
        [Parameter(mandatory=$true)]
        [object] $LogicalNetworkSubnet
    )
    $refpath = "$($logicalnetworksubnet.resourceRef)/ippools"
    return JSONGet $script:NetworkControllerRestIP "$refpath/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCIPPool                             {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs,
        [Parameter(mandatory=$true)]
        [object] $LogicalNetworkSubnet
     )
    $refpath = "$($logicalnetworksubnet.resourceRef)/ippools"
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "$refpath/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
     }
}
function New-NCAccessControlListRule                  {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $Protocol,
        [Parameter(mandatory=$true)]
        [string] $SourcePortRange,
        [Parameter(mandatory=$true)]
        [string] $DestinationPortRange,
        [Parameter(mandatory=$true)]
        [string] $SourceAddressPrefix,
        [Parameter(mandatory=$true)]
        [string] $DestinationAddressPrefix,
        [Parameter(mandatory=$true)]
        [string] $Action,
        [Parameter(mandatory=$true)]
        [string] $ACLType,
        [Parameter(mandatory=$true)]
        [boolean] $Logging,
        [Parameter(mandatory=$true)]
        [int] $Priority
        )

    $aclRule = @{}
    $aclRule.resourceId = $resourceId

    $aclRule.properties = @{}
    $aclRule.properties.protocol = $protocol
    $aclRule.properties.sourcePortRange = $SourcePortRange
    $aclRule.properties.destinationPortRange = $Destinationportrange
    $aclRule.properties.sourceAddressPrefix = $SourceAddressPrefix
    $aclRule.properties.destinationAddressPrefix = $destinationAddressprefix
    $aclRule.properties.action = $action
    $aclRule.properties.type = $ACLType
    if ($logging) {
        $aclRule.properties.logging = "Enabled"
    } else {
        $aclRule.properties.logging = "Disabled"
    }
    $aclRule.properties.priority = "$priority"

    return $aclRule
}
function New-NCAccessControlList                      {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object[]] $AccessControlListRules
        )

    $acls = @{}
    $acls.resourceID = $resourceId
    $acls.properties = @{}
    $acls.properties.aclRules = $AccessControlListRules

    $acls.properties.ipConfigurations = @()
    $acls.properties.subnet = @()

    $refpath = "/accessControlLists"
    JSONPost  $script:NetworkControllerRestIP $refpath $acls  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "$refpath/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCAccessControlList                      {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/accessControlLists/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCAccessControlList                   {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/accessControlLists/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
     }
}

function New-NCVirtualSubnet                          {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $addressPrefix,
        [Parameter(mandatory=$true)]
        [object] $AccessControlList
        )

    $subnet = @{}
    $subnet.resourceId = $ResourceId
    $subnet.properties = @{}
    $subnet.properties.addressPrefix = $AddressPrefix

    $subnet.properties.accessControlList = @{}
    $subnet.properties.accessControlList.resourceRef = $AccessControlList.resourceRef

    $subnet.properties.ipConfigurations = @()
    
    return $subnet
}

function Get-NCVirtualSubnet                        {
    param(
        [Parameter(mandatory=$true)]
        [object] $VirtualNetwork,
        [Parameter(mandatory=$false)]
        [string] $ResourceID=""
     )
     
     if ($resourceId -eq "") {
        $uri = "/VirtualNetworks/$($VirtualNetwork.ResourceId)/subnets"
    } else {
        $uri = "/VirtualNetworks/$($VirtualNetwork.ResourceId)/subnets/$ResourceId"
    }

     return JSONGet $script:NetworkControllerRestIP $uri -Credential $script:NetworkControllerCred
}

function New-NCVirtualNetwork                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string[]] $addressPrefixes,
        [Parameter(mandatory=$true)]
        [object] $LogicalNetwork,
        [Parameter(mandatory=$true)]
        [object[]] $VirtualSubnets
        )

    $vnet = @{}
    $vnet.resourceId = $resourceId
    $vnet.properties = @{}
    $vnet.properties.addressSpace = @{}
    $vnet.properties.addressSpace.addressPrefixes = $AddressPrefixes
    $vnet.properties.logicalnetwork = @{}
    $vnet.properties.logicalnetwork.resourceRef = "/logicalnetworks/$($LogicalNetwork.resourceId)"
    $vnet.properties.subnets = $VirtualSubnets

    $refpath = "/virtualnetworks"
    JSONPost  $script:NetworkControllerRestIP $refpath $vnet  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "$refpath/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred

}
function Get-NCVirtualNetwork                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/VirtualNetworks/$resourceID" -Credential $script:NetworkControllerCred
}
function Remove-NCVirtualNetwork                      {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/VirtualNetworks/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
     }
}

function Set-NCLoadBalancerManager                    {
    param(
        [Parameter(mandatory=$false)]
        [Object[]] $VIPIPPools=$null,
        [Parameter(mandatory=$false)]
        [String[]] $OutboundNatIPExemptions=$null,
        [Parameter(mandatory=$true)]
        [String] $IPAddress

)

    $LBM = @{}
    $lbm.resourceId = "config"
    $lbm.properties = @{}
    $lbm.properties.loadbalancermanageripaddress = $IPAddress
    
    if ($VIPIPPools -ne $NULL) {
        $lbm.properties.vipIpPools = @()

        foreach ($ippool in $VIPIPPools) {
            $poolRef = @{}
            $poolRef.resourceRef = $ippool.resourceRef
            $lbm.properties.vipIpPools += $poolRef
        }
    }
    
    if ($OutboundNatIPExemptions -ne $null) {
        $lbm.properties.OutboundNatIPExemptions = $OutboundNatIPExemptions
    }

    JSONPost  $script:NetworkControllerRestIP "/loadbalancermanager" $lbm   -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/loadbalancermanager/config" -WaitForUpdate -Credential $script:NetworkControllerCred


}
function Get-NCLoadbalancerManager                    {
     
     return JSONGet $script:NetworkControllerRestIP "/LoadBalancerManager/Config"  -Credential $script:NetworkControllerCred
}

function New-NCVirtualServer                          {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object[]] $Connections,
        [Parameter(mandatory=$false)]
        [string] $Certificate,
        [Parameter(mandatory=$true)]
        [string] $vmGuid
    )

    $server = @{}
    $server.resourceId = $ResourceID
    if ($ResourceID.Length -lt 36)
    { $server.instanceId = [system.guid]::NewGuid() }
    else
    { $server.instanceId = $ResourceID }
    $server.properties = @{}
    
    $server.properties.connections = $Connections
    if (![string]::IsNullOrEmpty($Certificate))
    {
        $server.properties.certificate = $certificate
    }
    $server.properties.vmGuid = $vmGuid

    JSONPost  $script:NetworkControllerRestIP "/VirtualServers" $server  -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/VirtualServers/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred

}
function Get-NCVirtualServer                          {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/VirtualServers/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCVirtualServer                       {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/VirtualServers/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function New-NCLoadBalancerMuxPeerRouterConfiguration {
    param(
        [Parameter(mandatory=$true)]
        [string] $RouterName,
        [Parameter(mandatory=$true)]
        [string] $RouterIPAddress,
        [Parameter(mandatory=$true)]
        [int] $PeerASN,
        [Parameter(mandatory=$false)]
        [string] $LocalIPAddress
        )

    $peer = @{}
    $peer.routerName = $RouterName
    $peer.routerIPAddress = $RouterIPAddress
    $peer.PeerASN = "$PeerASN"
    $peer.localIPAddress = $LocalIPAddress

    return $peer
}
function New-NCLoadBalancerMux                        {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [int] $LocalASN,
        [Parameter(mandatory=$false)]
        [object[]] $peerRouterConfigurations,
        [Parameter(mandatory=$true)]
        [object] $VirtualServer,
        [Parameter(mandatory=$false)]
        [object[]] $connections

    )

    # create credentials that will be used to talk to host

    $mux = @{}
    $mux.resourceID = $resourceID
    $mux.properties = @{}
    $mux.properties.routerConfiguration = @{}
    $mux.properties.routerConfiguration.localASN = "$LocalASN"
    $mux.properties.routerConfiguration.peerRouterConfigurations = @()
    foreach ($peerRouterConfiguration in $peerRouterConfigurations) 
    {
        $mux.properties.routerConfiguration.peerRouterConfigurations += $peerRouterConfiguration
    }
    $mux.properties.virtualServer = @{}
    $mux.properties.virtualServer.resourceRef = $VirtualServer.resourceRef

    JSONPost $script:NetworkControllerRestIP "/LoadBalancerMuxes" $mux  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/LoadBalancerMuxes/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCLoadBalancerMux                        {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/LoadBalancerMuxes/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCLoadBalancerMux                     {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/LoadBalancerMuxes/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function New-NCLoadBalancerFrontEndIPConfiguration    {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        #[Parameter(mandatory=$true)]
        #[object] $LoadBalancer,
        [Parameter(mandatory=$true)]
        [string] $PrivateIPAddress,
        #[Parameter(mandatory=$true)]
        #[object[]] $LoadBalancingRules,
        [Parameter(mandatory=$true)]
        [object] $Subnet
        )
    
    $frontend= @{}
    $frontend.resourceID = $resourceID
    $frontend.properties = @{}
    $frontend.properties.privateIPAddress = $PrivateIPAddress
    $frontend.properties.privateIPAllocationMethod = "Static"
    $frontend.properties.Subnet = @{}
    $frontend.properties.Subnet.resourceRef = $subnet.resourceRef

    return $frontend
}

function New-NCLoadBalancerBackendAddressPool         {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid()
        )
    
    $be= @{}
    $be.resourceID = $resourceID
    $be.properties = @{}

    $be.properties.backendIPConfigurations = @()
    return $be
}
function New-NCLoadBalancerLoadBalancingRule          {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $protocol,
        [Parameter(mandatory=$true)]
        [int] $frontendPort,
        [Parameter(mandatory=$true)]
        [int] $backendPort,
        [Parameter(mandatory=$true)]
        [boolean] $enableFloatingIP,
        [Parameter(mandatory=$false)]
        [int] $IdleTimeoutInMinutes = 4,
        [Parameter(mandatory=$false)]
        [String] $LoadDistribution = "Default",
        [Parameter(mandatory=$true)]
        [object[]] $frontEndIPConfigurations = $null,
        [Parameter(mandatory=$true)]
        [object] $backendAddressPool
        )
    
    $rule= @{}
    $rule.resourceID = $resourceID
    $rule.properties = @{}
    $rule.properties.protocol = $protocol
    $rule.properties.frontEndPort = "$frontendPort"
    $rule.properties.backendPort = "$backendPort"
    
    if ($enableFloatingIP) {
        $rule.properties.enableFloatingIP = "true"
    } else {
        $rule.properties.enableFloatingIP = "false"
    }
    $rule.properties.idleTimeoutInMinutes = "$idleTImeoutInMinutes"
    $rule.properties.loadDistribution = $LoadDistribution

    $rule.properties.frontendIPConfigurations = @()

    foreach ($vip in $frontendipconfigurations) {
        $newvip = @{}
        $newvip.resourceRef = "/loadbalancers/`{0`}/frontendipconfigurations/$($vip.resourceId)"
        $rule.properties.frontendIPConfigurations += $newvip
    }
    $rule.properties.backendAddressPool = @{}
    $rule.properties.backendAddressPool.resourceRef = "/loadbalancers/`{0`}/backendaddresspools/$($backendAddressPool.resourceID)"

    return $rule
}

function New-NCLoadBalancerProbe                      {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object] $LoadBalancer,
        [Parameter(mandatory=$true)]
        [string] $protocol,
        [Parameter(mandatory=$true)]
        [int] $port,
        [Parameter(mandatory=$true)]
        [int] $intervalInSeconds,
        [Parameter(mandatory=$true)]
        [int] $numberOfProbes,
        [Parameter(mandatory=$false)]
        [object[]] $loadBalancingRules = $null
        )
    
    $probe= @{}
    $probe.resourceID = $resourceID
    $probe.properties = @{}
    $probe.properties.protocol = $protocol
    $probe.properties.port = "$port"
    $probe.properties.intervalInSeconds= "$intervalInSeconds"
    $probe.properties.numberOfProbes = "$numberOfProbes"

    #TODO: what to do with loadbalancingrules

    $refpath = "$($loadbalancer.resourceRef)/probes"
    JSONPost  $script:NetworkControllerRestIP $refpath $probe  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "$refpath/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function New-NCLoadBalancerOutboundNatRule            {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$false)]
        [string] $protocol="All",
        [Parameter(mandatory=$true)]
        [object[]] $frontEndIpConfigurations,
        [Parameter(mandatory=$true)]
        [object] $backendAddressPool
        )
    
    $natrule= @{}
    $natrule.resourceID = $resourceID
    $natrule.properties = @{}
    $natrule.properties.protocol = $protocol
    $natrule.properties.frontendIPConfigurations = @()

    foreach ($frontendIP in $frontEndIpConfigurations) {
        $NewFEIP = @{}
        $NewFEIP.resourceRef = "/loadbalancers/`{0`}/frontendipconfigurations/$($frontendIP.resourceId)"
        $natrule.properties.frontendIPConfigurations += $NewFEIP
    }
    
    $natrule.properties.backendAddressPool = @{}
    $natrule.properties.backendAddressPool.resourceRef = "/loadbalancers/`{0`}/backendaddresspools/$($backendAddressPool.resourceID)"

    return $natrule    
}

function New-NCLoadBalancer
{
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [parameter(mandatory=$true)]
        [object[]] $FrontEndIPConfigurations,
        [parameter(mandatory=$true)]
        [object[]] $backendAddressPools,
        [parameter(mandatory=$false)]
        [object[]] $loadBalancingRules = $NULL,
        [parameter(mandatory=$false)]
        [object[]] $probes = $NULL,
        [parameter(mandatory=$false)]
        [object[]] $outboundnatrules= $NULL,
		[Parameter(mandatory=$false)]
        [string] $ComputerName=$script:NetworkControllerRestIP
    )

    $lb = JSONGet $script:NetworkControllerRestIP "/LoadBalancers/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred -Silent:$true
    # Note this handles Add updates ONLY for LOAD Balancing RULES (common case in MAS / PoC)
    if ($null -ne $lb)
    {
        # add the obNat, LB Rule, Inbound Rule
        
        $FrontEndIPConfigurations = @($FrontEndIPConfigurations)
        
        $lbfeIp = $lb.properties.frontendipconfigurations[0]

        if($null -ne $lbfeIp)
        {
            $newFeIP = @(New-NCLoadBalancerFrontEndIPConfiguration -resourceID $lbfeIp.resourceid -PrivateIPAddress $lbfeIp.properties.privateIpaddress -Subnet $lbfeIp.properties.subnet)
            $FrontEndIPConfigurations = $newFeIp
        }

        $lbbepool = $lb.properties.backendaddresspools[0]

        if($null -ne $lbbepool)
        {
            $newBePool = @(New-NCLoadBalancerBackendAddressPool -resourceID $lbbepool.resourceId)
            $backendAddressPools = $newBePool
        }
        
        if ( ($null -ne $lb.properties.OutboundNatRules)  -and ($lb.properties.OutboundNatRules.count -ne 0))
        {
            $obNatRules =$lb.properties.OutboundNatRules[0]

            $newObNatRule = @(New-NCLoadBalancerOutboundNatRule -resourceID $obNatRules.resourceId -protocol $obNatRules.properties.protocol -frontEndIpConfigurations $FrontEndIPConfigurations -backendAddressPool $backendAddressPools)
            $outboundnatrules = $newObNatRule
        }

        $loadBalancingRules = @($loadBalancingRules)
        $newloadBalancingRules = @()       
        
        foreach ($lbrule in $lb.properties.loadBalancingRules)
        {
            $newLbRule = @(New-NCLoadBalancerLoadBalancingRule -resourceId $lbrule.resourceId -protocol $lbrule.properties.protocol -frontendPort $lbrule.properties.frontendPort -backendport $lbrule.properties.backendPort -enableFloatingIP $lbrule.properties.enableFloatingIp -frontEndIPConfigurations $FrontEndIPConfigurations -backendAddressPool $backendAddressPools)
            $newloadBalancingRules += $newLbRule
        }

        $lbRuleCount = $newloadBalancingRules.Count

        #find new unique lb rules
        foreach ($lbrule in $loadBalancingRules)
        {
            $found = $false
            foreach ($oldrule in $lb.properties.loadBalancingRules)
            {
                if(($lbrule.properties.frontendPort -eq $oldrule.properties.frontendPort) -and ($lbrule.properties.backendPort -eq $oldrule.properties.backendPort))
                {
                    $found = $true
                }
            }

            if(-not $found)
            {
                $enableFloat = [Boolean]::Parse("$($lbrule.properties.enableFloatingIp)")
                $newLbRule = @(New-NCLoadBalancerLoadBalancingRule -resourceId $lbrule.resourceId -protocol $lbrule.properties.protocol -frontendPort $lbrule.properties.frontendPort -backendport $lbrule.properties.backendPort -enableFloatingIP $enableFloat -frontEndIPConfigurations $FrontEndIPConfigurations -backendAddressPool $backendAddressPools)
                $newloadBalancingRules += $newLbRule
            }
        }

        if($lbRuleCount -eq $newloadBalancingRules.Count)
        {
            #No change in LB required, skip the update
            return $lb
        }

        $loadBalancingRules = $newloadBalancingRules
    }
    else
    {
        $lb = @{}
        $lb.resourceID = $resourceID
        $lb.properties = @{}
    }

    #Need to populate existing refs with LB resourceID
    if ($loadbalancingrules -ne $null) 
    {
        foreach ($rule in $loadbalancingrules) 
        {
            foreach ($frontend in $rule.properties.frontendipconfigurations) 
            {
                $frontend.resourceRef = ($frontend.resourceRef -f $resourceID)
            }
            $rule.properties.backendaddresspool.resourceRef = ($rule.properties.backendaddresspool.resourceRef -f $resourceID)
        }
        $lb.properties.loadBalancingRules = $loadbalancingrules    
    }

    if ($outboundnatrules -ne $null) 
    {
        foreach ($rule in $outboundnatrules) 
        {
            foreach ($frontend in $rule.properties.frontendipconfigurations) 
            {
                $frontend.resourceRef = ($frontend.resourceRef -f $resourceID)
            }
            $rule.properties.backendaddresspool.resourceRef = ($rule.properties.backendaddresspool.resourceRef -f $resourceID)
        }
        $lb.properties.outboundnatrules = $outboundnatrules    
    }

    foreach ($frontend in $frontendipconfigurations) 
    {
        $frontendref = "/loadbalancers/$resourceID/frontendipconfigurations/$($frontend.resourceId)"
        
        $frontend.properties.loadbalancingrules = @()
        if ($loadbalancingrules -ne $null) 
        {
            foreach ($rule in $loadbalancingrules) 
            {
                foreach ($rulefe in $rule.properties.frontendipconfigurations) 
                {
                    if ($rulefe.resourceRef -eq $frontendref) 
                    {
                        $newref = @{}
                        $newref.resourceRef = "/loadbalancers/$resourceID/loadbalancingrules/$($rule.resourceId)"

                        $frontend.properties.loadbalancingrules += $newref
                    }                   
                }

            }
        }

        $frontend.properties.outboundNatRules = @()
        if ($oubboundNatRules -ne $null) 
        {
            foreach ($rule in $outboundnatrules) 
            {
                foreach ($rulefe in $rule.properties.frontendipconfigurations) 
                {
                    if ($rulefe.resourceRef -eq $frontendref) 
                    {
                        $newref = @{}
                        $newref.resourceRef = "/loadbalancers/$resourceID/outboundnatrules/$($rule.resourceId)"

                        $frontend.properties.outboundNatRules += $newref
                    }                   
                }

            }
        }
    }
    $lb.properties.frontendipconfigurations = $frontendipconfigurations

    foreach ($be in $backendaddresspools) 
    {
        $beref = "/loadbalancers/$resourceID/backendaddresspools/$($be.resourceId)"
        
        $be.properties.loadbalancingrules = @()
        if ($loadbalancingrules -ne $null) 
        {
            foreach ($rule in $loadbalancingrules) 
            {
                if ($rule.properties.backendaddresspool.resourceRef -eq $beref) 
                {
                    $newref = @{}
                    $newref.resourceRef = "/loadbalancers/$resourceID/loadbalancingrules/$($rule.resourceId)"
                    $be.properties.loadbalancingrules += $newref
                }                   

            }
        }
        $be.properties.outboundnatrules = @()
        if ($outboundnatrules -ne $null) 
        {
            foreach ($rule in $outboundnatrules) 
            {
                if ($rule.properties.backendaddresspool.resourceRef -eq $beref) 
                {
                    $newref = @{}
                    $newref.resourceRef = "/loadbalancers/$resourceID/outboundnatrules/$($rule.resourceId)"
                    $be.properties.outboundnatrules += $newref
                }                   

            }
        }
    }
    $lb.properties.backendaddresspools = $backendaddresspools

    # $computerName is here to workaround product limitation for PUT of LoadBalancer, which is > 35KB and must be done from the REST hosting NC Vm.
    JSONPost $script:NetworkControllerRestIP "/LoadBalancers" $lb  -Credential $script:NetworkControllerCred -computerName $ComputerName| out-null
    return JSONGet $script:NetworkControllerRestIP "/LoadBalancers/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCLoadBalancer                           {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/LoadBalancers/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCLoadBalancer                        {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/LoadBalancers/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function New-NCNetworkInterface                       {
    param(
        [Parameter(mandatory=$true,ParameterSetName="ByVirtualNetwork")]
        [Parameter(mandatory=$true,ParameterSetName="ByLogicalNetwork")]
        [Parameter(mandatory=$true,ParameterSetName="ByNoNetwork")]
        [string] $resourceID,
        [Parameter(mandatory=$true,ParameterSetName="ByVirtualNetwork")]
        [object] $VirtualSubnet = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByLogicalNetwork")]
        [object] $Subnet = $null,
        [Parameter(mandatory=$false,ParameterSetName="ByVirtualNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByLogicalNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByNoNetwork")]
        [string] $IPAddress = $null,
        [Parameter(mandatory=$true,ParameterSetName="ByVirtualNetwork")]
        [Parameter(mandatory=$true,ParameterSetName="ByLogicalNetwork")]
        [Parameter(mandatory=$true,ParameterSetName="ByNoNetwork")]
        [string] $MACAddress,
        [Parameter(mandatory=$false,ParameterSetName="ByVirtualNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByLogicalNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByNoNetwork")]
        [string[]] $DNSServers = @(),
        [Parameter(mandatory=$false,ParameterSetName="ByVirtualNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByLogicalNetwork")]
        [Parameter(mandatory=$false,ParameterSetName="ByNoNetwork")]
        [object] $acl=$null
    )

    if ($pscmdlet.ParameterSetName -eq 'ByVirtualNetwork') {
        $subnet = $virtualsubnet        
    }

    $interface = @{}
    # resource Id
    $interface.resourceID = $resourceID
    $interface.properties = @{}    

    # Mac Address
    $interface.properties.privateMacAddress = $macaddress
    $interface.properties.privateMacAllocationMethod = "Static"

    # IPConfigurations
    if ($Subnet -ne $null -or ![string]::IsNullOrEmpty($IPAddress) -or $acl -ne $null)
    {
        $interface.properties.ipConfigurations = @()

        $ipconfig = @{}
        $ipconfig.resourceId = [System.Guid]::NewGuid().toString()
        $ipconfig.properties = @{}

        if ($Subnet -ne $null)
        {
            $ipconfig.properties.subnet = @{}
            $ipconfig.properties.subnet.resourceRef = $Subnet.resourceRef
        }
        if (![string]::IsNullOrEmpty($IPAddress))
        {
            $ipconfig.properties.privateIPAddress = $IPAddress
            $ipconfig.properties.privateIPAllocationMethod = "Static"
        }
        if ($acl -ne $null) {
            $ipconfig.properties.accessControlList = @{}
            $ipconfig.properties.accessControlList.resourceRef = $acl.resourceRef
        }

        $interface.properties.ipConfigurations += $ipconfig
    }

    # DNS Servers
    if ($DNSServers -ne $null -and $DNSServers.count -gt 0)
    {
        $interface.properties.dnsSettings = @{}
        $interface.properties.dnsSettings.dnsServers = $DNSServers
    }

    JSONPost $script:NetworkControllerRestIP "/NetworkInterfaces" $interface  -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/NetworkInterfaces/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCNetworkInterface                       {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/NetworkInterfaces/$resourceID"  -Credential $script:NetworkControllerCred
}
function Remove-NCNetworkInterface                    {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/NetworkInterfaces/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

function Get-ServerResourceId                         {
   param (
        [Parameter(mandatory=$false)]
        [string] $ComputerName="localhost",
        [Parameter(mandatory=$false)]
        [Object] $Credential=$script:NetworkControllerCred
        )

    $resourceId = ""

    write-verbose ("Retrieving server resource id on [$ComputerName]")

    try 
    {
        $pssession = new-pssession -ComputerName $ComputerName -Credential $Credential

        $resourceId = invoke-command -session $pssession -ScriptBlock {
            $VerbosePreference = 'Continue'
            write-verbose "Retrieving first VMSwitch on [$using:ComputerName]"

            $switches = Get-VMSwitch -ErrorAction Ignore
            if ($switches.Count -eq 0)
            {
                throw "No VMSwitch was found on [$using:ComputerName]"
            }

            return $switches[0].Id
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

    write-verbose "Server resource id is [$resourceId] on [$ComputerName]"
    return $resourceId
}

function Set-PortProfileId                            {
   param (
        [Parameter(mandatory=$true)]
        [string] $resourceID,
        [Parameter(mandatory=$true)]
        [string] $VMName,
        [Parameter(mandatory=$false)]
        [string] $VMNetworkAdapterName,
        [Parameter(mandatory=$false)]
        [string] $ComputerName="localhost",
        [Parameter(mandatory=$false)]
        [Object] $credential=$script:NetworkControllerCred,
        [Parameter(mandatory=$false)]
        [int] $ProfileData = 1,
        [Switch] $force
        )

    #do not change these values
    write-verbose ("Setting port profile for [$vmname] on [$computername]" )
            
    try 
    {
        $pssession = new-pssession -ComputerName $computername -Credential $credential
        $isforce = $force.ispresent

        invoke-command -session $pssession -ScriptBlock {
            $VerbosePreference = 'Continue'
            write-verbose ("Running port profile set script block on host" )

            $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
            $NcVendorId  = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"

            $portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId
            
            $portProfileDefaultSetting.SettingData.ProfileId = "{$using:resourceId}"
            $portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{56785678-a0e5-4a26-bc9b-c0cba27311a3}"
            $portProfileDefaultSetting.SettingData.CdnLabelString = "TestCdn"
            $portProfileDefaultSetting.SettingData.CdnLabelId = 1111
            $portProfileDefaultSetting.SettingData.ProfileName = "Testprofile"
            $portProfileDefaultSetting.SettingData.VendorId = $NcVendorId 
            $portProfileDefaultSetting.SettingData.VendorName = "NetworkController"
            $portProfileDefaultSetting.SettingData.ProfileData = $using:ProfileData
            #$portprofiledefaultsetting.settingdata
            
            write-verbose ("Retrieving VM network adapter $using:VMNetworkAdapterName" )
            if ([String]::IsNullOrEmpty($using:VMNetworkAdapterName))
            {
                write-verbose ("Retrieving all VM network adapters for VM $using:VMName") 
                $vmNics = Get-VMNetworkAdapter -VMName $using:VMName 
            }
            else
            { 
                write-verbose ("Retrieving VM network adapter $using:VMNetworkAdapterName for VM $using:VMName" )
                $vmNics = @(Get-VMNetworkAdapter -VMName $using:VMName -Name $using:VMNetworkAdapterName) 
            }

            foreach ($vmNic in $vmNics) {
                write-verbose ("Setting port profile on vm network adapter $($vmNic.Name)" )
                $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMNetworkAdapter $vmNic
    
                if ( $currentProfile -eq $null)
                {
                    write-verbose ("Adding port feature for [{0}] to [{1}]" -f $using:VMName, "{$using:resourceId}") 
                    Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $vmNic | out-null
                    write-verbose "Adding port feature complete"

                }        
                else
                {
                    if ($using:isforce) {
                        write-verbose ("Setting port feature for [{0}] to [{1}]" -f $using:VMName, "{$using:resourceId}") 
        
                        $currentProfile.SettingData.ProfileId = "{$using:resourceId}"
                        $currentProfile.SettingData.ProfileData = $using:ProfileData
                        Set-VMSwitchExtensionPortFeature  -VMSwitchExtensionFeature $currentProfile  -VMNetworkAdapter $vmNic | out-null
                    } else {
                        write-verbose ("Port profile already set for [{0}] use -Force to override." -f $using:VMName) 
                    }
                }
            }
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

function Remove-PortProfileId
{
   param (
        [Parameter(mandatory=$true)]
        [string] $VMName,
        [Parameter(mandatory=$false)]
        [string] $VMNetworkAdapterName="Network Adapter",
        [Parameter(mandatory=$false)]
        [string] $ComputerName="localhost"
        )

    write-verbose ("Removing port profile for Network Adapter [$VMNetworkAdapterName] on VM [$vmname] on [$computername]" )
            
    try 
    {
        $pssession = new-pssession -ComputerName $computername

        invoke-command -session $pssession -ScriptBlock {
            param($VMName, $VMNetworkAdapterName)
            $VerbosePreference = 'Continue'
            write-verbose ("Running port profile remove script block on host" )

            #do not change these values
            $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
            $NcVendorId  = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"

            $portProfileCurrentSetting = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMName $VMName -VMNetworkAdapterName $VMNetworkAdapterName            
            
            write-verbose ("Removing port profile from vm network adapter $VMNetworkAdapterName" )
            Remove-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature $portProfileCurrentSetting -VMName $VMName -VMNetworkAdapterName $VMNetworkAdapterName -Confirm:$false
        } -ArgumentList @($VMName, $VMNetworkAdapterName)
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

function New-NCSwitchPort                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid()
    )

    $server = @{}
    $server.resourceId = $ResourceID
    $server.instanceId = $ResourceID
    $server.properties = @{}
    
    if ($managed.ispresent)  {
        $server.properties.managementState = "Managed"
    } else
    {
        $server.properties.managementState = "unManaged"
    }
    $server.properties.roleType = "multiLayerSwitch"
    $server.properties.switchType = $switchtype

    $server.properties.connections = $Connections

    JSONPost  $script:NetworkControllerRestIP "/Switches" $server  -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/Switches/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred

}

function New-NCSwitch                         {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [object[]] $Connections,
        [Parameter(mandatory=$true)]
        [string] $switchType,
        [Switch] $Managed
    )

    $server = @{}
    $server.resourceId = $ResourceID
    $server.instanceId = $ResourceID
    $server.properties = @{}
    
    if ($managed.ispresent)  {
        $server.properties.managementState = "Managed"
    } else
    {
        $server.properties.managementState = "Unmanaged"
    }
    $server.properties.roleType = "multiLayerSwitch"
    $server.properties.switchType = $switchtype
    $server.properties.switchPorts = @()
    
    $newport = @{}
    $newport.ResourceRef = "Port1"
    $newport.properties = @{}
    $server.properties.switchPorts += $newport

    $newport = @{}
    $newport.ResourceRef = "Port2"
    $newport.properties = @{}
    $server.properties.switchPorts += $newport

    $server.properties.connections = $Connections

    JSONPost  $script:NetworkControllerRestIP "/Switches" $server   -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/Switches/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred

}

function Get-NCSwitch                          {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/Switches/$resourceID"  -Credential $script:NetworkControllerCred
}

function Remove-NCSwitch                       {
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
	JSONDelete  $script:NetworkControllerRestIP "/Switches/$ResourceId" -Waitforupdate  -Credential $script:NetworkControllerCred| out-null
     }
}

#
#  iDNS Specific Wrappers 
#
function Add-iDnsConfiguration
{
    param(
        [Parameter(mandatory=$true)]
        [object[]] $connections,
        [Parameter(mandatory=$true)]
        [string] $zoneName
    )

    $iDnsObj = @{}
    # resource Id configuration is fixed
    $iDnsObj.resourceID = "configuration"
    $iDnsObj.properties = @{}

    $iDnsObj.properties.connections=$connections
    $iDnsObj.properties.zone=$zoneName


    JSONPost $script:NetworkControllerRestIP "/iDnsServer" $iDnsObj -Credential $script:NetworkControllerCred| out-null
    return JSONGet $script:NetworkControllerRestIP "/iDnsServer/Configuration" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-iDnsConfiguration
{
    return JSONGet $script:NetworkControllerRestIP "/iDnsServer/configuration"  -Credential $script:NetworkControllerCred
}


#
#  Gateway Specific Wrappers 
#

function New-NCPublicIPAddress
{
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID=[system.guid]::NewGuid(),
        [Parameter(mandatory=$true)]
        [string] $PublicIPAddress)

    $publicIP = @{}
    $publicIP.resourceId = $ResourceID
    $publicIP.properties = @{}
    $publicIP.properties.ipAddress = $PublicIPAddress
    $publicIP.properties.publicIPAllocationMethod = "Static"

    JSONPost  $script:NetworkControllerRestIP "/publicIPAddresses" $publicIP  -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/publicIPAddresses/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCPublicIPAddress
{
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/publicIPAddresses/$resourceID" -Credential $script:NetworkControllerCred
}

function Remove-NCPublicIPAddress
{
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
     )
     foreach ($resourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/publicIPAddresses/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
     }
}

function New-NCGatewayPool
{
    param(
        [Parameter(mandatory=$true)]
        [string] $resourceID,
        [Parameter(mandatory=$true)]
        [string] $Type,
        [Parameter(mandatory=$false)]
        [string] $GreVipSubnetResourceRef,
        [Parameter(mandatory=$false)]
        [string] $PublicIPAddressId,
        [Parameter(mandatory=$false)]
        [System.UInt64] $Capacity = 10000000,
        [Parameter(mandatory=$false)]
        [System.UInt32] $RedundantGatewayCount = 0
    )

    $gwPool = @{}
    $gwPool.resourceID = $resourceID
        
    $gwPool.properties = @{}
    $gwPool.properties.type = $Type
    $gwPool.properties.ipConfiguration = @{}

    if (-not([String]::IsNullOrEmpty($GreVipSubnetResourceRef)))
    {
        $gwPool.properties.ipConfiguration.greVipSubnets = @()
        $greVipSubnet = @{}
        $greVipSubnet.resourceRef = $GreVipSubnetResourceRef
        $gwPool.properties.ipConfiguration.greVipSubnets += $greVipSubnet
    }

    $publicIPAddresses = @{}
    if (-not([String]::IsNullOrEmpty($PublicIPAddressId)))
    {
        $publicIPAddresses.resourceRef = "/publicIPAddresses/$PublicIPAddressId"
        $gwPool.properties.ipConfiguration.publicIPAddresses = @()
        $gwPool.properties.ipConfiguration.publicIPAddresses += $publicIPAddresses
    }
    $gwPool.properties.redundantGatewayCount = $RedundantGatewayCount
    $gwPool.properties.gatewayCapacityKiloBitsPerSecond = $Capacity
    
    JSONPost $script:NetworkControllerRestIP "/GatewayPools" $gwPool -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/GatewayPools/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCGatewayPool
{
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/GatewayPools/$ResourceID" -Credential $script:NetworkControllerCred
}

function Remove-NCGatewayPool
{
    param(
        [Parameter(mandatory=$true)]
        [string[]] $ResourceIDs
    )
    foreach ($ResourceId in $ResourceIDs) {
        JSONDelete  $script:NetworkControllerRestIP "/GatewayPools/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
    }
}


function New-NCGateway
{
    param(
        [Parameter(mandatory=$true)]
        [string] $resourceID,
        [Parameter(mandatory=$true)]
        [string] $GatewayPoolRef,
        [Parameter(mandatory=$true)]
        [string] $Type,
        [Parameter(mandatory=$false)]
        [object] $BgpConfig,
        [Parameter(mandatory=$true)]
        [string] $VirtualServerRef,
        [Parameter(mandatory=$true)]
        [string] $InternalInterfaceRef,
        [Parameter(mandatory=$true)]
        [string] $ExternalInterfaceRef
    )

    $gateway = @{}
    $gateway.resourceID = $resourceID
    $gateway.properties = @{}

    $gateway.properties.pool = @{}
    $gateway.properties.pool.resourceRef = $GatewayPoolRef

    $gateway.properties.type = $Type
    $gateway.properties.bgpConfig = @{}
    $gateway.properties.bgpConfig = $BgpConfig

    $gateway.properties.virtualserver = @{}
    $gateway.properties.virtualserver.resourceRef = $VirtualServerRef

    $gateway.properties.networkInterfaces = @{}
    $gateway.properties.networkInterfaces.externalNetworkInterface = @{}
    $gateway.properties.networkInterfaces.externalNetworkInterface.resourceRef = $ExternalInterfaceRef
    $gateway.properties.networkInterfaces.internalNetworkInterface = @{}
    $gateway.properties.networkInterfaces.internalNetworkInterface.resourceRef = $InternalInterfaceRef

    JSONPost $script:NetworkControllerRestIP "/Gateways" $gateway -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/Gateways/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}

function Get-NCGateway
{
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/Gateways/$resourceID" -Credential $script:NetworkControllerCred
}

function Remove-NCGateway
{
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceID
    )
    JSONDelete  $script:NetworkControllerRestIP "/Gateways/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
}

function New-NCVpnClientAddressSpace
{
    param(
        [Parameter(mandatory=$true)]
        [string] $TenantName,
        [Parameter(mandatory=$true)]
        [System.UInt64] $VpnCapacity,
        [Parameter(mandatory=$true)]
        [string] $Ipv4AddressPool,
        [Parameter(mandatory=$true)]
        [string] $Ipv6AddressPool
    )

    $vpnClientAddressSpace = @{}
    $vpnClientAddressSpace.AddressPrefixes = @()
    $vpnClientAddressSpace.AddressPrefixes += @($Ipv4AddressPool, $Ipv6AddressPool)
    $vpnClientAddressSpace.Capacity = $VpnCapacity.ToString()
    $vpnClientAddressSpace.Realm = $TenantName

    return $vpnClientAddressSpace
}

function New-NCIPSecTunnel
{
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceId,
        [Parameter(mandatory=$true)]
        [system.uint64] $OutboundCapacity,
        [Parameter(mandatory=$true)]
        [system.uint64] $InboundCapacity,
        [Parameter(mandatory=$false)]
        [object[]] $IPAddresses,
        [Parameter(mandatory=$false)]
        [string[]] $PeerIPAddresses,
        [Parameter(mandatory=$false)]
        [string] $DestinationIPAddress,
        [Parameter(mandatory=$false)]
        [string] $SharedSecret,
        [Parameter(mandatory=$false)]
        [object[]] $IPv4Subnets
    )

    $AuthenticationMethod = "PSK"

    $ipSecVpn = @{}
    $ipsecVpn.resourceId = $ResourceId
    $ipSecVpn.properties = @{}
    
    $ipSecVpn.properties.connectionType = "IPSec"
    $ipSecVpn.properties.outboundKiloBitsPerSecond = $outboundCapacity
    $ipSecVpn.properties.inboundKiloBitsPerSecond = $inboundCapacity
    
    $routes = @()
    foreach ($IPv4Subnet in $IPv4Subnets)
    {
        $route = @{}
        $route.destinationPrefix = $IPv4Subnet.Prefix
        $route.metric = $IPv4Subnet.Metric
        $routes += $route
    }
    $ipSecVpn.properties.routes = @()
    $ipSecVpn.properties.routes = $routes

    $ipSecVpn.properties.ipSecConfiguration = @{}
    $ipSecVpn.properties.ipSecConfiguration.QuickMode = @{}
    $ipSecVpn.properties.ipSecConfiguration.MainMode = @{}

    $ipSecVpn.properties.ipSecConfiguration.authenticationMethod = $AuthenticationMethod
    if ($AuthenticationMethod -eq "PSK")
    { $ipSecVpn.properties.ipSecConfiguration.sharedSecret = $SharedSecret }

    $ipSecVpn.properties.ipSecConfiguration.quickMode.perfectForwardSecrecy                = "PFS2048"
    $ipSecVpn.properties.ipSecConfiguration.quickMode.authenticationTransformationConstant = "SHA256128"
    $ipSecVpn.properties.ipSecConfiguration.quickMode.cipherTransformationConstant         = "DES3"
    $ipSecVpn.properties.ipSecConfiguration.quickMode.saLifeTimeSeconds                    = 1233
    $ipSecVpn.properties.ipSecConfiguration.quickMode.idleDisconnectSeconds                = 500
    $ipSecVpn.properties.ipSecConfiguration.quickMode.saLifeTimeKiloBytes                  = 2000

    $ipSecVpn.properties.ipSecConfiguration.mainMode.diffieHellmanGroup  = "Group2"
    $ipSecVpn.properties.ipSecConfiguration.mainMode.integrityAlgorithm  = "SHA256"
    $ipSecVpn.properties.ipSecConfiguration.mainMode.encryptionAlgorithm = "AES256"
    $ipSecVpn.properties.ipSecConfiguration.mainMode.saLifeTimeSeconds   = 1234
    $ipSecVpn.properties.ipSecConfiguration.mainMode.saLifeTimeKiloBytes = 2000

    if ($IPAddresses -eq $null) {$IPAddresses = @()}
    if ($PeerIPAddresses -eq $null) {$PeerIPAddresses = @()}

    $ipSecVpn.properties.ipAddresses = $IPAddresses
    $ipSecVpn.properties.peerIPAddresses = $PeerIPAddresses
    $ipSecVpn.properties.destinationIPAddress = $DestinationIPAddress

    return $ipSecVpn
}

function New-NCGreTunnel
{
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceId,
        [Parameter(mandatory=$true)]
        [system.uint64] $OutboundCapacity,
        [Parameter(mandatory=$true)]
        [system.uint64] $InboundCapacity,
        [Parameter(mandatory=$false)]
        [object[]] $IPAddresses,
        [Parameter(mandatory=$false)]
        [string[]] $PeerIPAddresses,
        [Parameter(mandatory=$false)]
        [string] $DestinationIPAddress,
        [Parameter(mandatory=$false)]
        [object[]] $IPv4Subnets,
        [Parameter(mandatory=$false)]
        [string] $GreKey
    )

    $greTunnel = @{}
    $greTunnel.resourceId = $ResourceId
    $greTunnel.properties = @{}
    
    $greTunnel.properties.connectionType = "GRE"
    $greTunnel.properties.outboundKiloBitsPerSecond = $outboundCapacity
    $greTunnel.properties.inboundKiloBitsPerSecond = $inboundCapacity
    
    $greTunnel.properties.greConfiguration = @{}
    $greTunnel.properties.greConfiguration.GreKey = $GreKey
    
    if ($IPAddresses -eq $null) {$IPAddresses = @()}
    if ($PeerIPAddresses -eq $null) {$PeerIPAddresses = @()}

    $greTunnel.properties.ipAddresses = $IPAddresses
    $greTunnel.properties.peerIPAddresses = $PeerIPAddresses

    $routes = @()
    foreach ($IPv4Subnet in $IPv4Subnets)
    {
        $route = @{}
        $route.destinationPrefix = $IPv4Subnet.Prefix
        $route.metric = $IPv4Subnet.Metric
        $routes += $route
    }
    $greTunnel.properties.routes = @()
    $greTunnel.properties.routes = $routes

    $greTunnel.properties.destinationIPAddress = $DestinationIPAddress

    return $greTunnel
}

function New-NCL3Tunnel
{
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceId,
        [Parameter(mandatory=$true)]
        [system.uint64] $OutboundCapacity,
        [Parameter(mandatory=$true)]
        [system.uint64] $InboundCapacity,
        [Parameter(mandatory=$false)]
        [string] $VlanSubnetResourceRef,
        [Parameter(mandatory=$false)]
        [object[]] $L3IPAddresses,
        [Parameter(mandatory=$false)]
        [System.UInt16] $PrefixLength,
        [Parameter(mandatory=$false)]
        [string[]] $L3PeerIPAddresses,
        [Parameter(mandatory=$false)]
        [object[]] $IPv4Subnets
    )

    $l3Tunnel = @{}
    $l3Tunnel.resourceId = $ResourceId
    $l3Tunnel.properties = @{}
    
    $l3Tunnel.properties.connectionType = "L3"
    $l3Tunnel.properties.outboundKiloBitsPerSecond = $outboundCapacity
    $l3Tunnel.properties.inboundKiloBitsPerSecond = $inboundCapacity
    
    $l3Tunnel.properties.l3Configuration = @{}
    $l3Tunnel.properties.l3Configuration.vlanSubnet = @{}
    $l3Tunnel.properties.l3Configuration.vlanSubnet.resourceRef = $VlanSubnetResourceRef
    
    $l3Tunnel.properties.ipAddresses = @($L3IPAddresses)
    $l3Tunnel.properties.peerIPAddresses = @($L3PeerIPAddresses)

    $routes = @()
    foreach ($IPv4Subnet in $IPv4Subnets)
    {
        $route = @{}
        $route.destinationPrefix = $IPv4Subnet.Prefix
        $route.metric = $IPv4Subnet.Metric
        $routes += $route
    }
    $l3Tunnel.properties.routes = @()
    $l3Tunnel.properties.routes = $routes
    
    return $l3Tunnel
}

function New-NCBgpRoutingPolicy
{
    param(
        [Parameter(mandatory=$true)]
        [string] $PolicyName,
        [Parameter(mandatory=$true)]
        [string] $PolicyType,
        [Parameter(mandatory=$true)]
        [object[]] $MatchCriteriaList,
        [Parameter(mandatory=$false)]
        [object[]] $Actions,
        [Parameter(mandatory=$false)]
        [string] $EgressPolicyMapResourceRef
    )

    $bgpPolicy = @{}
    $bgpPolicy.policyName = $PolicyName
    $bgpPolicy.policyType = $policyType

    $bgpPolicy.matchCriteria = @()
    $bgpPolicy.setActions = @()

    foreach ($criteria in $MatchCriteriaList)
    {
        $matchCriteria = @{}
        $matchCriteria.clause = $criteria.clause
        $matchCriteria.operator = "And"
        $matchCriteria.value = $criteria.value

        $bgpPolicy.matchCriteria += $matchCriteria
    }
    
    $bgpPolicy.setActions += @($Actions)
    
    return $bgpPolicy
}

function New-NCBgpRoutingPolicyMap
{
    param(
        [Parameter(mandatory=$true)]
        [string] $PolicyMapName,
        [Parameter(mandatory=$true)]
        [object[]] $PolicyList
    )

    $bgpPolicyMap = @{}
    $bgpPolicyMap.resourceId = $PolicyMapName
    $bgpPolicyMap.properties = @{}

    $bgpPolicyMap.properties.policyList = @($PolicyList)
    
    return $bgpPolicyMap
}

function New-NCBgpPeer
{
    param(
        [Parameter(mandatory=$true)]
        [string] $PeerName,
        [Parameter(mandatory=$true)]
        [string] $PeerIP,
        [Parameter(mandatory=$true)]
        [string] $PeerASN,
        [Parameter(mandatory=$false)]
        [string] $IngressPolicyMapResourceRef,
        [Parameter(mandatory=$false)]
        [string] $EgressPolicyMapResourceRef
    )

    $bgpPeer = @{}
    $bgpPeer.resourceId = $PeerName
    $bgpPeer.properties = @{}

    $bgpPeer.properties.peerIPAddress = $PeerIP
    $bgpPeer.properties.peerAsNumber = $PeerASN
    $bgpPeer.properties.ExtAsNumber = "0.$PeerASN"

    $bgpPeer.properties.policyMapIn  = $null
    $bgpPeer.properties.policyMapOut = $null

    if (![string]::IsNullOrEmpty($IngressPolicyMapResourceRef))
    { 
        $bgpPeer.properties.policyMapIn  = @{}
        $bgpPeer.properties.policyMapIn.resourceRef = $IngressPolicyMapResourceRef 
    }    
    if (![string]::IsNullOrEmpty($EgressPolicyMapResourceRef))
    {
        $bgpPeer.properties.policyMapOut = @{}
        $bgpPeer.properties.policyMapOut.resourceRef = $EgressPolicyMapResourceRef 
    }

    return $bgpPeer
}

function New-NCBgpRouter
{
    param(
        [Parameter(mandatory=$true)]
        [string] $RouterName,
        [Parameter(mandatory=$true)]
        [string] $LocalASN,
        [Parameter(mandatory=$false)]
        [object[]] $BgpPeers
    )

    $bgpRouter = @{}
    $bgpRouter.resourceId = $RouterName
    $bgpRouter.properties = @{}

    $bgpRouter.properties.isEnabled = "true"
    $bgpRouter.properties.requireIGPSync = "true"
    $bgpRouter.properties.extAsNumber = "0.$LocalASN"
    $bgpRouter.properties.routerIP = @()
    $bgpRouter.properties.bgpNetworks = @()
    $bgpRouter.properties.isGenerated = $false

    $bgpRouter.properties.bgpPeers = @($BgpPeers)

    return $bgpRouter
}

function New-NCVirtualGateway
{
    param(
        [Parameter(mandatory=$true)]
        [string] $resourceID,
        [Parameter(mandatory=$true)]
        [string[]] $GatewayPools,
        [Parameter(mandatory=$true)]
        [string] $vNetIPv4SubnetResourceRef,
        [Parameter(mandatory=$false)]
        [object] $VpnClientAddressSpace,
        [Parameter(mandatory=$false)]
        [object[]] $NetworkConnections,
        [Parameter(mandatory=$false)]
        [object[]] $BgpRouters,
        [Parameter(mandatory=$false)]
        [object[]] $PolicyMaps,
        [Parameter(mandatory=$false)]
        [string] $RoutingType = "Dynamic"
    )

    $virtualGW = @{}
    $virtualGW.resourceID = $resourceID
    $virtualGW.properties = @{}

    $virtualGW.properties.gatewayPools = @()
    foreach ($gatewayPool in $GatewayPools)
    {
    	
    	$gwPool = @{}
    	$gwPool.resourceRef = "/gatewayPools/$gatewayPool"
    	$virtualGW.properties.gatewayPools += $gwPool
    }
    
    $gatewaySubnetsRef = @{}
    $gatewaySubnetsRef.resourceRef = $vNetIPv4SubnetResourceRef
    $virtualGW.properties.gatewaySubnets = @()    
    $virtualGW.properties.gatewaySubnets += $gatewaySubnetsRef
    
    $virtualGW.properties.vpnClientAddressSpace = @{}
    $virtualGW.properties.vpnClientAddressSpace = $VpnClientAddressSpace

    $virtualGW.properties.networkConnections = @()
    $virtualGW.properties.networkConnections += @($Networkconnections)
    
    $virtualGW.properties.bgpRouters = @()
    $virtualGW.properties.bgpRouters += $BgpRouters
    
    $virtualGW.properties.policyMaps = @()
    $virtualGW.properties.policyMaps += $PolicyMaps

    $virtualGW.properties.routingType = $RoutingType

    JSONPost $script:NetworkControllerRestIP "/VirtualGateways" $virtualGW -Credential $script:NetworkControllerCred | out-null
    return JSONGet $script:NetworkControllerRestIP "/VirtualGateways/$resourceID" -WaitForUpdate -Credential $script:NetworkControllerCred
}
function Get-NCVirtualGateway
{
    param(
        [Parameter(mandatory=$false)]
        [string] $ResourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/VirtualGateways/$ResourceID" -Credential $script:NetworkControllerCred
}
function Remove-NCVirtualGateway
{
    param(
        [Parameter(mandatory=$true)]
        [string] $ResourceID
     )
     JSONDelete  $script:NetworkControllerRestIP "/VirtualGateways/$ResourceId" -Waitforupdate -Credential $script:NetworkControllerCred | out-null
}

function Add-LoadBalancerToNetworkAdapter
{
    param(
        [parameter(mandatory=$false)]
        [string] $LoadBalancerResourceID,
        [parameter(mandatory=$false)]
        [string[]] $VMNicResourceIds
    )
    $loadBalancer = Get-NCLoadBalancer -resourceId $LoadBalancerResourceID
    $lbbeResourceRef = $loadBalancer.Properties.backendAddressPools.resourceRef
    foreach($nicResourceID in $VMNicResourceIds)
    {
        $nicResource = Get-NCNetworkInterface -resourceid $nicResourceID
        $loadBalancerBackendAddressPools = @{}
        $loadBalancerBackendAddressPools.resourceRef = $lbbeResourceRef    
        if(-not $nicResource.properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools)
        {     
            $nicResource.properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools= @()
        }
        else
        {
            $found = $false
            foreach ($backendAddressPool in $nicResource.properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools)
            {
                $resourceRef = $backendAddressPool.resourceRef
                if ($resourceRef -eq $lbbeResourceRef)
                {
                    $found = $true
                    break
                }
            }

            if ($found -eq $true)
            {
                continue
            }
        }
        $nicResource.properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools += $loadBalancerBackendAddressPools      
        JSONPost $script:NetworkControllerRestIP "/NetworkInterfaces" $nicResource -Credential $script:NetworkControllerCred | out-null
    }
} 


function Remove-LoadBalancerFromNetworkAdapter
{
    param(
        [parameter(mandatory=$false)]
        [string[]] $VMNicResourceIds
    )
    foreach($nicResourceID in $VMNicResourceIds)
    {
        $nicResource = Get-NCNetworkInterface -resourceid $nicResourceID
        $nicResource.properties.ipConfigurations[0].loadBalancerBackendAddressPools.resourceRef = ""       
        JSONPost $script:NetworkControllerRestIP "/NetworkInterfaces" $nicResource -Credential $script:NetworkControllerCred | out-null
    }
}

function Get-NCConnectivityCheckResult                      {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/diagnostics/ConnectivityCheckResults/$resourceID"  -Credential $script:NetworkControllerCred
}
function Get-NCRouteTable                       {
    param(
        [Parameter(mandatory=$false)]
        [string] $resourceID = ""
    )
    return JSONGet $script:NetworkControllerRestIP "/RouteTables/$resourceID"  -Credential $script:NetworkControllerCred
}

