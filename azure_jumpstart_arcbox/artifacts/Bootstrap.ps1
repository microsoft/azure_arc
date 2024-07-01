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
    [string]$k3sArcDataClusterName,
    [string]$k3sArcClusterName,
    [string]$aksArcClusterName,
    [string]$aksdrArcClusterName,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$rdpPort,
    [string]$sshPort,
    [string]$vmAutologon,
    [string]$addsDomainName,
    [string]$customLocationRPOID
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername, [System.EnvironmentVariableTarget]::Machine)
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
[System.Environment]::SetEnvironmentVariable('k3sArcDataClusterName', $k3sArcDataClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('k3sArcClusterName', $k3sArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('addsDomainName', $addsDomainName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksArcClusterName', $aksArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksdrArcClusterName', $aksdrArcClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('customLocationRPOID', $customLocationRPOID, [System.EnvironmentVariableTarget]::Machine)

[System.Environment]::SetEnvironmentVariable('ArcBoxDir', "C:\ArcBox", [System.EnvironmentVariableTarget]::Machine)

# Formatting VMs disk
$disk = (Get-Disk | Where-Object partitionstyle -eq 'raw')[0]
$driveLetter = "F"
$label = "VMsDisk"
$disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
    New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -Force

# Creating ArcBox path
Write-Output "Creating ArcBox path"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxDscDir = "$Env:ArcBoxDir\DSC"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "F:\Virtual Machines"
$Env:ArcBoxKVDir = "$Env:ArcBoxDir\KeyVault"
$Env:ArcBoxGitOpsDir = "$Env:ArcBoxDir\GitOps"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$Env:agentScript = "$Env:ArcBoxDir\agentScript"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:ArcBoxDataOpsDir = "$Env:ArcBoxDir\DataOps"

New-Item -Path $Env:ArcBoxDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxDscDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxLogsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxVMDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxKVDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxGitOpsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxIconDir -ItemType directory -Force
New-Item -Path $Env:ToolsDir -ItemType Directory -Force
New-Item -Path $Env:tempDir -ItemType directory -Force
New-Item -Path $Env:agentScript -ItemType directory -Force
New-Item -Path $Env:ArcBoxDataOpsDir -ItemType directory -Force
New-Item -Path $Env:ArcBoxTestsDir -ItemType directory -Force

Start-Transcript -Path $Env:ArcBoxLogsDir\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

if ([bool]$vmAutologon) {

    Write-Host "Configuring VM Autologon"

    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" "1"
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUserName" $adminUsername
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" $adminPassword

}

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
$modules = @("Az", "Az.ConnectedMachine", "Az.ConnectedKubernetes", "Az.CustomLocation", "Azure.Arc.Jumpstart.Common", "Microsoft.PowerShell.SecretManagement", "Posh-SSH", "Pester")

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

# Temporary workaround for Posh-SSH module due to: https://github.com/darkoperator/Posh-SSH/issues/558
Install-PSResource -Name Posh-SSH -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease

# Add Key Vault Secrets
Connect-AzAccount -Identity

$KeyVault = Get-AzKeyVault -ResourceGroupName $resourceGroup

# Set Key Vault Name as an environment variable (used by DevOps flavor)
[System.Environment]::SetEnvironmentVariable('keyVaultName', $KeyVault.VaultName, [System.EnvironmentVariableTarget]::Machine)

# Import required module
Import-Module Microsoft.PowerShell.SecretManagement

# Register the Azure Key Vault as a secret vault if not already registered
# Ensure you have installed the SecretManagement and SecretStore modules along with the Key Vault extension

if (-not (Get-SecretVault -Name $KeyVault.VaultName -ErrorAction Ignore)) {
    Register-SecretVault -Name $KeyVault.VaultName -ModuleName Az.KeyVault -VaultParameters @{ AZKVaultName = $KeyVault.VaultName } -DefaultVault
}

Set-Secret -Name adminPassword -Secret $adminPassword
Set-Secret -Name AZDATAPASSWORD -Secret $azdataPassword
Set-Secret -Name registryPassword -Secret $registryPassword

Write-Output "Added the following secrets to Azure Key Vault"
Get-SecretInfo

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
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

Copy-Item $PsHome\Profile.ps1 -Destination "C:\Program Files\PowerShell\7\"

Write-Header "Fetching GitHub Artifacts"

# All flavors
Write-Host "Fetching Artifacts for All Flavors"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/arcbox_wallpaper_dark.png" -OutFile $Env:ArcBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/MonitorWorkbookLogonScript.ps1") -OutFile $Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/mgmtMonitorWorkbook.parameters.json") -OutFile $Env:ArcBoxDir\mgmtMonitorWorkbook.parameters.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/DeploymentStatus.ps1") -OutFile $Env:ArcBoxDir\DeploymentStatus.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $Env:ArcBoxLogsDir\LogInstructions.txt
Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/common.dsc.yml") -OutFile $Env:ArcBoxDscDir\common.dsc.yml
Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/virtual_machines_sql.dsc.yml") -OutFile $Env:ArcBoxDscDir\virtual_machines_sql.dsc.yml
Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/arcbox-bginfo.bgi") -OutFile $Env:ArcBoxTestsDir\arcbox-bginfo.bgi
Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/common.tests.ps1") -OutFile $Env:ArcBoxTestsDir\common.tests.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/Invoke-Test.ps1") -OutFile $Env:ArcBoxTestsDir\Invoke-Test.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/WinGet.ps1") -OutFile $Env:ArcBoxDir\WinGet.ps1
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

