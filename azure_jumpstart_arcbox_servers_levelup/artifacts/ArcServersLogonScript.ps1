$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$agentScript = "$Env:ArcBoxDir\agentScript"

# Set variables to execute remote powershell scripts on guest VMs
$nestedVMArcBoxDir = $Env:ArcBoxDir
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup

# Moved VHD storage account details here to keep only in place to prevent duplicates.
#$vhdSourceFolder = "https://jsvhds.blob.core.windows.net/arcbox"
#$sas = "*?si=ArcBox-RL&spr=https&sv=2022-11-02&sr=c&sig=vg8VRjM00Ya%2FGa5izAq3b0axMpR4ylsLsQ8ap3BhrnA%3D"

# Change to use the level-up CDN for VHDs

$usLocations = @('eastus', 'eastus2', 'centralus', 'westus2')
$europeLocations = @('northeurope', 'westeurope', 'francecentral', 'uksouth')
$apacLocations = @( 'southeastasia', 'australiaeast', 'japaneast', 'koreacentral')

# Archive exising log file and crate new one
$logFilePath = "$Env:ArcBoxLogsDir\ArcServersLogonScript.log"
if ([System.IO.File]::Exists($logFilePath)) {
    $archivefile = "$Env:ArcBoxLogsDir\ArcServersLogonScript-" + (Get-Date -Format "yyyyMMddHHmmss")
    Rename-Item -Path $logFilePath -NewName $archivefile -Force
}

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

