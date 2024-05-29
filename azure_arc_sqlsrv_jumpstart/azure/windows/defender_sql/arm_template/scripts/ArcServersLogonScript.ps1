$Env:ArcJSDir = "C:\Jumpstart"
$Env:ArcJSLogsDir = "$Env:ArcJSDir\Logs"
$Env:ArcJSVMDir = "$Env:ArcJSDir\VirtualMachines"
$Env:ArcJSIconDir = "$Env:ArcJSDir\Icons"
$agentScriptDir = "$Env:ArcJSDir\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"

# VHD storage details
$sourceFolder = "https://jsvhds.blob.core.windows.net/scenarios/prod"

$logFilePath = "$Env:ArcJSLogsDir\ArcServersLogonScript.log"
if ([System.IO.File]::Exists($logFilePath)) {
    $archivefile = "$Env:ArcJSLogsDir\ArcServersLogonScript-" + (Get-Date -Format "yyyyMMddHHmmss")
    Rename-Item -Path $logFilePath -NewName $archivefile -Force
}

Start-Transcript -Path $logFilePath

$cliDirPath = "$Env:ArcJSDir\.cli\.servers"
if (![System.IO.Directory]::Exists($cliDirPath)) {
    $cliDir = New-Item -Path "$Env:ArcJSDir\.cli\" -Name ".servers" -ItemType Directory
}
else {
    $cliDir = Get-Item -Path $cliDirPath
}

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az config set extension.use_dynamic_install=yes_without_prompt
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.AzureArcData --wait
az provider register --namespace Microsoft.OperationsManagement --wait

#Install az extions
az extension add --name log-analytics-solution --yes --only-show-errors
az extension add --name connectedmachine --yes --only-show-errors
az extension add --name monitor-control-service --yes --only-show-errors

# Enable defender for cloud
Write-Header "Enabling defender for cloud for SQL Server at the subscription level"
$laWorkspaceId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$env:workspaceName"

$currentsqlplan = (az security pricing show -n SqlServerVirtualMachines --subscription $env:subscriptionId | ConvertFrom-Json)
if ($currentsqlplan.pricingTier -eq "Free") {
    az security pricing create -n SqlServerVirtualMachines --tier 'standard'
}
else {
    Write-Host "Current Defender for SQL plan at the subscription level is: $($currentsqlplan.pricingTier)"
}

# Set defender for cloud log analytics workspace
Write-Host "Updating Log Analytics workspacespace for defender for cloud for SQL Server"
az security workspace-setting create -n default --target-workspace $laWorkspaceId

#Install SQLAdvancedThreatProtection solution
az monitor log-analytics solution create --resource-group $env:resourceGroup --solution-type SQLAdvancedThreatProtection --workspace $Env:workspaceName --only-show-errors

#Install SQLVulnerabilityAssessment solution
az monitor log-analytics solution create --resource-group $env:resourceGroup --solution-type SQLVulnerabilityAssessment --workspace $Env:workspaceName --only-show-errors

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Header "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object {$_.InterfaceAlias -eq "Ethernet" }
$dhcpScope = Get-DhcpServerv4Scope
if ($dhcpScope.Name -ne "ArcJS") {
    Add-DhcpServerv4Scope -Name "ArcJS" `
                        -StartRange 10.10.1.100 `
                        -EndRange 10.10.1.200 `
                        -SubnetMask 255.255.255.0 `
                        -LeaseDuration 1.00:00:00 `
                        -State Active
}

$dhcpOptions = Get-DhcpServerv4OptionValue                      
if ($dhcpOptions.Count -lt 3) {
    Set-DhcpServerv4OptionValue -ComputerName localhost `
                            -DnsDomain $dnsClient.ConnectionSpecificSuffix `
                            -DnsServer 168.63.129.16 `
                            -Router 10.10.1.1
    Restart-Service dhcpserver
}

# Create the NAT network
Write-Header "Creating Internal NAT"
$natName = "InternalNat"
$netNat = Get-NetNat
if ($netNat.Name -ne $natName) {
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24
}

# Create an internal switch with NAT
Write-Header "Creating Internal vSwitch"
$switchName = 'InternalNATSwitch'

# Verify if internal switch is already created, if not create a new switch
$inernalSwitch = Get-VMSwitch
if ($inernalSwitch.Name -ne $switchName) {
    New-VMSwitch -Name $switchName -SwitchType Internal
    $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*"+$switchName+"*" }

        # Create an internal network (gateway first)
    Write-Header "Creating Gateway"
    New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

    # Enable Enhanced Session Mode on Host
    Write-Header "Enabling Enhanced Session Mode"
    Set-VMHost -EnableEnhancedSessionMode $true
}

Write-Header "Creating VM Credentials"
# Hard-coded username and password for the nested VM
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "JS123!!"

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

Write-Header "Fetching Nested VMs"
$Env:AZCOPY_BUFFER_GB=4

# Other ArcJS flavors does not have an azcopy network throughput capping
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
$vhdImageToDownload = "JSSQL19Base.vhdx"
if ($Env:sqlServerEdition -eq "Standard"){
    $vhdImageToDownload = "JSSQLStd19Base.vhdx"
}
elseif ($Env:sqlServerEdition -eq "Enterprise"){
    $vhdImageToDownload = "JSSQLEnt19Base.vhdx"
}

$SQLvmvhdPath = "$Env:ArcJSVMDir\JS-Win-SQL-01.vhdx"
if (!([System.IO.File]::Exists($SQLvmvhdPath) )) {
    $vhdImageUrl = "$sourceFolder/$vhdImageToDownload"
    azcopy cp $vhdImageUrl $SQLvmvhdPath --recursive=true --check-length=false --log-level=ERROR
}

