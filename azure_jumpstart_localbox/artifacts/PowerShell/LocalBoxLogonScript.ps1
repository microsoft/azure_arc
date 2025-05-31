# Script runtime environment: Level-0 Azure virtual machine ("Client VM")
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################

# Load config file
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile

Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\LocalBoxLogonScript.log"

# Login to Azure PowerShell
Connect-AzAccount -Identity -Tenant $Env:tenantId -Subscription $Env:subscriptionId

#####################################################################
# Add RBAC permissions
#####################################################################

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
$LogsPath = "C:\LocalBox\Logs"
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

# Creating Hyper-V Manager desktop shortcut
Write-Host 'Creating Hyper-V Shortcut'
Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk' -Destination 'C:\Users\All Users\Desktop' -Force

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

Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($LocalBoxConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
foreach ($extension in $LocalBoxConfig.VSCodeExtensions) {
    $WarningPreference = "SilentlyContinue"
    code --install-extension $extension 2>&1 | Out-File -Append -FilePath ($LocalBoxConfig.Paths.LogsDir + "\Tools.log")
    $WarningPreference = "Continue"
}

#####################################################################
# Configure virtualization infrastructure
#####################################################################

# Configure storage pools and data disks
Write-Header "Configuring storage"
New-StoragePool -FriendlyName AzLocalPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
$disks = Get-StoragePool -FriendlyName AzLocalPool -IsPrimordial $False | Get-PhysicalDisk
$diskNum = $disks.Count
New-VirtualDisk -StoragePoolFriendlyName AzLocalPool -FriendlyName AzLocalDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
$vDisk = Get-VirtualDisk -FriendlyName AzLocalDisk
if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $LocalBoxConfig.HostVMDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel AzLocalData -AllocationUnitSize 64KB -FileSystem NTFS
}
elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
    $vDisk | Get-Disk | New-Partition -DriveLetter $LocalBoxConfig.HostVMDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel AzLocalData -AllocationUnitSize 64KB -FileSystem NTFS
}

Stop-Transcript

# Build Azure Local cluster
& "$Env:LocalBoxDir\New-LocalBoxCluster.ps1"

Start-Transcript -Append -Path "$($LocalBoxConfig.Paths.LogsDir)\LocalBoxLogonScript.log"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "LocalBoxLogonScript" -Confirm:$false

#Changing to Jumpstart LocalBox wallpaper

Write-Header "Changing wallpaper"

# bmp file is required for BGInfo
Convert-JSImageToBitMap -SourceFilePath "$Env:LocalBoxDir\wallpaper.png" -DestinationFilePath "$Env:LocalBoxDir\wallpaper.bmp"

Set-JSDesktopBackground -ImagePath "$Env:LocalBoxDir\wallpaper.bmp"

Write-Header "Running tests to verify infrastructure"

& "$Env:LocalBoxTestsDir\Invoke-Test.ps1"

Write-Header "Creating deployment logs bundle"

$RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
$LogsBundleTempDirectory = "$Env:windir\TEMP\LogsBundle-$RandomString"
$null = New-Item -Path $LogsBundleTempDirectory -ItemType Directory -Force

#required to avoid "file is being used by another process" error when compressing the logs
Copy-Item -Path "$($LocalBoxConfig.Paths.LogsDir)\*.log" -Destination $LogsBundleTempDirectory -Force -PassThru
Compress-Archive -Path "$LogsBundleTempDirectory\*.log" -DestinationPath "$($LocalBoxConfig.Paths.LogsDir)\LogsBundle-$RandomString.zip" -PassThru


Stop-Transcript