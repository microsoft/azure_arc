$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "C:\ArcBox\Icons"
$agentScript = "$Env:ArcBoxDir\agentScript"

Start-Transcript -Path $Env:ArcBoxLogsDir\ArcServersLogonScript.log

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".servers" -ItemType Directory

if(-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.GuestConfiguration --wait

# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Header "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object {$_.InterfaceAlias -eq "Ethernet" }
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
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*"+$switchName+"*" }

# Create an internal network (gateway first)
Write-Header "Creating Gateway"
New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

# Enable Enhanced Session Mode on Host
Write-Header "Enabling Enhanced Session Mode"
Set-VMHost -EnableEnhancedSessionMode $true

Write-Header "Fetching Nested VMs"
$sourceFolder = 'https://jumpstart.blob.core.windows.net/v2images'
$sas = "?sp=rl&st=2022-01-27T01:47:01Z&se=2025-01-27T09:47:01Z&spr=https&sv=2020-08-04&sr=c&sig=NB8g7f4JT3IM%2FL6bUfjFdmnGIqcc8WU015socFtkLYc%3D"
$Env:AZCOPY_BUFFER_GB=4

# Other ArcBox flavors does not have an azcopy network throughput capping
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
azcopy cp $sourceFolder/*$sas $Env:ArcBoxVMDir --recursive=true --check-length=false --log-level=ERROR

# Create the nested VMs
Write-Header "Create Hyper-V VMs"
New-VM -Name ArcBox-SQL -MemoryStartupBytes 8GB -BootDevice VHD -VHDPath "$Env:ArcBoxVMDir\ArcBox-SQL.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName ArcBox-SQL -Count 2

# We always want the VMs to start with the host and shut down cleanly with the host
Write-Header "Set VM Auto Start/Stop"
Set-VM -Name ArcBox-SQL -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Header "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Header "Starting VMs"
Start-VM -Name ArcBox-SQL

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
Invoke-Command -VMName ArcBox-SQL -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
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
$hasPermission = $rolePermissions | Where-Object {($_.principalId -eq $spnObjectId) -and ($_.roleDefinitionName -in $authorizedRoles)}

# Copying the Azure Arc Connected Agent to nested VMs
Write-Header "Customize Onboarding Scripts"
Write-Output "Replacing values within Azure Arc connected machine agent install scripts..."
(Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId',"'$Env:spnClientId'" -replace '\$spnClientSecret',"'$Env:spnClientSecret'" -replace '\$resourceGroup',"'$Env:resourceGroup'" -replace '\$spnTenantId',"'$Env:spnTenantId'" -replace '\$azureLocation',"'$Env:azureLocation'" -replace '\$subscriptionId',"'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModified.ps1"

# Create appropriate onboard script to SQL VM depending on whether or not the Service Principal has permission to peroperly onboard it to Azure Arc
if(-not $hasPermission) {
    (Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId',"'$Env:spnClientId'" -replace '\$spnClientSecret',"'$Env:spnClientSecret'" -replace '\$resourceGroup',"'$Env:resourceGroup'" -replace '\$spnTenantId',"'$Env:spnTenantId'" -replace '\$azureLocation',"'$Env:azureLocation'" -replace '\$subscriptionId',"'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
} else {
    (Get-Content -path "$agentScript\installArcAgentSQLSP.ps1" -Raw) -replace '\$spnClientId',"'$Env:spnClientId'" -replace '\$spnClientSecret',"'$Env:spnClientSecret'" -replace '\$myResourceGroup',"'$Env:resourceGroup'" -replace '\$spnTenantId',"'$Env:spnTenantId'" -replace '\$azureLocation',"'$Env:azureLocation'" -replace '\$subscriptionId',"'$Env:subscriptionId'" -replace '\$logAnalyticsWorkspaceName',"'$Env:workspaceName'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
}

Write-Header "Copying Onboarding Scripts"

# Copy installtion script to nested Windows VMs
Write-Output "Transferring installation script to nested Windows VMs..."
Copy-VMFile ArcBox-SQL -SourcePath "$agentScript\installArcAgentSQLModified.ps1" -DestinationPath C:\ArcBox\installArcAgentSQL.ps1 -CreateFullPath -FileSource Host

Write-Header "Onboarding Arc-enabled Servers"

# Onboarding the nested VMs as Azure Arc-enabled servers
Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"

Invoke-Command -VMName ArcBox-SQL -ScriptBlock { powershell -File C:\ArcBox\installArcAgentSQL.ps1 } -Credential $winCreds

# Creating Hyper-V Manager desktop shortcut
Write-Header "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Prepare ArcBox-SQL onboarding script and create shortcut on desktop if the current Service Principal doesn't have appropriate permission to onboard the VM to Azure Arc
if(-not $hasPermission) {
    Write-Header "Creating Arc-enabled SQL Shortcut"

    # Replace variables in Arc-enabled SQL onboarding scripts
    $sqlServerName = "ArcBox-SQL"

    (Get-Content -path "$Env:ArcBoxDir\installArcAgentSQLUser.ps1" -Raw) -replace '<subscriptionId>',"$Env:subscriptionId" -replace '<resourceGroup>',"$Env:resourceGroup" -replace '<location>',"$Env:azureLocation" | Set-Content -Path "$Env:ArcBoxDir\installArcAgentSQLUser.ps1"
    (Get-Content -path "$Env:ArcBoxDir\ArcSQLManualOnboarding.ps1" -Raw) -replace '<subscriptionId>',"$Env:subscriptionId" -replace '<resourceGroup>',"$Env:resourceGroup" -replace '<sqlServerName>',"$sqlServerName" | Set-Content -Path "$Env:ArcBoxDir\ArcSQLManualOnboarding.ps1"

    # Set Edge as the Default Browser
    & SetDefaultBrowser.exe HKLM "Microsoft Edge"

    # Disable Edge 'First Run' Setup
    $edgePolicyRegistryPath  = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
    $desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
    $firstRunRegistryName  = 'HideFirstRunExperience'
    $firstRunRegistryValue = '0x00000001'
    $savePasswordRegistryName = 'PasswordManagerEnabled'
    $savePasswordRegistryValue = '0x00000000'
    $autoArrangeRegistryName = 'FFlags'
    $autoArrangeRegistryValue = '1075839525'

    If (-NOT (Test-Path -Path $edgePolicyRegistryPath)) {
        New-Item -Path $edgePolicyRegistryPath -Force | Out-Null
    }

    New-ItemProperty -Path $edgePolicyRegistryPath -Name $firstRunRegistryName -Value $firstRunRegistryValue -PropertyType DWORD -Force
    New-ItemProperty -Path $edgePolicyRegistryPath -Name $savePasswordRegistryName -Value $savePasswordRegistryValue -PropertyType DWORD -Force
    Set-ItemProperty -Path $desktopSettingsRegistryPath -Name $autoArrangeRegistryName -Value $autoArrangeRegistryValue -Force

    # Creating Arc-enabled SQL Server onboarding desktop shortcut
    $sourceFileLocation = "${Env:ArcBoxDir}\ArcSQLManualOnboarding.ps1"
    $shortcutLocation = "$Env:Public\Desktop\Onboard SQL Server.lnk"
    $wScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File $sourceFileLocation"
    $shortcut.IconLocation="${Env:ArcBoxIconDir}\arcsql.ico, 0"
    $shortcut.WindowStyle = 3
    $shortcut.Save()
}

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

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false

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
