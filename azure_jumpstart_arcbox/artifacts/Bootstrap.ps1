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
    [string]$aksArcClusterName,
    [string]$aksdrArcClusterName,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$rdpPort,
    [string]$sshPort
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryPassword', $registryPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('mssqlmiName', $mssqlmiName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_NAME', $POSTGRES_NAME, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_WORKER_NODE_COUNT', $POSTGRES_WORKER_NODE_COUNT, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_DATASIZE', $POSTGRES_DATASIZE, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('POSTGRES_SERVICE_TYPE', $POSTGRES_SERVICE_TYPE, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('capiArcDataClusterName', $capiArcDataClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcClusterName', $k3sArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('addsDomainName', "jumpstart.local", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksArcClusterName', $aksArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksdrArcClusterName', $aksdrArcClusterName, [System.EnvironmentVariableTarget]::Machine)

[System.Environment]::SetEnvironmentVariable('ArcBoxDir', "C:\ArcBox", [System.EnvironmentVariableTarget]::Machine)

# Creating ArcBox path
Write-Output "Creating ArcBox path"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxKVDir = "$Env:ArcBoxDir\KeyVault"
$Env:ArcBoxGitOpsDir = "$Env:ArcBoxDir\GitOps"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$Env:agentScript = "$Env:ArcBoxDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:ArcBoxDataOpsDir = "$Env:ArcBoxDir\DataOps"

New-Item -Path $Env:ArcBoxDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxVMDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxKVDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxGitOpsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force
New-Item -Path $Env:ArcBoxDataOpsDir -ItemType directory -Force

Start-Transcript -Path $Env:ArcBoxLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

# Installing DHCP service
Write-Output "Installing DHCP service"
Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

#Installing AD DS roles
if ($flavor -eq "DataOps") {
    Install-WindowsFeature -Name RSAT-AD-PowerShell
    Install-WindowsFeature -Name RSAT-DNS-Server
}

# Installing tools

Write-Header "Installing PowerShell 7"

$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
msiexec.exe /package PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

Copy-Item $PsHome\Profile.ps1 -Destination "C:\Program Files\PowerShell\7\"

Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,ssms,dotnet-sdk,setdefaultbrowser,zoomit,openssl.light'

try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Chocolatey Apps Specified"

$appsToInstall = $chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }

foreach ($app in $appsToInstall) {
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output

}

Write-Header "Installing Azure CLI (64-bit not available via Chocolatey)"

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

Write-Header "Fetching GitHub Artifacts"

# All flavors
Write-Host "Fetching Artifacts for All Flavors"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/arcbox_wallpaper_dark.png" -OutFile $Env:ArcBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/MonitorWorkbookLogonScript.ps1") -OutFile $Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.parameters.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.parameters.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile $Env:ArcBoxDir\DeploymentStatus.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:ArcBoxLogsDir\LogInstructions.txt

Invoke-WebRequest ($templateBaseUrl + "../tests/GHActionDeploy.ps1") -OutFile "$Env:ArcBoxDir\GHActionDeploy.ps1"
Invoke-WebRequest ($templateBaseUrl + "../tests/OpenSSHDeploy.ps1") -OutFile "$Env:ArcBoxDir\OpenSSHDeploy.ps1"

# Workbook template
if ($flavor -eq "ITPro") {
    Write-Host "Fetching Workbook Template Artifact for ITPro"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookITPro.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
}
elseif ($flavor -eq "DevOps") {
    Write-Host "Fetching Workbook Template Artifact for DevOps"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookDevOps.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
}
elseif ($flavor -eq "DataOps") {
    Write-Host "Fetching Workbook Template Artifact for DataOps"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookDataOps.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
}
else {
    Write-Host "Fetching Workbook Template Artifact for Full"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookFull.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.json
}

