# Configure the Domain Controller
param (
    [string]$domainName,
    [string]$domainAdminUsername,
    [string]$domainAdminPassword
)

$secureDomainAdminPassword = $domainAdminPassword | ConvertTo-SecureString -AsPlainText -Force

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Create Active Directory Forest
Install-ADDSForest `
    -DomainName "$domainName" `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -DomainNetbiosName $domainName.Split('.')[0].ToUpper() `
    -ForestMode "7" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$True `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $secureDomainAdminPassword

Write-Host "ADDS Deployment successful. No rebooting computer."

# Reboot computer
Restart-Computer
Write-Host "System reboot requested."

# Setup reverse lookup zone
#Add-DnsServerPrimaryZone -NetworkId "172.16.1.0/24" -ReplicationScope Domain -DomainNetbiosName "contoso" -
