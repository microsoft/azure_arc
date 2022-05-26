
##############################################
# This script will be executed after ADDS domain setup and restarted
# to continue configure reverse DNS lookup to support SQLMI AD authentication
##############################################
Import-Module ActiveDirectory
Import-Module DnsServer

Start-Transcript -Path "C:\Temp\SetupReverseDNS.log"

# Get Activectory Information
$dcInfo = Get-ADDomainController
$dcIPv4 = ([System.Net.IPAddress]$dcInfo.IPv4Address).GetAddressBytes()
$reverseLookupCidr = [System.String]::Concat($dcIPv4[0], '.', $dcIPv4[1], '.', $dcIPv4[2], '.0/24')
#$netbiosname = $domainName.Split('.')[0].ToUpper()

# Setup reverse lookup zone
try {
    Add-DnsServerPrimaryZone -NetworkId $reverseLookupCidr -ReplicationScope "Forest" -ComputerName $dcInfo.HostName
    Write-Host "Successfully created reverse DNS Zone."

    $ReverseDnsZone = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true}
}
catch {
    # Reverse DNS already setup
    $ReverseDnsZone = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true}
    Write-Host "Reverse DNS Zone ${ReverseDnsZone.Name} already exists for this domain controller."
}

# Create reverse DNS for domain controller
try {
    Add-DNSServerResourceRecordPTR -ZoneName $ReverseDnsZone -Name 4 -PTRDomainName $dcInfo.HostName
    Write-Host "Created PTR record for domain controller."
}
catch {
    Write-Host "PTR record already exists for domain controller."
}

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterADDSRestart

# schedule task to run after reboot to create reverse DNS lookup
#$Trigger = New-ScheduledTaskTrigger -AtStartup
#$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\RunAfterADDSRestart.ps1'
#Register-ScheduledTask -TaskName "RunAfterADDSRestart" -Trigger $Trigger -User "$netbiosname\$Env:domainAdminUsername" -Password "$Env:domainAdminPassword" -Action $Action -RunLevel "Highest" -Force

Stop-Transcript