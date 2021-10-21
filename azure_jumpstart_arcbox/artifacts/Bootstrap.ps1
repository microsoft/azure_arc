param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$registryUsername,
    [string]$registryPassword,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$mssqlmiName,
    [string]$POSTGRES_NAME,   
    [string]$POSTGRES_WORKER_NODE_COUNT,
    [string]$POSTGRES_DATASIZE,
    [string]$POSTGRES_SERVICE_TYPE,
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$automationTriggerAtLogon
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryPassword', $registryPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('mssqlmiName', $mssqlmiName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_NAME', $POSTGRES_NAME,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_WORKER_NODE_COUNT', $POSTGRES_WORKER_NODE_COUNT,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_DATASIZE', $POSTGRES_DATASIZE,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_SERVICE_TYPE', $POSTGRES_SERVICE_TYPE,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon,[System.EnvironmentVariableTarget]::Machine)

# Create path
Write-Output "Create ArcBox path"
$ArcBoxDir = "C:\ArcBox"
$vmDir = "C:\ArcBox\Virtual Machines"
$agentScript = "C:\ArcBox\agentScript"
$tempDir = "C:\Temp"
New-Item -Path $ArcBoxDir -ItemType directory -Force
New-Item -Path $vmDir -ItemType directory -Force
New-Item -Path $tempDir -ItemType directory -Force
New-Item -Path $agentScript -ItemType directory -Force

Start-Transcript "C:\ArcBox\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

# Installing DHCP service 
Write-Output "Installing DHCP service"
Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

# Installing tools
workflow ClientTools_01
        {
            param(
                [Parameter (Mandatory = $true)]
                [string]$templateBaseUrl,
                [Parameter (Mandatory = $true)]
                [string]$flavor
            )
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,dotnetcore-3.1-sdk'
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
                                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }

                    # All flavors
                    Invoke-WebRequest ($templateBaseUrl + "artifacts/wallpaper.png") -OutFile "C:\ArcBox\wallpaper.png"
                    Invoke-WebRequest ($templateBaseUrl + "artifacts/MonitorWorkbookLogonScript.ps1") -OutFile "C:\ArcBox\MonitorWorkbookLogonScript.ps1"
                    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.json") -OutFile "C:\ArcBox\mgmtMonitorWorkbook.json"
                    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.parameters.json") -OutFile "C:\ArcBox\mgmtMonitorWorkbook.parameters.json"

                    # ITPro
                    if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile "C:\ArcBox\ArcServersLogonScript.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile "C:\ArcBox\agentScript\installArcAgent.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQL.ps1") -OutFile "C:\ArcBox\agentScript\installArcAgentSQL.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentUbuntu.sh") -OutFile "C:\ArcBox\agentScript\installArcAgentUbuntu.sh"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentCentOS.sh") -OutFile "C:\ArcBox\agentScript\installArcAgentCentOS.sh"
                    }

                    # Developers
                    if ($flavor -eq "Full" -Or $flavor -eq "Developer") {
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/capiStorageClass.yaml") -OutFile "C:\ArcBox\capiStorageClass.yaml"
                        Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\ArcBox\azuredatastudio.zip"
                        Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\ArcBox\AZDataCLI.msi"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile "C:\ArcBox\settingsTemplate.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/DataServicesLogonScript.ps1") -OutFile "C:\ArcBox\DataServicesLogonScript.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/DeployPostgreSQL.ps1") -OutFile "C:\ArcBox\DeployPostgreSQL.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMI.ps1") -OutFile "C:\ArcBox\DeploySQLMI.ps1"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.json") -OutFile "C:\ArcBox\dataController.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile "C:\ArcBox\dataController.parameters.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.json") -OutFile "C:\ArcBox\postgreSQL.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.parameters.json") -OutFile "C:\ArcBox\postgreSQL.parameters.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.json") -OutFile "C:\ArcBox\sqlmi.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.parameters.json") -OutFile "C:\ArcBox\sqlmi.parameters.json"
                        Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile "C:\ArcBox\SQLMIEndpoints.ps1"
                        Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip" -OutFile "C:\ArcBox\SqlQueryStress.zip"                    
                    }

                }
        }

ClientTools_01 -templateBaseUrl $templateBaseUrl -flavor $flavor | Format-Table
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\ArcBox\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\ArcBox\AZDataCLI.msi /quiet'
                }
            }
        }
        
if ($flavor -eq "Full" -Or $flavor -eq "Developer") {
    ClientTools_02 | Format-Table 
}

if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    # Creating scheduled task for ArcServersLogonScript.ps1
    if ($automationTriggerAtLogon -eq $true) {
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
    }
    else {
        $Trigger = New-ScheduledTaskTrigger -AtStartup   
    }
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\ArcBox\ArcServersLogonScript.ps1'
    Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "Full" -Or $flavor -eq "Developer") {
    # Creating scheduled task for DataServicesLogonScript.ps1
    if ($automationTriggerAtLogon -eq $true) {
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
    }
    else {
        $Trigger = New-ScheduledTaskTrigger -AtStartup   
    }
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\ArcBox\DataServicesLogonScript.ps1'
    Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
if ($automationTriggerAtLogon -eq $true) {
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
}
else {
    $Trigger = New-ScheduledTaskTrigger -AtStartup   
}
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\ArcBox\MonitorWorkbookLogonScript.ps1'
Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart