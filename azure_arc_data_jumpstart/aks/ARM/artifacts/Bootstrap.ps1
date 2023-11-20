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
    [string]$addsDomainName
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

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

$bootstrapLogFile = "$tempDir\Bootstrap.log"
Start-Transcript $bootstrapLogFile

$ErrorActionPreference = 'SilentlyContinue'

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Host "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Downloading GitHub artifacts for DataServicesLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile "${tempDir}\settingsTemplate.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/DataServicesLogonScript.ps1") -OutFile "${tempDir}\DataServicesLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMI.ps1") -OutFile "${tempDir}\DeploySQLMI.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeployPostgreSQL.ps1") -OutFile "${tempDir}\DeployPostgreSQL.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.json") -OutFile "${tempDir}\dataController.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile "${tempDir}\dataController.parameters.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMI.json") -OutFile "${tempDir}\SQLMI.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMI.parameters.json") -OutFile "${tempDir}\SQLMI.parameters.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.json") -OutFile "${tempDir}\postgreSQL.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.parameters.json") -OutFile "${tempDir}\postgreSQL.parameters.json"
Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile "${tempDir}\SQLMIEndpoints.ps1"
Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip" -OutFile "${tempDir}\SqlQueryStress.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/jumpstart_wallpaper_dark.png" -OutFile "${tempDir}\wallpaper.png"
Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnector.yaml") -OutFile "${tempDir}\adConnector.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnectorCMK.yaml") -OutFile "${tempDir}\adConnectorCMK.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIADAuthCMK.yaml") -OutFile "${tempDir}\SQLMIADAuthCMK.yaml"
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMIADAuth.ps1") -OutFile "${tempDir}\DeploySQLMIADAuth.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/RunAfterClientVMADJoin.ps1") -OutFile "${tempDir}\RunAfterClientVMADJoin.ps1"


# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm,grep,ssms,dotnetcore-3.1-sdk'
            #Run commands in parallel.
            Parallel 
                {
                    InlineScript {
                        param (
                            [string]$chocolateyAppList
                        )
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false)
                        {
                            try{
                                choco config get cacheLocation
                            }catch{
                                Write-Output "Chocolatey not detected, trying to install now"
                                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "${tempDir}\azuredatastudio.zip"
                    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "${tempDir}\AZDataCLI.msi"
                }
        }

ClientTools_01 | Format-Table

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive '${tempDir}\azuredatastudio.zip' -DestinationPath 'C:\Program Files\Azure Data Studio'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I ${tempDir}\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | Format-Table 

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HubsSidebarEnabled'
$Value        = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HideFirstRunExperience'
$Value        = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

##############################################################################
# Following code is support AD authentication in SQL MI. This code is executed
# when user sets enableADAuth=true. When this flag is set true 'addsDomainName' parameter
# is supplied to this script setup ADDS domain.
##############################################################################
# If AD Auth is required join computer to ADDS domain and restart computer
if ($enableADAuth -eq $true -and $addsDomainName.Length -gt 0)
{
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
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$tempDir\RunAfterClientVMADJoin.ps1"
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
    # Creating scheduled task for DataServicesLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$tempDir\DataServicesLogonScript.ps1"

    # Register schedule task under local account
    Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
    Write-Host "Registered scheduled task 'DataServicesLogonScript' to run at user logon."

    # Clean up Bootstrap.log
    Stop-Transcript
    $logSuppress = Get-Content $bootstrapLogFile | Where { $_ -notmatch "Host Application: powershell.exe" } 
    $logSuppress | Set-Content $bootstrapLogFile -Force
}