# ITPro
if ($flavor -eq "ITPro") {
    Write-Host "Fetching Artifacts for ITPro Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgent.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgent.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLSP.ps1") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentSQLSP.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentUbuntu.sh") -OutFile $Env:ArcBoxDir\agentScript\installArcAgentUbuntu.sh
    Invoke-WebRequest ($templateBaseUrl + "artifacts/icons/arcsql.ico") -OutFile $Env:ArcBoxIconDir\arcsql.ico
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcSQLManualOnboarding.ps1") -OutFile $Env:ArcBoxDir\ArcSQLManualOnboarding.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/installArcAgentSQLUser.ps1") -OutFile $Env:ArcBoxDir\installArcAgentSQLUser.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/SqlAdvancedThreatProtectionShell.psm1") -OutFile $Env:ArcBoxDir\SqlAdvancedThreatProtectionShell.psm1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/defendersqldcrtemplate.json") -OutFile $Env:ArcBoxDir\defendersqldcrtemplate.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/testDefenderForSQL.ps1") -OutFile $Env:ArcBoxDir\testDefenderForSQL.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/itpro.tests.ps1") -OutFile $Env:ArcBoxTestsDir\itpro.tests.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/itpro.dsc.yml") -OutFile $Env:ArcBoxDscDir\itpro.dsc.yml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/virtual_machines_itpro.dsc.yml") -OutFile $Env:ArcBoxDscDir\virtual_machines_itpro.dsc.yml
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
    Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/devops.tests.ps1") -OutFile $Env:ArcBoxTestsDir\devops.tests.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/devops.dsc.yml") -OutFile $Env:ArcBoxDscDir\devops.dsc.yml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/longhorn.yaml") -OutFile $Env:ArcBoxDir\longhorn.yaml
}

# DataOps
if ($flavor -eq "DataOps") {
    Write-Host "Fetching Artifacts for DataOps Flavor"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/ArcServersLogonScript.ps1") -OutFile $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/DataOpsLogonScript.ps1") -OutFile $Env:ArcBoxDir\DataOpsLogonScript.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/RunAfterClientVMADJoin.ps1") -OutFile $Env:ArcBoxDir\RunAfterClientVMADJoin.ps1
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
    Invoke-WebRequest ($templateBaseUrl + "artifacts/SqlAdvancedThreatProtectionShell.psm1") -OutFile $Env:ArcBoxDir\SqlAdvancedThreatProtectionShell.psm1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/defendersqldcrtemplate.json") -OutFile $Env:ArcBoxDir\defendersqldcrtemplate.json
    Invoke-WebRequest ($templateBaseUrl + "artifacts/testDefenderForSQL.ps1") -OutFile $Env:ArcBoxDir\testDefenderForSQL.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/tests/dataops.tests.ps1") -OutFile $Env:ArcBoxTestsDir\dataops.tests.ps1
    Invoke-WebRequest ($templateBaseUrl + "artifacts/dsc/dataops.dsc.yml") -OutFile $Env:ArcBoxDscDir\dataops.dsc.yml
    Invoke-WebRequest ($templateBaseUrl + "artifacts/longhorn.yaml") -OutFile $Env:ArcBoxDir\longhorn.yaml
}

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HubsSidebarEnabled'
$Value = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HideFirstRunExperience'
$Value = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Change RDP Port
Write-Host "RDP port number from configuration is $rdpPort"
if (($rdpPort -ne $null) -and ($rdpPort -ne "") -and ($rdpPort -ne "3389")) {
    Write-Host "Configuring RDP port number to $rdpPort"
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0

    # RDP port
    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host "Current RDP PortNumber: $portNumber"
    if (!($portNumber -eq $rdpPort)) {
        Write-Host Setting RDP PortNumber to $rdpPort
        Set-ItemProperty -Path $RDPTCPpath -name 'PortNumber' -Value $rdpPort
        Restart-Service TermService -force
    }

    #Setup firewall rules
    if ($rdpPort -eq 3389) {
        netsh advfirewall firewall set rule group="remote desktop" new Enable=Yes
    }
    else {
        $systemroot = get-content env:systemroot
        netsh advfirewall firewall add rule name="Remote Desktop - Custom Port" dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$RDPPort enable=yes
    }

    Write-Host "RDP port configuration complete."
}

Write-Header "Configuring Logon Scripts"

$ScheduledTaskExecutable = "pwsh.exe"


if ($flavor -eq "ITPro") {
    # Creating scheduled task for WinGet.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\WinGet.ps1
    Register-ScheduledTask -TaskName "WinGetLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
    # Creating scheduled task for ArcServersLogonScript.ps1
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Register-ScheduledTask -TaskName "ArcServersLogonScript" -User $adminUsername -Action $Action -RunLevel "Highest" -Force

}

if ($flavor -eq "DevOps") {
    # Creating scheduled task for WinGet.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\WinGet.ps1
    Register-ScheduledTask -TaskName "WinGetLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
    # Creating scheduled task for DevOpsLogonScript.ps1
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\DevOpsLogonScript.ps1
    Register-ScheduledTask -TaskName "DevOpsLogonScript" -User $adminUsername -Action $Action -RunLevel "Highest" -Force

}

if ($flavor -eq "DataOps") {

    # Joining ClientVM to AD DS domain
    if ($null -eq $addsDomainName){
        $addsDomainName = "jumpstart.local"        
    }
    
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
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Env:ArcBoxDir\RunAfterClientVMADJoin.ps1"
    Register-ScheduledTask -TaskName "RunAfterClientVMADJoin" -Trigger $Trigger -User SYSTEM -Action $Action -RunLevel "Highest" -Force
    Write-Host "Registered scheduled task 'RunAfterClientVMADJoin' to run after Client VM AD join."

    Write-Host "Joining client VM to domain"
    Add-Computer -DomainName $addsDomainName -LocalCredential $localCred -Credential $domainCred
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

    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1
    Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -User $adminUsername -Action $Action -RunLevel "Highest" -Force

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
