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
azcopy cp $sourceFolder/*$sas $Env:ArcBoxVMDir --recursive=true --include-pattern 'JSLU-*' --check-length=false --log-level=ERROR

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

$JSLUWinSQL04 = "JSLU-Win-SQL-04"
New-VM -Name $JSLUWinSQL04 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${JSLUWinSQL04}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName $JSLUWinSQL04 -Count 2

$JSLUWinSQL05 = "JSLU-Win-SQL-05"
New-VM -Name $JSLUWinSQL05 -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${JSLUWinSQL05}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
Set-VMProcessor -VMName $JSLUWinSQL05 -Count 2


# We always want the VMs to start with the host and shut down cleanly with the host
Write-Header "Set VM Auto Start/Stop"
Set-VM -Name $JSLUWinSQL01 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL02 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL03 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL04 -AutomaticStartAction Start -AutomaticStopAction ShutDown
Set-VM -Name $JSLUWinSQL05 -AutomaticStartAction Start -AutomaticStopAction ShutDown

Write-Header "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Header "Starting VMs"
Start-VM -Name $JSLUWinSQL01
Start-VM -Name $JSLUWinSQL02
Start-VM -Name $JSLUWinSQL03
Start-VM -Name $JSLUWinSQL04
Start-VM -Name $JSLUWinSQL05

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
Invoke-Command -VMName $JSLUWinSQL04 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Invoke-Command -VMName $JSLUWinSQL05 -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
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
Write-Header "Customize Onboarding Scripts"
Write-Output "Replacing values within Azure Arc connected machine agent install scripts..."
(Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModified.ps1"

# Create appropriate onboard script to SQL VM depending on whether or not the Service Principal has permission to peroperly onboard it to Azure Arc
if (-not $hasPermission) {
(Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
}
else {
(Get-Content -path "$agentScript\installArcAgentSQLSP.ps1" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$myResourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
}

Write-Header "Copying Onboarding Scripts"

# Copy installation script to nested Windows VMs
Write-Output "Transferring installation script to nested Windows VMs..."
Copy-VMFile $JSLUWinSQL01 -SourcePath "$agentScript\installArcAgentSQLModified.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL02 -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $JSLUWinSQL03 -SourcePath "$agentScript\installArcAgentModified.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force

Write-Header "Onboarding Arc-enabled Servers"

# Onboarding the nested VMs as Azure Arc-enabled servers
Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"

$nestedVMArcBoxDir = $Env:ArcBoxDir
Invoke-Command -VMName $JSLUWinSQL01 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgentSQL.ps1 } -Credential $winCreds
Invoke-Command -VMName $JSLUWinSQL02 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 } -Credential $winCreds
Invoke-Command -VMName $JSLUWinSQL03 -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 } -Credential $winCreds

# Creating Hyper-V Manager desktop shortcut
Write-Header "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Prepare Arc-enabled SQL server onboarding script and create shortcut on desktop if the current Service Principal doesn't have appropriate permission to onboard the VM to Azure Arc
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

# Enable Best practices assessment
# Create custom log analytics table for SQL assessment
$SQLvmName = $JSLUWinSQL01
az monitor log-analytics workspace table create --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName -n SqlAssessment_CL --columns RawData=string TimeGenerated=datetime

Write-Host "Enabling SQL server best practices assessment"
$bpaDeploymentTemplateUrl = "$Env:templateBaseUrl/artifacts/sqlbpa.json"
az deployment group create --resource-group $Env:resourceGroup --template-uri $bpaDeploymentTemplateUrl --parameters workspaceName=$Env:workspaceName vmName=$SQLvmName arcSubscriptionId=$Env:subscriptionId

# Run Best practices assessment
Write-Host "Execute SQL server best practices assessment"

# Wait for a minute to finish everyting and run assessment
Start-Sleep(60)

# Get access token to make ARM REST API call for SQL server BPA
$armRestApiEndpoint = "https://management.azure.com/subscriptions/$Env:subscriptionId/resourcegroups/$Env:resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer?api-version=2019-08-02-preview"
$token=(az account get-access-token --subscription $Env:subscriptionId --query accessToken --output tsv)

# Build API request payload
$worspaceResourceId = "/subscriptions/$Env:subscriptionId/resourcegroups/$Env:resourceGroup/providers/microsoft.operationalinsights/workspaces/$Env:workspaceName".ToLower()
$sqlExtensionId = "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer".ToLower()
$sqlbpaPayloadTemplate = "$Env:templateBaseUrl/artifacts/sqlbpa.payload.json"
$apiPayload = (Invoke-WebRequest -Uri $sqlbpaPayloadTemplate).Content -replace '{{RESOURCEID}}', $sqlExtensionId -replace '{{LOCATION}}', $Env:azureLocation -replace '{{WORKSPACEID}}', $worspaceResourceId

# Call REST API to run best practices assessment
$headers = @{"Authorization"="Bearer $token"; "Content-Type"="application/json"}
Invoke-WebRequest -Method Patch -Uri $armRestApiEndpoint -Body $apiPayload -Headers $headers
Write-Host "Arc-enabled SQL server best practices assessment complete. Wait for assessment to complete to view results."

# Test Defender for SQL
Write-Header "Simulating SQL threats to generate alerts from Defender for Cloud"
$remoteScriptFileFile = "$agentScript\testDefenderForSQL.ps1"
Copy-VMFile $SQLvmName -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath $remoteScriptFileFile -CreateFullPath -FileSource Host

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
