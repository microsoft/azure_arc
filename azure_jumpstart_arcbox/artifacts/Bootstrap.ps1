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
    [string]$capiArcDataClusterName,
    [string]$k3sArcClusterName,
    [string]$githubUser,
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
[System.Environment]::SetEnvironmentVariable('capiArcDataClusterName', $capiArcDataClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcClusterName', $k3sArcClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon,[System.EnvironmentVariableTarget]::Machine)

# Creating ArcBox path
Write-Output "Creating ArcBox path"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxVMDir = "C:\ArcBox\Virtual Machines"
$Env:ArcBoxKVDir = "C:\ArcBox\KeyVault"
$Env:ArcBoxGitOpsDir = "C:\ArcBox\GitOps"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$Env:agentScript = "C:\ArcBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$winTerminalVersion = "1.7.1091.0" # Pindown Windows Terminal version 

New-Item -Path $Env:ArcBoxDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxVMDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxKVDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxGitOpsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force

Start-Transcript -Path $Env:ArcBoxLogsDir\Bootstrap.log

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
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,dotnetcore-3.1-sdk,setdefaultbrowser,zoomit'
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
                    
                    $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                
                    foreach ($app in $appsToInstall)
                    {
                        Write-Host "Installing $app"
                        & choco install $app /y -Force | Write-Output
                    }
                }                        
            }

            # All flavors
            Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/arcbox_wallpaper.png" -OutFile "$Env:ArcBoxDir\wallpaper.png"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/MonitorWorkbookLogonScript.ps1") -OutFile "$Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.parameters.json") -OutFile "$Env:ArcBoxDir\mgmtMonitorWorkbook.parameters.json"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile "$Env:ArcBoxDir\DeploymentStatus.ps1"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile "$Env:ArcBoxLogsDir\LogInstructions.txt"

            Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcSQLIcon.ico") -OutFile "$Env:ArcBoxDir\ArcSQLIcon.ico"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcSQLManualOnboarding.ps1") -OutFile "$Env:ArcBoxDir\ArcSQLManualOnboarding.ps1"
            Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLUser.ps1") -OutFile "$Env:ArcBoxDir\installArcAgentSQLUser.ps1"

            Invoke-WebRequest "https://github.com/microsoft/terminal/releases/download/v"$winTerminalVersion"/Microsoft.WindowsTerminal_"$winTerminalVersion"_8wekyb3d8bbwe.msixbundle" -OutFile "$Env:ArcBoxDir\WindowsTerminal.msixbundle"
            Add-AppxPackage -Path "$Env:ArcBoxDir\WindowsTerminal.msixbundle"

            # Workbook template
            if ($flavor -eq "ITPro") {
                Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookITPro.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
            }
            elseif ($flavor -eq "DevOps") {
                Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookDevOps.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
            }
            else {
                Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookFull.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
            }

            # ITPro
            if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
                Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgent.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentSQLSP.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentUbuntu.sh") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentUbuntu.sh
                Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentCentOS.sh") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentCentOS.sh
            }

            # DevOps
            if ($flavor -eq "Full" -Or $flavor -eq "DevOps") {
                Invoke-WebRequest ($templateBaseUrl + "artifacts/DevOpsLogonScript.ps1") -OutFile $Env:ArcBoxDir\DevOpsLogonScript.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookbuyer.yaml") -OutFile $Env:ArcBoxKVDir\bookbuyer.yaml
                Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookstore.yaml") -OutFile $Env:ArcBoxKVDir\bookstore.yaml
                Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/hello-arc.yaml") -OutFile $Env:ArcBoxKVDir\hello-arc.yaml
                Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sGitOps.ps1") -OutFile $Env:ArcBoxGitOpsDir\K3sGitOps.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sRBAC.ps1") -OutFile $Env:ArcBoxGitOpsDir\K3sRBAC.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arc.ico") -OutFile $Env:ArcBoxIconDir\arc.ico
                Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/bookstore.ico") -OutFile $Env:ArcBoxIconDir\bookstore.ico
            }

            # Full
            if ($flavor -eq "Full") {
                Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile $Env:ArcBoxDir\azuredatastudio.zip
                Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile $Env:ArcBoxDir\AZDataCLI.msi
                Invoke-WebRequest ($templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile $Env:ArcBoxDir\settingsTemplate.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/DataServicesLogonScript.ps1") -OutFile $Env:ArcBoxDir\DataServicesLogonScript.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/DeployPostgreSQL.ps1") -OutFile $Env:ArcBoxDir\DeployPostgreSQL.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMI.ps1") -OutFile $Env:ArcBoxDir\DeploySQLMI.ps1
                Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:ArcBoxDir\dataController.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:ArcBoxDir\dataController.parameters.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.json") -OutFile $Env:ArcBoxDir\postgreSQL.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/postgreSQL.parameters.json") -OutFile $Env:ArcBoxDir\postgreSQL.parameters.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.json") -OutFile $Env:ArcBoxDir\sqlmi.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmi.parameters.json") -OutFile $Env:ArcBoxDir\sqlmi.parameters.json
                Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile $Env:ArcBoxDir\SQLMIEndpoints.ps1
                Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip" -OutFile $Env:ArcBoxDir\SqlQueryStress.zip
            }
        }

ClientTools_01 -templateBaseUrl $templateBaseUrl -flavor $flavor | Format-Table
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

workflow ClientTools_02
{
    InlineScript {
        Expand-Archive $Env:ArcBoxDir\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
        Start-Process msiexec.exe -Wait -ArgumentList "/I $Env:ArcBoxDir\AZDataCLI.msi /quiet"
    }
}
        
if ($flavor -eq "Full") {
    ClientTools_02 | Format-Table 
}

if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    # Creating scheduled task for ArcServersLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "Full") {
    # Creating scheduled task for DataServicesLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn 
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcBoxDir\DataServicesLogonScript.ps1
    Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "DevOps") {
    # Creating scheduled task for DevOpsLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn 
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcBoxDir\DevOpsLogonScript.ps1
    Register-ScheduledTask -TaskName "DevOpsLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1
Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart
