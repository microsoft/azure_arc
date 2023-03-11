$Env:ArcBoxDir = "C:\ArcBoxLevelup"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$agentScript = "$Env:ArcBoxDir\agentScript"

Start-Transcript -Path $Env:ArcBoxLogsDir\ArcServersLogonScript.log
$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".servers" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

# Install Azure CLI extensions
Write-Header "Az CLI extensions"
az extension add --yes --name ssh
# az extension add --yes --name connectedmachine

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.AzureArcData --wait

# Deploy SQLAdvancedThreatProtection solution to support Defender for SQL
Write-Host "Deploying SQLAdvancedThreatProtection solution to support Defender for SQL server."
# Install log-analytics-solution cli extension
az extension add --name log-analytics-solution --yes
az monitor log-analytics solution create --resource-group $Env:resourceGroup --solution-type SQLAdvancedThreatProtection --workspace $Env:workspaceName

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Header "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq "Ethernet" }
Add-DhcpServerv4Scope -Name "ArcBox" `
    -StartRange 10.10.1.100 `
    -EndRange 10.10.1.200 `
    -SubnetMask 255.255.255.0 `
    -LeaseDuration 1.00:00:00 `
    -State Active
Set-DhcpServerv4OptionValue -ComputerName localhost `
    -DnsDomain $dnsClient.ConnectionSpecificSuffix `
    -DnsServer 168.63.129.16 `
    -Router 10.10.1.1
Restart-Service dhcpserver

# Create the NAT network
Write-Header "Creating Internal NAT"
$natName = "InternalNat"
New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24

# Create an internal switch with NAT
Write-Header "Creating Internal vSwitch"
$switchName = 'InternalNATSwitch'
New-VMSwitch -Name $switchName -SwitchType Internal
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*" + $switchName + "*" }

# Create an internal network (gateway first)
Write-Header "Creating Gateway"
New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Enable Enhanced Session Mode on Host
Write-Header "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

Write-Header "Fetching Nested VMs"
$sourceFolder = 'https://jumpstartlevelup.blob.core.windows.net/luarcsqlsrv'
$sas = "?sp=rl&st=2023-02-10T00:00:00Z&se=2024-02-10T08:00:00Z&spr=https&sv=2021-06-08&sr=c&sig=MOG4q%2BzXkiPAFZguYxyLgQxKmSu2W3AZFZKbWwBJBfg%3D"
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
azcopy cp $sourceFolder/*$sas $Env:ArcBoxVMDir --recursive=true --include-pattern 'JSLU-Win-SQL-01.vhdx;JSLU-Win-SQL-02.vhdx;JSLU-Win-SQL-03.vhdx' --check-length=false --log-level=ERROR

# Create the nested VMs
Write-Header "Create Hyper-V VMs"
$JSLUWinSQL01 = "JSLU-Win-SQL-01"
New-VM -Name $JSLUWinSQL01 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${JSLUWinSQL01}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName $JSLUWinSQL01 -Count 2

$JSLUWinSQL02 = "JSLU-Win-SQL-02"
New-VM -Name $JSLUWinSQL02 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${JSLUWinSQL02}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName $JSLUWinSQL02 -Count 2

$JSLUWinSQL03 = "JSLU-Win-SQL-03"
New-VM -Name $JSLUWinSQL03 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${JSLUWinSQL03}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName $JSLUWinSQL03 -Count 2

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Header "Set VM Auto Start/Stop"
Set-VM -Name $JSLUWinSQL01 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL02 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL03 -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Header "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Header "Starting VMs"
Start-VM -Name $JSLUWinSQL01
Start-VM -Name $JSLUWinSQL02
Start-VM -Name $JSLUWinSQL03

Write-Header "Creating VM Credentials"
# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

# Restarting Windows VM Network Adapters
Write-Header "Restarting Network Adapters"
Start-Sleep -Seconds 20
Invoke-Command -VMName $JSLUWinSQL01 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Invoke-Command -VMName $JSLUWinSQL02 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Invoke-Command -VMName $JSLUWinSQL03 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Start-Sleep -Seconds 5

# Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
Write-Header "Blocking IMDS"
Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc-enabled servers"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# Check if Service Principal has 'Microsoft.Authorization/roleAssignments/write' permissions to target Resource Group
$requiredActions = @('*', 'Microsoft.Authorization/roleAssignments/write', 'Microsoft.Authorization/*', 'Microsoft.Authorization/*/write')