# Create the nested VMs
Write-Header "Create Hyper-V VMs"
$JSWinSQLVMName = "JS-Win-SQL-01"
if ((Get-VM -Name $JSWinSQLVMName -ErrorAction SilentlyContinue).State -ne "Running") {
    Remove-VM -Name $JSWinSQLVMName -Force -ErrorAction SilentlyContinue
    New-VM -Name $JSWinSQLVMName -MemoryStartupBytes 8GB -BootDevice VHD -VHDPath $SQLvmvhdPath -Path $Env:ArcJSVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $JSWinSQLVMName -Count 2

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Header "Set VM Auto Start/Stop"
    Set-VM -Name $JSWinSQLVMName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Header "Enabling Guest Integration Service"
    Get-VM | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

    # Start the VM
    Write-Header "Starting VM"
    Start-VM -Name $JSWinSQLVMName
}

# Restarting Windows VM Network Adapters
Write-Header "Restarting Network Adapters"
Start-Sleep -Seconds 20
Invoke-Command -VMName $JSWinSQLVMName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Start-Sleep -Seconds 5

# Rename hostname from ArcBox-SQL to JS-Win-SQL-01
Invoke-Command -VMName $JSWinSQLVMName -ScriptBlock { 
    $ComputerInfo = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerInfo.Rename($Using:JSWinSQLVMName) 
} -Credential $winCreds

# Restart VM after rename
Restart-VM -VMName $JSWinSQLVMName -Force -Wait

# Configure the Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
Write-Header "Blocking IMDS"
Write-Output "Configure the ArcJS VM to allow the nested VMs onboard as Azure Arc-enabled servers"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose

if (!(Get-NetFirewallRule -Name BlockAzureIMDS -ErrorAction SilentlyContinue).Enabled) {
    New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254
}

# Copying the Azure Arc Connected Agent to nested VMs
# Onboarding the nested VMs as Azure Arc-enabled servers
Write-Output "Onboarding the nested Windows VM as Azure Arc-enabled servers"
$nestedVMArcJSDir = $Env:ArcJSDir
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup

$remoteScriptFileFile = "$agentScriptDir\installArcAgentSQL.ps1"
Copy-VMFile $JSWinSQLVMName -SourcePath "$agentScriptDir\installArcAgentSQLSP.ps1" -DestinationPath "$nestedVMArcJSDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
Invoke-Command -VMName $JSWinSQLVMName -ScriptBlock { powershell -File $Using:nestedVMArcJSDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds

# Install Azure Monitor Agent extension
Write-Host "Installing Azure Monitor Agent extension"
az connectedmachine extension create --machine-name $JSWinSQLVMName --name AzureMonitorWindowsAgent --publisher Microsoft.Azure.Monitor --type AzureMonitorWindowsAgent --resource-group $resourceGroup --location $env:azureLocation
Write-Host "Azure Monitor Agent extension installation completed"

# Install AdvancedThreatProtection extension
Write-Host "Installing AdvancedThreatProtection extension"
az connectedmachine extension create --machine-name $JSWinSQLVMName --name AzureDefenderForSQLATP --publisher Microsoft.Azure.AzureDefenderForSQL --type "AdvancedThreatProtection.Windows" --resource-group $resourceGroup --location $env:azureLocation
Write-Host "AdvancedThreatProtection extension installation completed"

# Update Azure Monitor data collection rule template with Log Analytics workspace resource ID
$sqlDefenderDcrFile = "$Env:ArcJSDir\defendersqldcrtemplate.json"
(Get-Content -Path $sqlDefenderDcrFile) -replace '{LOGANLYTICS_WORKSPACEID}', $laWorkspaceId | Set-Content -Path $sqlDefenderDcrFile

# Create data collection rules for Defender for SQL
Write-Host "Creating Azure Monitor data collection rule"
$dcrName = "Jumpstart-DefenderForSQL-DCR"
az monitor data-collection rule create --resource-group $resourceGroup --location $env:azureLocation --name $dcrName --rule-file $sqlDefenderDcrFile

# Associate DCR with Azure Arc-enabled Server resource
Write-Host "Creating Azure Monitor data collection rule assocation for Arc-enabled server"
$dcrRuleId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"
$azConnectedMachineId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.HybridCompute/machines/$JSWinSQLVMName"
az monitor data-collection rule association create --name "$JSWinSQLVMName-DefenderForSQL-DCR-Association" --rule-id $dcrRuleId --resource $azConnectedMachineId

# Test Defender for SQL
Write-Header "Simulating SQL threats to generate alerts from Defender for Cloud"
$remoteScriptFileFile = "$agentScriptDir\testDefenderForSQL.ps1"
Copy-VMFile $JSWinSQLVMName -SourcePath "$Env:ArcJSDir\SqlAdvancedThreatProtectionShell.psm1" -DestinationPath "$agentScriptDir\SqlAdvancedThreatProtectionShell.psm1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSWinSQLVMName -SourcePath "$Env:ArcJSDir\testDefenderForSQL.ps1" -DestinationPath $remoteScriptFileFile -CreateFullPath -FileSource Host -Force
Invoke-Command -VMName $JSWinSQLVMName -ScriptBlock { powershell -File $Using:remoteScriptFileFile -workingDir $using:agentScriptDir} -Credential $winCreds

# Creating Hyper-V Manager desktop shortcut
Write-Header "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Changing to Client VM wallpaper
$imgPath="$Env:TempDir\wallpaper.png"
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
if ($null -ne (Get-ScheduledTask -TaskName "ArcServersLogonScript" -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false
}

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:ArcJSLogsDir\LogsBundle-"$RandomString".zip $Env:ArcJSLogsDir\*.log
}'

Stop-Transcript