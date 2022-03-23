$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

Start-Transcript -Path $Env:ArcBoxLogsDir\ScriptOpenSSH.log
Write-Host "ScriptOpenSSH log in"

# Required for CLI commands
az login --service-principal --username $env:spnClientID --password $env:spnClientSecret --tenant $env:spnTenantId

if ($Env:flavor -eq "Full" -Or $Env:flavor -eq "ITPro") {
    Write-Host "Deploying ArcServersLogonScript."
    Write-Host "`n"
    Invoke-Expression $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Write-Host "Deployed ArcServersLogonScript."
    Write-Host "`n"
}

#Install open SSH
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Start-Service sshd
Stop-Service sshd
((Get-Content -path C:\ProgramData\ssh\sshd_config -Raw) -replace '#Port 22',"Port 2204") | Set-Content -Path C:\ProgramData\ssh\sshd_config
Start-Service sshd

# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if ((Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
   Write-Host "Removing"
   Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
}
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2204

Write-Host "Deployed OpenSSH"

echo "Deployed OpenSSH" > $Env:ArcBoxLogsDir\OpenSSHDeployed.txt
exit 0