################################################
# Setup Hyper-V server before deploying VMs for each flavor
################################################
# Install and configure DHCP service (used by Hyper-V nested VMs)
Write-Host "Configuring DHCP Service"
$dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq "Ethernet" }
$dhcpScope = Get-DhcpServerv4Scope
if ($dhcpScope.Name -ne "ArcBox") {
    Add-DhcpServerv4Scope -Name "ArcBox" `
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
        -DnsServer 168.63.129.16, 10.16.2.100 `
        -Router 10.10.1.1 `
        -Force
}

# Create the NAT network
Write-Host "Creating Internal NAT"
$natName = "InternalNat"
$netNat = Get-NetNat
if ($netNat.Name -ne $natName) {
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24
}

# Create an internal switch with NAT
Write-Host "Creating Internal vSwitch"
$switchName = 'InternalNATSwitch'

# Verify if internal switch is already created, if not create a new switch
$inernalSwitch = Get-VMSwitch
if ($inernalSwitch.Name -ne $switchName) {
    New-VMSwitch -Name $switchName -SwitchType Internal
    $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*" + $switchName + "*" }

    # Create an internal network (gateway first)
    Write-Host "Creating Gateway"
    New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

    # Enable Enhanced Session Mode on Host
    Write-Host "Enabling Enhanced Session Mode"
    Set-VMHost -EnableEnhancedSessionMode $true
}

Write-Host "Creating VM Credentials"
# Hard-coded username and password for the nested VMs
$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

# Create Windows credential object
$secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
$winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

# Creating Hyper-V Manager desktop shortcut
Write-Host "Creating Hyper-V Shortcut"
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

# Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
Write-Header "Blocking IMDS"
Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc-enabled servers"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose

if (!(Get-NetFirewallRule -Name BlockAzureIMDS -ErrorAction SilentlyContinue).Enabled) {
    New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254
}

$cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name ".servers" -ItemType Directory -Force
if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Install Azure CLI extensions
Write-Header "Az CLI extensions"
az extension add --name ssh --yes --only-show-errors
az extension add --name log-analytics-solution --yes --only-show-errors
az extension add --name connectedmachine --yes --only-show-errors

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $spnClientId --password=$spnClientSecret --tenant $spnTenantId

az account set -s $subscriptionId

# Connect to azure using azure powershell
$SecurePassword = ConvertTo-SecureString -String $spnClientSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spnClientId, $SecurePassword
Connect-AzAccount -ServicePrincipal -TenantId $spnTenantId -Credential $Credential

Set-AzContext -Subscription $subscriptionId -tenant $spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.HybridCompute --wait --only-show-errors
az provider register --namespace Microsoft.HybridConnectivity --wait --only-show-errors
az provider register --namespace Microsoft.GuestConfiguration --wait --only-show-errors
az provider register --namespace Microsoft.AzureArcData --wait --only-show-errors

Write-Header "Fetching Nested VMs"

$Win2k19vmName = "ArcBox-Win2K19"
$win2k19vmvhdPath = "${Env:ArcBoxVMDir}\${Win2k19vmName}.vhdx"

$Win2k22vmName = "ArcBox-Win2K22"
$Win2k22vmvhdPath = "${Env:ArcBoxVMDir}\${Win2k22vmName}.vhdx"

$Ubuntu01vmName = "ArcBox-Ubuntu-01"
$Ubuntu01vmvhdPath = "${Env:ArcBoxVMDir}\${Ubuntu01vmName}.vhdx"

$Ubuntu02vmName = "ArcBox-Ubuntu-02"
$Ubuntu02vmvhdPath = "${Env:ArcBoxVMDir}\${Ubuntu02vmName}.vhdx"

# Verify if VHD files already downloaded especially when re-running this script
if (!([System.IO.File]::Exists($win2k19vmvhdPath) -and [System.IO.File]::Exists($Win2k22vmvhdPath) -and [System.IO.File]::Exists($Ubuntu01vmvhdPath) -and [System.IO.File]::Exists($Ubuntu02vmvhdPath))) {
    <# Action when all if and elseif conditions are false #>
    $Env:AZCOPY_BUFFER_GB = 4
    # Other ArcBox flavors does not have an azcopy network throughput capping
    Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."

    switch ($azureLocation) {
        "eastus2" {
            $vhdSourceFolder = "https://jsvhdslevelupeus2.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=1eyW6VmrDzlJNsFSssBCoyNH4i6zt5mSvcuVgFuPv%2BM%3D"
        }
        "eastus" {
            $vhdSourceFolder = "https://jsvhdslevelup.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=X9L09UCkIaDNWHh6AsDKQ%2Fc%2BZrRBMnMV1uBhT2zrdLE%3D"
        }
        "westeus2" {
            $vhdSourceFolder = "https://jsvhdslevelupwus2.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=SlV3WhjWTty%2Bb3xRs3ah50CPbeirU%2FwMk6zlQf5XP80%3D"
        }
        "southeastasia" {
            $vhdSourceFolder = "https://jsvhdslevelupapac.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=9gZdHXNd6CXmkKG0NZjDhzT9ACELpsYGcRIbzlyLfJg%3D"
        }
        "australiaeast" {
            $vhdSourceFolder = "https://jsvhdslevelupausteast.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=GEkCDlxRclmP4NcuXHr1OFC7UoKwMJRLGolfGnTIYrk%3D"
        }
        "japaneast" {
            $vhdSourceFolder = "https://jsvhdslevelupjapaneast.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=%2Bhl6euOEP0xw2OCDwViLuRy8wShfThb62%2F9dkEsJBao%3D"

        }
        "westeurope" {
            $vhdSourceFolder = "https://jsvhdslevelupeurope.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=Uz0fPIEfBsKglScotYtEnAATSTx187DzyE2gNXV40y4%3D"
        }
        "northeurope" {
            $vhdSourceFolder = "https://jsvhdslevelupnortheu.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=ldvkO%2FWUJsNV%2FvFVjyMGtORZzeHA4QZN75ipkeT5T94%3D"
        }
        Default {
            $vhdSourceFolder = "https://jsvhdslevelup.blob.core.windows.net/arcbox"
            $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=X9L09UCkIaDNWHh6AsDKQ%2Fc%2BZrRBMnMV1uBhT2zrdLE%3D"
        }
    }

    <#if ($apacLocations -contains $azureLocation) {
        # APAC Storage account
        $vhdSourceFolder = "https://jsvhdslevelupapac.blob.core.windows.net/arcbox"
        $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=9gZdHXNd6CXmkKG0NZjDhzT9ACELpsYGcRIbzlyLfJg%3D"
    } elseif ($europeLocations -contains $azureLocation) {
        $vhdSourceFolder = "https://jsvhdslevelupeurope.blob.core.windows.net/arcbox"
        $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=Uz0fPIEfBsKglScotYtEnAATSTx187DzyE2gNXV40y4%3D"
    } else {
        $vhdSourceFolder = "https://jsvhdslevelup.blob.core.windows.net/arcbox"
        $sas = "*?si=jsvhds-sas-policy&spr=https&sv=2022-11-02&sr=c&sig=X9L09UCkIaDNWHh6AsDKQ%2Fc%2BZrRBMnMV1uBhT2zrdLE%3D"
    }#>
    azcopy cp $vhdSourceFolder/$sas $Env:ArcBoxVMDir --include-pattern "${Win2k19vmName}.vhdx;${Win2k22vmName}.vhdx;${Ubuntu01vmName}.vhdx;${Ubuntu02vmName}.vhdx;" --recursive=true --check-length=false --cap-mbps 1200 --log-level=ERROR --check-md5 NoCheck
}

# Create the nested VMs if not already created
Write-Header "Create Hyper-V VMs"

# Check if VM already exists
if ((Get-VM -Name $Win2k19vmName -ErrorAction SilentlyContinue).State -ne "Running") {
    Remove-VM -Name $Win2k19vmName -Force -ErrorAction SilentlyContinue
    New-VM -Name $Win2k19vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $win2k19vmvhdPath -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $Win2k19vmName -Count 2
    Set-VM -Name $Win2k19vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
}

if ((Get-VM -Name $Win2k22vmName -ErrorAction SilentlyContinue).State -ne "Running") {
    Remove-VM -Name $Win2k22vmName -Force -ErrorAction SilentlyContinue
    New-VM -Name $Win2k22vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $Win2k22vmvhdPath -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $Win2k22vmName -Count 2
    Set-VM -Name $Win2k22vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
}

if ((Get-VM -Name $Ubuntu01vmName -ErrorAction SilentlyContinue).State -ne "Running") {
    Remove-VM -Name $Ubuntu01vmName -Force -ErrorAction SilentlyContinue
    New-VM -Name $Ubuntu01vmName -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath $Ubuntu01vmvhdPath -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMFirmware -VMName $Ubuntu01vmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    Set-VMProcessor -VMName $Ubuntu01vmName -Count 1
    Set-VM -Name $Ubuntu01vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
}

if ((Get-VM -Name $Ubuntu02vmName -ErrorAction SilentlyContinue).State -ne "Running") {
    Remove-VM -Name $Ubuntu02vmName -Force -ErrorAction SilentlyContinue
    New-VM -Name $Ubuntu02vmName -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath $Ubuntu02vmvhdPath -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMFirmware -VMName $Ubuntu02vmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    Set-VMProcessor -VMName $Ubuntu02vmName -Count 1
    Set-VM -Name $Ubuntu02vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
}

Write-Header "Enabling Guest Integration Service"
Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

# Start all the VMs
Write-Header "Starting VMs"\
Start-VM -Name $Win2k19vmName
Start-VM -Name $Win2k22vmName
Start-VM -Name $Ubuntu01vmName
Start-VM -Name $Ubuntu02vmName

Write-Header "Creating VM Credentials"
# Hard-coded username and password for the nested VMs
$nestedLinuxUsername = "arcdemo"
$nestedLinuxPassword = "ArcDemo123!!"

# Create Linux credential object
$secLinuxPassword = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
$linCreds = New-Object System.Management.Automation.PSCredential ($nestedLinuxUsername, $secLinuxPassword)

# Restarting Windows VM Network Adapters
Write-Header "Restarting Network Adapters"
Start-Sleep -Seconds 20
Invoke-Command -VMName $Win2k19vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
Start-Sleep -Seconds 5

# Getting the Ubuntu nested VM IP address
$Ubuntu01VmIp = Get-VM -Name $Ubuntu01vmName | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0
$Ubuntu02VmIp = Get-VM -Name $Ubuntu02vmName | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0

# Copy installation script to nested Windows VMs
Write-Output "Transferring installation script to nested Windows VMs..."
Copy-VMFile $Win2k19vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
Copy-VMFile $Win2k22vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force

(Get-Content -path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"

# Copy installation script to nested Linux VMs
Write-Output "Transferring installation script to nested Linux VMs..."
Set-SCPItem -ComputerName $Ubuntu01VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force
Set-SCPItem -ComputerName $Ubuntu02VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force

Write-Header "Onboarding Arc-enabled servers"

# Onboarding the nested VMs as Azure Arc-enabled servers

$Ubuntu02vmvhdPath = "${Env:ArcBoxVMDir}\${Ubuntu02vmName}.vhdx"
Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
Invoke-Command -VMName $Win2k19vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds
#Invoke-Command -VMName $Win2k22vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

Write-Header "Installing the Azure Monitor Agent on the Windows Arc-enabled server"
#az connectedmachine extension create --name AzureMonitorWindowsAgent `
#                                     --publisher Microsoft.Azure.Monitor `
#                                     --type AzureMonitorWindowsAgent `
#                                     --machine-name $Win2k19vmName `
#                                     --resource-group $resourceGroup `
#                                     --location $azureLocation `
#                                     --enable-auto-upgrade true `
#                                     --no-wait

# Test Defender for Servers
Write-Header "Simulating threats to generate alerts from Defender for Cloud"
$remoteScriptFile = "$agentScript\testDefenderForServers.ps1"
Copy-VMFile $Win2k19vmName -SourcePath "$Env:ArcBoxDir\testDefenderForServers.cmd" -DestinationPath $remoteScriptFile -CreateFullPath -FileSource Host -Force
Copy-VMFile $Win2k22vmName -SourcePath "$Env:ArcBoxDir\testDefenderForServers.cmd" -DestinationPath $remoteScriptFile -CreateFullPath -FileSource Host -Force

$cmdExePath = "C:\Windows\System32\cmd.exe"
$cmdArguments = "/C `"$remoteScriptFile`""

Invoke-Command -VMName $Win2k19vmName -ScriptBlock { Start-Process -FilePath $Using:cmdExePath -ArgumentList $Using:cmdArguments } -Credential $winCreds

# Onboarding to Vulnerability assessment solution
#Write-Header "Onboarding to Vulnerability assessment solution"
#$resourceId = $(az resource show --name $Win2k19vmName --resource-group $resourceGroup --resource-type Microsoft.HybridCompute/machines --query id --output tsv)
#$Uri = "https://management.azure.com${resourceId}/providers/Microsoft.Security/serverVulnerabilityAssessments/mdetvm?api-version=2015-06-01-preview"
#az rest --uri $Uri --method PUT


Write-Output "Onboarding the nested Linux VMs as an Azure Arc-enabled servers"
$ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
$Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output
$command = "curl -o ~/Downloads/eicar.com.txt"
$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

#Write-Header "Installing the Azure Monitor Agent on the Linux Arc-enabled server"
#az connectedmachine extension create --name AzureMonitorLinuxAgent `
#                                     --publisher Microsoft.Azure.Monitor `
#                                     --type AzureMonitorLinuxAgent `
#                                     --machine-name $Ubuntu01vmName `
#                                     --resource-group $resourceGroup `
#                                     --location $azureLocation `
#                                     --enable-auto-upgrade true `
#                                     --no-wait

# Onboarding to Vulnerability assessment solution
#Write-Header "Onboarding to Vulnerability assessment solution"
#$resourceId = $(az resource show --name $Ubuntu01vmName --resource-group $resourceGroup --resource-type Microsoft.HybridCompute/machines --query id --output tsv)
#$Uri = "https://management.azure.com${resourceId}/providers/Microsoft.Security/serverVulnerabilityAssessments/mdetvm?api-version=2015-06-01-preview"
#az rest --uri $Uri --method PUT

#$ubuntuSession = New-SSHSession -ComputerName $Ubuntu02VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
#$Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
#$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

# Configure SSH on the nested Windows VMs
<#Write-Output "Configuring SSH via Azure Arc agent on the nested Windows VMs"
Invoke-Command -VMName $Win2k19vmName, $Win2k22vmName -ScriptBlock {
    # Allow SSH via Azure Arc agent
    azcmagent config set incomingconnections.ports 22
} -Credential $winCreds
#>

#############################################################
# Install VSCode extensions
#############################################################
Write-Header "Installing VSCode extensions"
# Install VSCode extensions
$VSCodeExtensions = @(
    'ms-vscode.powershell',
    'esbenp.prettier-vscode',
    'ms-vscode-remote.remote-ssh'
)

foreach ($extension in $VSCodeExtensions) {
    code --install-extension $extension
}

#############################################################
# Install PowerShell 7
#############################################################
Write-Header "Installing PowerShell 7 on the client VM"
#Invoke-WebRequest "https://github.com/PowerShell/PowerShell/releases/download/v7.3.6/PowerShell-7.3.6-win-x64.msi" -OutFile $Env:ArcBoxDir\PowerShell-7.3.6-win-x64.msi
Start-Process msiexec.exe -ArgumentList "/I $Env:ArcBoxDir\PowerShell-7.3.6-win-x64.msi /quiet"


Write-Header "Installing PowerShell 7 on the ArcBox-Win2K22 machine"
Copy-VMFile $Win2k22vmName -SourcePath "$Env:ArcBoxDir\PowerShell-7.3.6-win-x64.msi" -DestinationPath "$Env:ArcBoxDir\PowerShell-7.3.6-win-x64.msi" -CreateFullPath -FileSource Host -Force
Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Start-Process msiexec.exe -ArgumentList "/I C:\ArcBox\PowerShell-7.3.6-win-x64.msi /quiet" } -Credential $winCreds

