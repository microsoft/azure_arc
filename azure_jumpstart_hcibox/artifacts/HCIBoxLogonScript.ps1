# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxGitOpsDir = "C:\HCIBox\GitOps"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

Start-Transcript -Path $Env:HCIBoxLogsDir\HCIBoxLogonScript.log

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".servers" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Configure storage pools and data disks
Write-Header "Configuring storage"
New-StoragePool -FriendlyName AsHciPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
$disks = Get-StoragePool -FriendlyName AsHciPool -IsPrimordial $False | Get-PhysicalDisk
$diskNum = $disks.Count
New-VirtualDisk -StoragePoolFriendlyName AsHciPool -FriendlyName AsHciDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
$vDisk = Get-VirtualDisk -FriendlyName AsHciDisk
if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter V -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}
elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
    $vDisk | Get-Disk | New-Partition -DriveLetter V -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
}
New-Item -Path "V:\" -Name "VMs" -ItemType "directory"

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId

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