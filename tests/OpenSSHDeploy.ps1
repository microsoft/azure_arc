#Install open SSH
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Start-Service sshd
Stop-Service sshd
#Changing port
((Get-Content -path C:\ProgramData\ssh\sshd_config -Raw) -replace '#Port 22',"Port 2204") | Set-Content -Path C:\ProgramData\ssh\sshd_config
Start-Service sshd

Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if ((Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
   Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
}
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2204