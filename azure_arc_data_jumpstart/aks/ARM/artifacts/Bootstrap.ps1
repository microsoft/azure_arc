param (
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$workspaceName,
    [string]$clusterName,
    [string]$deploySQLMI,
    [string]$SQLMIHA,    
    [string]$deployPostgreSQL,
    [string]$templateBaseUrl,
    [string]$enableADAuth,
    [string]$addsDomainName,
    [string]$profileRootBaseUrl
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deploySQLMI', $deploySQLMI,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SQLMIHA', $SQLMIHA,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployPostgreSQL', $deployPostgreSQL,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('enableADAuth', $enableADAuth,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('addsDomainName', $addsDomainName,[System.EnvironmentVariableTarget]::Machine)

$Env:tempDir="C:\Temp"
$bootstrapLogFile = "$Env:tempDir\Bootstrap.log"
Start-Transcript $bootstrapLogFile
. ./AddPSProfile-v1.ps1

Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnector.yaml") -OutFile "$Env:tempDir\adConnector.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnectorCMK.yaml") -OutFile "$Env:tempDir\adConnectorCMK.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIADAuthCMK.yaml") -OutFile "$Env:tempDir\SQLMIADAuthCMK.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMIADAuth.ps1") -OutFile "$Env:tempDir\DeploySQLMIADAuth.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/RunAfterClientVMADJoin.ps1") -OutFile "$Env:tempDir\RunAfterClientVMADJoin.ps1"


##############################################################################
# Following code is support AD authentication in SQL MI. This code is executed
# when user sets enableADAuth=true. When this flag is set true 'addsDomainName' parameter
# is supplied to this script setup ADDS domain.
##############################################################################
# If AD Auth is required join computer to ADDS domain and restart computer
if ($enableADAuth -eq $true -and $addsDomainName.Length -gt 0)
{
    . ./ArcDataCommonBootstrap.ps1 -profileRootBaseUrl $profileRootBaseUrl -templateBaseUrl $templateBaseUrl -adminUsername $adminUsername -avoidScriptAtLogOn

    # Install Windows Feature RSAT-AD-PowerShell windows feature to setup OU and User Accounts in ADDS
    Install-WindowsFeature -Name RSAT-AD-PowerShell
    Install-WindowsFeature -Name RSAT-DNS-Server

    Write-Host "Installed RSAT-AD-PowerShell windows feature"

    Write-Host "Joining computer to Active Directory domain ${addsDomainName}. Computer will be rebooted after joining domain."
    # Get NetBios name from FQDN
    $netbiosname = $addsDomainName.Split(".")[0]
    $computername = $env:COMPUTERNAME

    $domainCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
        UserName = "${netbiosname}\${adminUsername}"
        Password = (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)[0]
    })
    
    $localCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
        UserName = "${computername}\${adminUsername}"
        Password = (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)[0]
    })
 
    # Register schedule task to run after system reboot
    # schedule task to run after reboot to create reverse DNS lookup
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Env:tempDir\RunAfterClientVMADJoin.ps1"
    Register-ScheduledTask -TaskName "RunAfterClientVMADJoin" -Trigger $Trigger -User SYSTEM -Action $Action -RunLevel "Highest" -Force
    Write-Host "Registered scheduled task 'RunAfterClientVMADJoin' to run after Client VM AD join."

    # services
    # Use $env:username to run task under domain user
    Write-Host "Domain Name: $addsDomainName, Admin User: $adminUsername, NetBios Name: $netbiosname, Computer Name: $computername"
    
    Add-Computer -DomainName $addsDomainName -LocalCredential $localCred -Credential $domainCred
    Write-Host "Joined Client VM to $addsDomainName domain."

    # Clean up Bootstrap.log
    Stop-Transcript
    $logSuppress = Get-Content $bootstrapLogFile | Where { $_ -notmatch "Host Application: powershell.exe" } 
    $logSuppress | Set-Content $bootstrapLogFile -Force

    # Restart computer
    Restart-Computer
}
else
{
    . ./ArcDataCommonBootstrap.ps1 -profileRootBaseUrl $profileRootBaseUrl -templateBaseUrl $templateBaseUrl -adminUsername $adminUsername

    # Clean up Bootstrap.log
    Stop-Transcript
    $logSuppress = Get-Content $bootstrapLogFile | Where { $_ -notmatch "Host Application: powershell.exe" } 
    $logSuppress | Set-Content $bootstrapLogFile -Force
}