# ITPro
if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    Write-Host "Fetching Artifacts for ITPro Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgent.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentSQLSP.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentUbuntu.sh") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentUbuntu.sh
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arcsql.ico") -OutFile $Env:ArcBoxIconDir\arcsql.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcSQLManualOnboarding.ps1") -OutFile $Env:ArcBoxDir\ArcSQLManualOnboarding.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLUser.ps1") -OutFile $Env:ArcBoxDir\installArcAgentSQLUser.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/testDefenderForSQL.ps1") -OutFile $Env:ArcBoxDir\testDefenderForSQL.ps1
}

# DevOps
if ($flavor -eq "DevOps") {
    Write-Host "Fetching Artifacts for DevOps Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DevOpsLogonScript.ps1") -OutFile $Env:ArcBoxDir\DevOpsLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/BookStoreLaunch.ps1") -OutFile $Env:ArcBoxDir\BookStoreLaunch.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookbuyer.yaml") -OutFile $Env:ArcBoxKVDir\bookbuyer.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/bookstore.yaml") -OutFile $Env:ArcBoxKVDir\bookstore.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/devops_ingress/hello-arc.yaml") -OutFile $Env:ArcBoxKVDir\hello-arc.yaml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sGitOps.ps1") -OutFile $Env:ArcBoxGitOpsDir\K3sGitOps.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/K3sRBAC.ps1") -OutFile $Env:ArcBoxGitOpsDir\K3sRBAC.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/gitops_scripts/ResetBookstore.ps1") -OutFile $Env:ArcBoxGitOpsDir\ResetBookstore.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arc.ico") -OutFile $Env:ArcBoxIconDir\arc.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/bookstore.ico") -OutFile $Env:ArcBoxIconDir\bookstore.ico
}

# DataOps
if ($flavor -eq "DataOps") {
    Write-Host "Fetching Artifacts for DataOps Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataOpsLogonScript.ps1") -OutFile $Env:ArcBoxDir\DataOpsLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/RunAfterClientVMADJoin.ps1") -OutFile $Env:ArcBoxDir\RunAfterClientVMADJoin.ps1
    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile $Env:ArcBoxDir\azuredatastudio.zip
    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile $Env:ArcBoxDir\AZDataCLI.msi
    Invoke-WebRequest ($templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile $Env:ArcBoxDir\settingsTemplate.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploySQLMIADAuth.ps1") -OutFile $Env:ArcBoxDir\DeploySQLMIADAuth.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:ArcBoxDir\dataController.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:ArcBoxDir\dataController.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmiAD.json") -OutFile $Env:ArcBoxDir\sqlmiAD.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/sqlmiAD.parameters.json") -OutFile $Env:ArcBoxDir\sqlmiAD.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile $Env:ArcBoxDir\SQLMIEndpoints.ps1
    Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStressNet6.zip" -OutFile $Env:ArcBoxDir\SqlQueryStress.zip
    Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnector.json") -OutFile $Env:ArcBoxDir\adConnector.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/adConnector.parameters.json") -OutFile $Env:ArcBoxDir\adConnector.parameters.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataOpsAppScript.ps1") -OutFile $Env:ArcBoxDir\DataOpsAppScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/bookstore.ico") -OutFile $Env:ArcBoxIconDir\bookstore.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataOpsAppDRScript.ps1") -OutFile $Env:ArcBoxDataOpsDir\DataOpsAppDRScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataOpsTestAppScript.ps1") -OutFile $Env:ArcBoxDataOpsDir\DataOpsTestAppScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgent.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentSQLSP.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/testDefenderForSQL.ps1") -OutFile $Env:ArcBoxDir\testDefenderForSQL.ps1
}

# Full
if ($flavor -eq "Full") {
    Write-Host "Fetching Artifacts for Full Flavor"
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
    Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStressNet6.zip" -OutFile $Env:ArcBoxDir\SqlQueryStress.zip
}

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

if ($flavor -eq "Full" -Or $flavor -eq "DataOps") {
    Write-Header "Installing Azure Data Studio"
    Expand-Archive $Env:ArcBoxDir\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
    Start-Process msiexec.exe -Wait -ArgumentList "/I $Env:ArcBoxDir\AZDataCLI.msi /quiet"
}

