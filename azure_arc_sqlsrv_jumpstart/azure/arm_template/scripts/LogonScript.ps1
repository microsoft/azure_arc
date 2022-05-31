$Env:JumpstartDir = "C:\Jumpstart"
$Env:JumpstartLogsDir = "C:\Jumpstart\Logs"
$Env:JumpstartScriptDir = "C:\Jumpstart\agentScript"
$Env:JumpstartTempDir = "C:\Temp"

Start-Transcript -Path $Env:JumpstartLogsDir\LogonScript.log

Write-Host "Installing ConnectedMachine PowerShell Module"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Write-Host "Installing SQL Server and PowerShell Module"
If(-not(Get-InstalledModule SQLServer -ErrorAction silentlycontinue)){
    Install-Module SQLServer -Confirm:$False -Force
}

choco install sql-server-2019 -y --params="'/IgnorePendingReboot /INSTANCENAME=MSSQLSERVER'"

Set-Service -Name SQLBrowser -StartupType Automatic
Start-Service -Name SQLBrowser

$env:PSModulePath = $env:PSModulePath + ";C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules"
Import-Module -Name "sqlps"

$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer # connects to localhost by default
$instance = $wmi.ServerInstances | Where-Object { $_.Name -eq 'MSSQLSERVER' }
$wmi

$tcp = $instance.ServerProtocols | Where-Object { $_.Name -eq 'Tcp' }
$tcp.IsEnabled = $true
$tcp.Alter()
$tcp

$np = $instance.ServerProtocols | Where-Object { $_.Name -eq 'Np' }
$np.IsEnabled = $true
$np.Alter()
$np

Restart-Service -Name 'MSSQLSERVER'

# Download and restore AdventureWorks Database
Write-Host "Restoring AdventureWorks database"
Invoke-WebRequest ($Env:templateBaseUrl + "arm_template/scripts/AdventureWorksLT2019.bak") -OutFile $Env:JumpstartTempDir\AdventureWorksLT2019.bak
Start-Sleep -Seconds 3
Restore-SqlDatabase -ServerInstance $Env:COMPUTERNAME -Database "AdventureWorksLT2019" -BackupFile $Env:JumpstartTempDir\AdventureWorksLT2019.bak -PassThru -Verbose

Write-Host "Creating SQL Server Management Studio Desktop shortcut"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
$ShortcutFile = "C:\Users\$Env:USERNAME\Desktop\Microsoft SQL Server Management Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
Write-Output "Configuring the VM to allow onboarding as an Azure Arc-enabled server"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

Start-Process powershell.exe -ArgumentList $Env:JumpstartScriptDir\installArcAgentSQLModified.ps1

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
