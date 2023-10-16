# Script runtime environment: Level-0 Azure virtual machine ("Client VM")
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################

# Load config file
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile

Start-Transcript -Path $HCIBoxConfig.HCIBoxPaths["LogsDir"]\HCIBoxLogonScript.log

#####################################################################
# Setup Azure CLI
#####################################################################
$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".servers" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Login to Azure CLI with service principal provided by user
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

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

#############################################################
# Install VSCode extensions
#############################################################

Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($HCIBoxConfig.VSCodeExtensions -join ', ') -ForegroundColor Gray
foreach ($extension in $AgConfig.VSCodeExtensions) {
    code --install-extension $extension 2>&1 | Out-File -Append -FilePath ($HCIBoxConfig.HCIBoxPaths["LogsDir"] + "\Tools.log")
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
New-Item -Path "V:\" -Name "VMs" -ItemType "directory"






Stop-Transcript

# Build HCI cluster
Write-Header "Deploying HCI cluster"
& "$Env:HCIBoxDir\New-HCIBoxCluster.ps1"

# Register HCI cluster
if ($env:registerCluster -eq $true) {
    Write-Header "Registering HCI cluster"
    & "$Env:HCIBoxDir\Register-AzSHCI.ps1"
}

# deploy AKS
if (($env:registerCluster -eq $true) -and ($env:deployAKSHCI -eq $true)) {
    Write-Header "Deploying AKS"
    & "$Env:HCIBoxDir\Deploy-AKS.ps1"
}

# Deploy Arc Resource Bridge
if (($env:registerCluster -eq $true) -and ($env:deployResourceBridge -eq $true)) {
    Write-Header "Deploying Arc Resource Bridge"
    & "$Env:HCIBoxDir\Deploy-ArcResourceBridge.ps1"
}

Start-Transcript -Append -Path $Env:HCIBoxLogsDir\HCIBoxLogonScript.log

# Changing to Jumpstart ArcBox wallpaper
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
    public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
            static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
            
            public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
            }
        }
    } 
'@

Write-Header "Changing Wallpaper"
$imgPath="$Env:HCIBoxDir\wallpaper.png"
Add-Type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "HCIBoxLogonScript" -Confirm:$false

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:HCIBoxLogsDir\LogsBundle-"$RandomString".zip $Env:HCIBoxLogsDir\*.log
}'

Stop-Transcript