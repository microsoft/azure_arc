param (
    [string]$subscriptionId,
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$location,
    [string]$adminUsername
)

[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)

$chocolateyAppList = "az.powershell,azure-cli,sql-server-management-studio"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){   
    Write-Host "Chocolatey Apps Specified"  
    
    $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

    foreach ($app in $appsToInstall)
    {
        Write-Host "Installing $app"
        & choco install $app /y
    }
}

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force

Write-Host "Installing SQL Server and PowerShell Module"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
If(-not(Get-InstalledModule SQLServer -ErrorAction silentlycontinue)){
    Install-Module SQLServer -Confirm:$False -Force
}
choco install sql-server-2019 -y --params="'/IgnorePendingReboot /INSTANCENAME=MSSQLSERVER'"
Set-Service -Name SQLBrowser -StartupType Automatic
Start-Service -Name SQLBrowser

Write-Host "Enable SQL TCP"
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules"
Import-Module -Name "sqlps"
$smo = 'Microsoft.SqlServer.Management.Smo.'  
$wmi = new-object ($smo + 'Wmi.ManagedComputer').  
# List the object properties, including the instance names.  
$Wmi

# Enable the TCP protocol on the default instance.  
$uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']" 
$Tcp = $wmi.GetSmoObject($uri)  
$Tcp.IsEnabled = $true  
$Tcp.Alter()  
$Tcp

# Enable the named pipes protocol for the default instance.  
$uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']"  
$Np = $wmi.GetSmoObject($uri)  
$Np.IsEnabled = $true  
$Np.Alter()  
$Np

Restart-Service -Name 'MSSQLSERVER'

Write-Host "Restoring AdventureWorksLT2019 Sample Database"
Invoke-WebRequest "https://github.com/microsoft/azure_arc/raw/master/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/AdventureWorksLT2019.bak" -OutFile "C:\tmp\AdventureWorksLT2019.bak"
Restore-SqlDatabase -ServerInstance $env:COMPUTERNAME -Database "AdventureWorksLT2019" -BackupFile "C:\tmp\AdventureWorksLT2019.bak" -AutoRelocateFile -PassThru -Verbose



# Creating Powershell Logon Script
# $LogonScript = @'
# Start-Transcript -Path C:\tmp\LogonScript.log

# Write-Host "Creating SQL Server Management Studio Desktop shortcut"
# $TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
# $ShortcutFile = "C:\Users\$env:USERNAME\Desktop\Microsoft SQL Server Management Studio.lnk"
# $WScriptShell = New-Object -ComObject WScript.Shell
# $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
# $Shortcut.TargetPath = $TargetFile
# $Shortcut.Save()

# ## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

# Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
# Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
# Stop-Service WindowsAzureGuestAgent -Force -Verbose
# New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254 

# ## Azure Arc agent Installation

# Write-Host "Onboarding to Azure Arc"
# # Download the package
# function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
# download

# # Install the package
# msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# # Run connect command
#  & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
#  --service-principal-id $env:appId `
#  --service-principal-secret $env:password `
#  --resource-group $env:resourceGroup `
#  --tenant-id $env:tenantId `
#  --location $env:location `
#  --subscription-id $env:subscriptionId `
#  --tags "Project=jumpstart_azure_arc_servers"

# Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
# Stop-Process -Name powershell -Force
# '@ > C:\tmp\LogonScript.ps1

# # Creating LogonScript Windows Scheduled Task
# $Trigger = New-ScheduledTaskTrigger -AtLogOn
# $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
# Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "${adminUsername}" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