$roleDefinitions = az role definition list --out json | ConvertFrom-Json
$spnObjectId = az ad sp show --id $Env:spnClientID --query id -o tsv
$rolePermissions = az role assignment list --include-inherited --include-groups --scope "/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}" | ConvertFrom-Json
$authorizedRoles = $roleDefinitions | ForEach-Object { $_ | Where-Object { (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.actions | Select-Object) -ExcludeDifferent -IncludeEqual) -and -not (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.notactions | Select-Object) -ExcludeDifferent -IncludeEqual) } } | Select-Object -ExpandProperty roleName
$hasPermission = $rolePermissions | Where-Object { ($_.principalId -eq $spnObjectId) -and ($_.roleDefinitionName -in $authorizedRoles) }

# Copying the Azure Arc Connected Agent to nested VMs
if (-not $hasPermission) {
    Write-Output "Service principal doesn't have necessary permissions to onboard Arc-enabled SQL server. Please grant required permissions to service principal."
}
else {
    Write-Output "Service Principal has necessary permissions to onboard Arc-enabled SQL server."
}

Write-Header "Copying Onboarding Scripts"

# Copy installation script to nested Windows VMs
Write-Output "Transferring installation script to nested Windows VMs..."
Copy-VMFile $JSLUWinSQL01 -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL01 -SourcePath "$agentScript\installArcAgentSQLSP.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL01 -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -CreateFullPath -FileSource Host

Copy-VMFile $JSLUWinSQL02 -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL02 -SourcePath "$agentScript\installArcAgentSQLSP.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL02 -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -CreateFullPath -FileSource Host

Copy-VMFile $JSLUWinSQL03 -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL03 -SourcePath "$agentScript\installArcAgentSQLSP.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL03 -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -CreateFullPath -FileSource Host

Write-Header "Onboarding Arc-enabled Servers"

# Onboarding the nested VMs as Azure Arc-enabled servers
Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"

$nestedVMArcBoxDir = $Env:ArcBoxDir
$spnClientId = $Env:spnClientId
$spnClientSecret = $Env:spnClientSecret
$spnTenantId = $Env:spnTenantId
$subscriptionId = $env:subscriptionId
$resourceGroup = $env:resourceGroup
$azureLocation = $Env:azureLocation

#Invoke-Command -VMName $JSLUWinSQL01 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds
# Install Log Analytics extension
# Get workspace information
#$workspaceID = (az monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $Env:workspaceName --query "customerId" -o tsv)
#$workspaceKey = (az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $Env:workspaceName --query "primarySharedKey" -o tsv)

Invoke-Command -VMName $JSLUWinSQL02 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds
#az connectedmachine extension create --machine-name $JSLUWinSQL02 --name "MicrosoftMonitoringAgent" --settings "{'workspaceId':'$workspaceID'}" --protected-settings "{'workspaceKey':'$workspaceKey'}" --resource-group $resourceGroup --type-handler-version "1.0.18067.0" --type "MicrosoftMonitoringAgent" --publisher "Microsoft.EnterpriseCloud.Monitoring"

Invoke-Command -VMName $JSLUWinSQL03 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds 
#az connectedmachine extension create --machine-name $JSLUWinSQL03 --name "MicrosoftMonitoringAgent" --settings "{'workspaceId':'$workspaceID'}" --protected-settings "{'workspaceKey':'$workspaceKey'}" --resource-group $resourceGroup --type-handler-version "1.0.18067.0" --type "MicrosoftMonitoringAgent" --publisher "Microsoft.EnterpriseCloud.Monitoring"

# Creating Hyper-V Manager desktop shortcut
Write-Header "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Prepare Arc-enabled SQL server onboarding script and create shortcut on desktop if the current Service Principal doesn't have appropriate permission to onboard the VM to Azure Arc
# Changing to Jumpstart ArcBox wallpaper
# Changing to Client VM wallpaper
$imgPath="$Env:ArcBoxDir\wallpaper.png"
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

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)


# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false

# Creating SQL Server Management Studio desktop shortcut
Write-Host "`n"
Write-Host "Creating SQL Server Management Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio 18.lnk"

# Verify if shortcut already exists
if ([System.IO.File]::Exists($ShortcutFile))
{
    Write-Host "SQL Server Management Studio Desktop shortcut already exists."
}
else
{
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
    Write-Host "Created SQL Server Management Studio Desktop shortcut"
}

Stop-Transcript

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
Invoke-Expression 'cmd /c start Powershell -Command {
$RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
Start-Sleep -Seconds 5
Write-Host "`n"
Write-Host "Creating deployment logs bundle"
7z a $Env:ArcBoxLogsDir\LogsBundle-"$RandomString".zip $Env:ArcBoxLogsDir\*.log
}'
