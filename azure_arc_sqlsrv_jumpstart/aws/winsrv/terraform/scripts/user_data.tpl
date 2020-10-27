<powershell>

$env:admin_user='${admin_user}'
$env:admin_password='${admin_password}'

[System.Environment]::SetEnvironmentVariable('admin_user', $env:admin_user,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('admin_password', $env:admin_password,[System.EnvironmentVariableTarget]::Machine)

$SecurePassword=ConvertTo-SecureString $env:admin_password -AsPlainText -Force
New-LocalUser -Name $env:admin_user -Password $SecurePassword -PasswordNeverExpires 
Add-LocalGroupMember -Group "Administrators" -Member $env:admin_user

write-output "Running User Data Script"
write-host "(host) Running User Data Script"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# Remove HTTP listener
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse

Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -RemoteAddress Any

netsh advfirewall firewall set rule group="remote administration" new enable=yes
netsh advfirewall firewall add rule name="Open Port 5985" dir=in action=allow protocol=TCP localport=5985
netsh advfirewall firewall add rule name="Open Port 5986" dir=in action=allow protocol=TCP localport=5986

winrm quickconfig -q
winrm quickconfig -transport:http
winrm set winrm/config '@{MaxTimeoutms="7200000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
winrm set winrm/config/winrs '@{MaxProcessesPerShell="0"}'
winrm set winrm/config/winrs '@{MaxShellsPerUser="0"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

net stop winrm
sc.exe config winrm start= auto
net start winrm

Rename-Computer -NewName '${hostname}' -Force
Restart-Computer

</powershell>