# Change RDP Port
Write-Host "RDP port number from configuration is $rdpPort"
if (($rdpPort -ne $null) -and ($rdpPort -ne "") -and ($rdpPort -ne "3389"))
{
    Write-Host "Configuring RDP port number to $rdpPort"
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0

    # RDP port
    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host "Current RDP PortNumber: $portNumber"
    if (!($portNumber -eq $rdpPort))
    {
      Write-Host Setting RDP PortNumber to $rdpPort
      Set-ItemProperty -Path $RDPTCPpath -name 'PortNumber' -Value $rdpPort
      Restart-Service TermService -force
    }

    #Setup firewall rules
    if ($rdpPort -eq 3389)
    {
      netsh advfirewall firewall set rule group="remote desktop" new Enable=Yes
    }
    else
    {
      $systemroot = get-content env:systemroot
      netsh advfirewall firewall add rule name="Remote Desktop - Custom Port" dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$RDPPort enable=yes
    }

    Write-Host "RDP port configuration complete."
}

Write-Header "Configuring Logon Scripts"

$ScheduledTaskExecutable = "pwsh.exe"

if ($flavor -eq "Full" -Or $flavor -eq "ITPro") {
    # Creating scheduled task for ArcServersLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Register-ScheduledTask -TaskName "ArcServersLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "Full") {
    # Creating scheduled task for DataServicesLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\DataServicesLogonScript.ps1
    Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "DevOps") {
    # Creating scheduled task for DevOpsLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\DevOpsLogonScript.ps1
    Register-ScheduledTask -TaskName "DevOpsLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($flavor -eq "DataOps") {

    # Joining ClientVM to AD DS domain
    $netbiosname = $Env:addsDomainName.Split(".")[0]
    $computername = $env:COMPUTERNAME

    $domainCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
            UserName = "${netbiosname}\${adminUsername}"
            Password = (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)[0]
        })

    $localCred = New-Object pscredential -ArgumentList ([pscustomobject]@{
            UserName = "${computername}\${adminUsername}"
            Password = (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)[0]
        })

    # Creating scheduled task for DataOpsLogonScript.ps1
    # Register schedule task to run after system reboot
    # schedule task to run after reboot to create reverse DNS lookup
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument "$Env:ArcBoxDir\RunAfterClientVMADJoin.ps1"
    Register-ScheduledTask -TaskName "RunAfterClientVMADJoin" -Trigger $Trigger -User SYSTEM -Action $Action -RunLevel "Highest" -Force
    Write-Host "Registered scheduled task 'RunAfterClientVMADJoin' to run after Client VM AD join."

    Write-Host "`n"
    Write-Host "Joining client VM to domain"
    Add-Computer -DomainName $Env:addsDomainName -LocalCredential $localCred -Credential $domainCred
    Write-Host "Joined Client VM to $addsDomainName domain."

    # Disabling Windows Server Manager Scheduled Task
    Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

    # Install Hyper-V and reboot
    Write-Host "Installing Hyper-V and restart"
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

    # Clean up Bootstrap.log
    Stop-Transcript
    $logSuppress = Get-Content $bootstrapLogFile | Where-Object { $_ -notmatch "Host Application: $ScheduledTaskExecutable" }
    $logSuppress | Set-Content $bootstrapLogFile -Force

    # Restart computer
    Restart-Computer
}
else {

    # Creating scheduled task for MonitorWorkbookLogonScript.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1
    Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

    # Disabling Windows Server Manager Scheduled Task
    Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

    Write-Header "Installing Hyper-V"

    # Install Hyper-V and reboot
    Write-Host "Installing Hyper-V and restart"
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart

    # Clean up Bootstrap.log
    Write-Host "Clean up Bootstrap.log"
    Stop-Transcript
    $logSuppress = Get-Content $Env:ArcBoxLogsDir\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: $ScheduledTaskExecutable" }
    $logSuppress | Set-Content $Env:ArcBoxLogsDir\Bootstrap.log -Force
}