Write-Header "Installing PowerShell 7 on the nested ArcBox-Ubuntu-01 VM"
$ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
$Command = "wget https://github.com/PowerShell/PowerShell/releases/download/v7.3.3/powershell_7.3.3-1.deb_amd64.deb;sudo dpkg -i /home/arcdemo/powershell_7.3.3-1.deb_amd64.deb"
$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

Write-Host "Installing PSWSMan on the Linux VM"
$ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
$Command = "sudo pwsh -command 'Install-Module -Force -PassThru -Name PSWSMan'"
$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

Write-Host "Configuring PSWSMan on the Linux VM"
$ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
$Command = "sudo pwsh -command 'Install-WSMan'"
$(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output


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
7z a $Env:ArcBoxLogsDir\LogsBundle-"$RandomString".zip $Env:ArcBoxLogsDir\*.log
}'

# Changing to Jumpstart ArcBox wallpaper
# Changing to Client VM wallpaper
$imgPath = "$Env:ArcBoxDir\wallpaper.png"
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

# Set wallpaper image based on the ArcBox Flavor deployed
Write-Header "Changing Wallpaper"
$imgPath = "$Env:ArcBoxDir\wallpaper.png"
Add-Type $code
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Send telemtry
$Url = "https://arcboxleveluptelemtry.azurewebsites.net/api/triggerDeployment?"
$rowKey = -join ((97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_})
$headers = @{
    'Content-Type'='application/json'
    }
$Body = @{
    Location = $azureLocation
    PartitionKey = "Location"
    RowKey = $rowKey
}
$Body = $Body | ConvertTo-Json
Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers

Stop-Transcript
