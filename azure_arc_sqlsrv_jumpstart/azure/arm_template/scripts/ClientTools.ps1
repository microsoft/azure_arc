param (
    [string]$subId,
    [string]$servicePrincipalAppId,
    [string]$servicePrincipalSecret,
    [string]$servicePrincipalTenantId,
    [string]$resourceGroup,
    [string]$location,
    [string]$adminUsername,
    [string]$adminPassword
)

[System.Environment]::SetEnvironmentVariable('subId', $subId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalAppId', $servicePrincipalAppId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalSecret', $servicePrincipalSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalTenantId', $servicePrincipalTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword,[System.EnvironmentVariableTarget]::Machine)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
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

# Downloading artifacts & enabling Fusion logging
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/ArcOnboarding.ps1" -OutFile "C:\tmp\ArcOnboarding.ps1"
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Fusion" -Name "EnableLog" -Value 1 -PropertyType "DWord"

# Creating PowerShell Logon Script
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

Write-Host "Installing ConnectedMachine PowerShell Module"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Az.ConnectedMachine -AllowClobber -Scope CurrentUser -Force

Write-Host "Installing SQL Server and PowerShell Module"
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

# Onboarding to Azure Arc, installing SQL and configuring SQL Azure Assessment
$script = "C:\tmp\ArcOnboarding.ps1"
$commandLine = "$script"
Start-Process powershell.exe -ArgumentList $commandline

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "${adminUsername}" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
