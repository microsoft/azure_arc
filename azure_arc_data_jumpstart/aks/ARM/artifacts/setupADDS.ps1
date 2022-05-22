##############################################################
# This script will install ADDS window feature and promote windows server
# as a domain controller and restarts to finish AD setup
##############################################################
# Configure the Domain Controller
param (
    [string]$domainName,
    [string]$domainAdminUsername,
    [string]$domainAdminPassword
)

# Convert plain text password to secure string
$secureDomainAdminPassword = $domainAdminPassword | ConvertTo-SecureString -AsPlainText -Force

# Enable ADDS windows feature to setup domain forest
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Finished enabling ADDS windows feature."

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

Write-Host "ADDS Deployment successful. Now rebooting computer to finsih setup."

# Reboot computer
Restart-Computer
Write-Host "System reboot requested."

# Setup reverse lookup zone
#Add-DnsServerPrimaryZone -NetworkId "172.16.1.0/24" -ReplicationScope Domain -DomainNetbiosName "contoso" -
