# Script runtime environment: Level-0 Azure virtual machine ("Client VM")
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################

# Load config file
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
$Env:HCIBoxTestsDir = "$Env:HCIBoxDir\Tests"

Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\HCIBoxLogonScript.log"

#####################################################################
# Setup Azure CLI and Azure PowerShell
#####################################################################

# Login to Azure CLI with service principal provided by user
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId

# Login to Azure PowerShell with service principal provided by user
$spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)
Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spntenantId -Subscription $env:subscriptionId

#####################################################################
# Register Azure providers
#####################################################################

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait
az provider register --namespace Microsoft.OperationsManagement --wait
az provider register --namespace Microsoft.AzureStackHCI --wait
az provider register --namespace Microsoft.ResourceConnector --wait

#####################################################################
# Add RBAC permissions
#####################################################################

# Add required RBAC permission required for the service principal to deploy Azure Stack HCI

Write-Header "Add required RBAC permission required for the service principal to deploy Azure Stack HCI"

$roleAssignment = Get-AzRoleAssignment -ServicePrincipalName $Env:spnClientId -Scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup" -RoleDefinitionName "Key Vault Administrator" -ErrorAction SilentlyContinue
if ($null -eq $roleAssignment) {
    New-AzRoleAssignment -RoleDefinitionName "Key Vault Administrator" -ServicePrincipalName $Env:spnClientId -Scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
}

$roleAssignment = Get-AzRoleAssignment -ServicePrincipalName $Env:spnClientId -Scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup" -RoleDefinitionName "Storage Account Contributor" -ErrorAction SilentlyContinue
if ($null -eq $roleAssignment) {
    New-AzRoleAssignment -RoleDefinitionName "Storage Account Contributor" -ServicePrincipalName $Env:spnClientId -Scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
}

#############################################################
# Remove registry keys that are used to automatically logon the user (only used for first-time setup)
#############################################################

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$keys = @("AutoAdminLogon", "DefaultUserName", "DefaultPassword")

foreach ($key in $keys) {
    try {
        $property = Get-ItemProperty -Path $registryPath -Name $key -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath -Name $key
        Write-Host "Removed registry key that are used to automatically logon the user: $key"
    } catch {
        Write-Verbose "Key $key does not exist."
    }
}

#############################################################
# Create desktop shortcut for Logs-folder
#############################################################

$WshShell = New-Object -comObject WScript.Shell
$LogsPath = "C:\HCIBox\Logs"
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

#############################################################
# Configure Windows Terminal as the default terminal application
#############################################################

$registryPath = "HKCU:\Console\%%Startup"

if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
} else {
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name "DelegationConsole" -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
    Set-ItemProperty -Path $registryPath -Name "DelegationTerminal" -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
}

#############################################################
# Install VSCode extensions
#############################################################

Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($HCIBoxConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
foreach ($extension in $HCIBoxConfig.VSCodeExtensions) {
    $WarningPreference = "SilentlyContinue"
    code --install-extension $extension 2>&1 | Out-File -Append -FilePath ($HCIBoxConfig.Paths.LogsDir + "\Tools.log")
    $WarningPreference = "Continue"
}

#####################################################################
# Configure virtualization infrastructure
#####################################################################

# Configure storage pools and data disks
Write-Header "Configuring storage"
New-StoragePool -FriendlyName AsHciPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
$disks = Get-StoragePool -FriendlyName AsHciPool -IsPrimordial $False | Get-PhysicalDisk
$diskNum = $disks.Count
New-VirtualDisk -StoragePoolFriendlyName AsHciPool -FriendlyName AsHciDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
$vDisk = Get-VirtualDisk -FriendlyName AsHciDisk
if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $HCIBoxConfig.HostVMDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}
elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
    $vDisk | Get-Disk | New-Partition -DriveLetter $HCIBoxConfig.HostVMDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}

Stop-Transcript

# Build HCI cluster
& "$Env:HCIBoxDir\New-HCIBoxCluster.ps1"

Start-Transcript -Append -Path "$($HCIBoxConfig.Paths.LogsDir)\HCIBoxLogonScript.log"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "HCIBoxLogonScript" -Confirm:$false

#Changing to Jumpstart HCIBox wallpaper

Write-Header "Changing wallpaper"

# bmp file is required for BGInfo
Convert-JSImageToBitMap -SourceFilePath "$Env:HCIBoxDir\wallpaper.png" -DestinationFilePath "$Env:HCIBoxDir\wallpaper.bmp"

Set-JSDesktopBackground -ImagePath "$Env:HCIBoxDir\wallpaper.bmp"

Write-Header "Running tests to verify infrastructure"

& "$Env:HCIBoxTestsDir\Invoke-Test.ps1"

Write-Header "Creating deployment logs bundle"

$RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
$LogsBundleTempDirectory = "$Env:windir\TEMP\LogsBundle-$RandomString"
$null = New-Item -Path $LogsBundleTempDirectory -ItemType Directory -Force

#required to avoid "file is being used by another process" error when compressing the logs
Copy-Item -Path "$($HCIBoxConfig.Paths.LogsDir)\*.log" -Destination $LogsBundleTempDirectory -Force -PassThru
Compress-Archive -Path "$LogsBundleTempDirectory\*.log" -DestinationPath "$($HCIBoxConfig.Paths.LogsDir)\LogsBundle-$RandomString.zip" -PassThru


Stop-Transcript