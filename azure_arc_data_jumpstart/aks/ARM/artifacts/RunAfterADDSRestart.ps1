
##############################################
# This script will be executed after ADDS domain setup and restarted
# to continue configure reverse DNS lookup to support SQLMI AD authentication
##############################################
Import-Module ActiveDirectory
Import-Module DnsServer

# Wait for the system to fully reboot before creating reverse lookup zone
Start-Sleep -Seconds 30

Start-Transcript -Path "C:\Temp\SetupReverseDNS.log"

# Get Activectory Information
$netbiosname = $Env:domainName.Split('.')[0].ToUpper()

$adminuser = "$netbiosname\$Env:domainAdminUsername"
$secpass = $Env:domainAdminPassword | ConvertTo-SecureString -AsPlainText -Force
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser, $secpass
$dcName = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName

$dcInfo = Get-ADDomainController -Server $dcName -Credential $adminCredential

# Print domain information
$dcInfo

$dcIPv4 = ([System.Net.IPAddress]$dcInfo.IPv4Address).GetAddressBytes()
$reverseLookupCidr = [System.String]::Concat($dcIPv4[0], '.', $dcIPv4[1], '.', $dcIPv4[2], '.0/24')
Write-Host "Reverse lookup zone CIDR $reverseLookupCidr"

# Create login session with domain credentials
$cimsession = New-CimSession -Credential $adminCredential

# Setup reverse lookup zone
try {
    Add-DnsServerPrimaryZone -NetworkId $reverseLookupCidr -ReplicationScope Domain -CimSession $cimsession
    Write-Host "Successfully created reverse DNS Zone."

    $ReverseDnsZone = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true}
}
catch {
    # Reverse DNS already setup
    $ReverseDnsZone = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true}
    Write-Host "Reverse DNS Zone ${ReverseDnsZone.Name} already exists for this domain controller."
}

# Create reverse DNS for domain controller
if ($null -ne $ReverseDnsZone)
{
    Add-DNSServerResourceRecordPTR -ZoneName $ReverseDnsZone.ZoneName -Name $dcIPv4[3] -PTRDomainName $dcInfo.HostName -CimSession $cimsession
    Write-Host "Created PTR record for domain controller."
}
else {
    Write-Host "Failed to create reverse DNS lookup zone or zone does not exist."
}

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterADDSRestart

Stop-Transcript