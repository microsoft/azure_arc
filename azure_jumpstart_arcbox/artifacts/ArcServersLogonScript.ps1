$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = "$Env:ArcBoxDir\Virtual Machines"
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$agentScript = "$Env:ArcBoxDir\agentScript"

if ($Env:flavor -eq 'DataOps') {
    ################################################
    # - Created Nested SQL VM
    ################################################
    Start-Transcript -Path $Env:ArcBoxLogsDir\NestedSqlLogonScript.log
    $host.ui.RawUI.WindowTitle = 'Nested SQL Server VM'
    Write-Header "Creating Nested SQL VM"

    # Install and configure DHCP service (used by Hyper-V nested VMs)
    Write-Host "Configuring DHCP Service"
    $dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq "Ethernet" }
    Add-DhcpServerv4Scope -Name "ArcBox" `
        -StartRange 10.10.1.100 `
        -EndRange 10.10.1.200 `
        -SubnetMask 255.255.255.0 `
        -LeaseDuration 1.00:00:00 `
        -State Active

    Set-DhcpServerv4OptionValue -ComputerName localhost `
        -DnsDomain $dnsClient.ConnectionSpecificSuffix `
        -DnsServer 168.63.129.16, 10.16.2.100 `
        -Router 10.10.1.1 `
        -Force

    Add-DhcpServerInDC -DnsName "arcbox-client.jumpstart.local"
    Restart-Service dhcpserver

    # Create the NAT network
    Write-Host "Creating Internal NAT"
    $natName = "InternalNat"
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24

    # Create an internal switch with NAT
    Write-Host "Creating Internal vSwitch"
    $switchName = 'InternalNATSwitch'
    New-VMSwitch -Name $switchName -SwitchType Internal
    $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*" + $switchName + "*" }

    # Create an internal network (gateway first)
    Write-Host "Creating Gateway"
    New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

    # Enable Enhanced Session Mode on Host
    Write-Host "Enabling Enhanced Session Mode"
    Set-VMHost -EnableEnhancedSessionMode $true

    $SQLvmName = "ArcBox-SQL"

    Write-Host "Fetching Nested VMs"
    $sourceFolder = 'https://jumpstart.blob.core.windows.net/v2images'
    $sas = "?sp=rl&st=2022-01-27T01:47:01Z&se=2025-01-27T09:47:01Z&spr=https&sv=2020-08-04&sr=c&sig=NB8g7f4JT3IM%2FL6bUfjFdmnGIqcc8WU015socFtkLYc%3D"
    $Env:AZCOPY_BUFFER_GB = 4
    Write-Output "Downloading nested VMs VHDX file for SQL. This can take some time, hold tight..."
    azcopy cp "$sourceFolder/${SQLvmName}.vhdx$sas" "$Env:ArcBoxVMDir\${SQLvmName}.vhdx" --check-length=false --cap-mbps 1200 --log-level=ERROR

    # Create the nested SQL VM
    Write-Host "Create Hyper-V VMs"
    New-VM -Name $SQLvmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${SQLvmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $SQLvmName -Count 2

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Host "Set VM Auto Start/Stop"
    Set-VM -Name $SQLvmName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Host "Enabling Guest Integration Service"
    Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

    # Start all the VMs
    Write-Host "Starting SQL VM"
    Start-VM -Name $SQLvmName


    Write-Host "Creating VM Credentials"
    # Hard-coded username and password for the nested VMs
    $nestedWindowsUsername = "Administrator"
    $nestedWindowsPassword = "ArcDemo123!!"

    # Create Windows credential object
    $secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
    $winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

    # Restarting Windows VM Network Adapters
    Write-Host "Restarting Network Adapters"
    Start-Sleep -Seconds 20
    Invoke-Command -VMName $SQLvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 5

    # Configuring the local SQL VM
    Write-Host "Setting local SQL authentication and adding a SQL login"
    $localSQLUser = $Env:AZDATA_USERNAME
    $localSQLPassword = $Env:AZDATA_PASSWORD
    Invoke-Command -VMName ArcBox-SQL -Credential $winCreds -ScriptBlock {
        Install-Module -Name SqlServer -AllowClobber -Force
        $server = "localhost"
        $user = $Using:localSQLUser
        $LoginType = "SqlLogin"
        $pass = ConvertTo-SecureString -String $Using:localSQLPassword -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pass
        Add-SqlLogin -ServerInstance $Server -LoginName $User -LoginType $LoginType -DefaultDatabase AdventureWorksLT2019 -Enable -GrantConnectSql -LoginPSCredential $Credential
        $svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
        $svr.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
        $svr.Alter()
        Restart-Service -Force MSSQLSERVER
        $svrole = $svr.Roles | where { $_.Name -eq 'sysadmin' }
        $svrole.AddMember($user)
    }

    # Creating Hyper-V Manager desktop shortcut
    Write-Host "Creating Hyper-V Shortcut"
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

    # Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
    Write-Header "Blocking IMDS"
    Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc-enabled servers"
    Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
    Stop-Service WindowsAzureGuestAgent -Force -Verbose
    New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

    # Check if Service Principal has 'Microsoft.Authorization/roleAssignments/write' permissions to target Resource Group
    $requiredActions = @('*', 'Microsoft.Authorization/roleAssignments/write', 'Microsoft.Authorization/*', 'Microsoft.Authorization/*/write')

    Write-Header "Az CLI Login"
    az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

    $roleDefinitions = az role definition list --out json | ConvertFrom-Json
    $spnObjectId = az ad sp show --id $Env:spnClientID --query id -o tsv
    $rolePermissions = az role assignment list --include-inherited --include-groups --scope "/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}" | ConvertFrom-Json
    $authorizedRoles = $roleDefinitions | ForEach-Object { $_ | Where-Object { (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.actions | Select-Object) -ExcludeDifferent -IncludeEqual) -and -not (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.notactions | Select-Object) -ExcludeDifferent -IncludeEqual) } } | Select-Object -ExpandProperty roleName
    $hasPermission = $rolePermissions | Where-Object { ($_.principalId -eq $spnObjectId) -and ($_.roleDefinitionName -in $authorizedRoles) }

    # Enable defender for cloud for SQL Server
    # Verify existing plan and update accordingly
    $currentsqlplan = (az security pricing show -n SqlServerVirtualMachines --subscription $env:subscriptionId | ConvertFrom-Json)
    if ($currentsqlplan.pricingTier -eq "Free")
    {
        # Update to standard plan
        Write-Header "Current Defender for SQL plan is $($currentsqlplan.pricingTier). Updating to standard plan."
        az security pricing create -n SqlServerVirtualMachines --tier 'standard' --subscription $env:subscriptionId
    }
    else {
        Write-Header "Current Defender for SQL plan is $($currentsqlplan.pricingTier)"
    }

    # Set defender for cloud log analytics workspace
    Write-Header "Updating Log Analytics workspacespace for defender for cloud for SQL Server"
    az security workspace-setting create -n default --target-workspace "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$env:workspaceName"

    # Deploy SQLAdvancedThreatProtection solution to support Defender for SQL
    Write-Host "Deploying SQLAdvancedThreatProtection solution to support Defender for SQL server."
    # Install log-analytics-solution cli extension
    az extension add --name log-analytics-solution --yes
    az monitor log-analytics solution create --resource-group $Env:resourceGroup --solution-type SQLAdvancedThreatProtection --workspace $Env:workspaceName

    # Copying the Azure Arc Connected Agent to nested VMs
    # Create appropriate onboard script to SQL VM depending on whether or not the Service Principal has permission to peroperly onboard it to Azure Arc
    if (-not $hasPermission) {
    (Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
    }
    else {
    (Get-Content -path "$agentScript\installArcAgentSQLSP.ps1" -Raw) | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
    }
    (Get-Content -path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"

    # Copy installtion script to nested Windows VMs
    Write-Output "Transferring installation script to nested Windows VMs..."
    Copy-VMFile $SQLvmName -SourcePath "$agentScript\installArcAgentSQLModified.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host

    $nestedVMArcBoxDir = $Env:ArcBoxDir
    $spnClientId = $env:spnClientId
    $spnClientSecret = $env:spnClientSecret
    $spnTenantId = $env:spnTenantId
    $subscriptionId = $env:subscriptionId
    $azureLocation = $env:azureLocation
    $resourceGroup = $env:resourceGroup
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds

    # Creating Hyper-V Manager desktop shortcut
    Write-Host "Creating Hyper-V Shortcut"
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force
    Stop-Transcript
}
else {
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

    # Enable defender for cloud for SQL Server
    Write-Header "Enabling defender for cloud for SQL Server"
    az security pricing create -n SqlServerVirtualMachines --tier 'standard'

    # Set defender for cloud log analytics workspace
    Write-Header "Updating Log Analytics workspacespace for defender for cloud for SQL Server"
    az security workspace-setting create -n default --target-workspace "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$env:workspaceName"

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
    $sourceFolder = 'https://jumpstart.blob.core.windows.net/v2images'
    $sas = "?sp=rl&st=2022-01-27T01:47:01Z&se=2025-01-27T09:47:01Z&spr=https&sv=2020-08-04&sr=c&sig=NB8g7f4JT3IM%2FL6bUfjFdmnGIqcc8WU015socFtkLYc%3D"
    $Env:AZCOPY_BUFFER_GB = 4
    if ($Env:flavor -eq "Full") {
        # The "Full" ArcBox flavor has an azcopy network throughput capping
        Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
        azcopy cp $sourceFolder/*$sas $Env:ArcBoxVMDir --recursive=true --check-length=false --cap-mbps 1200 --log-level=ERROR
    }
    else {
        # Other ArcBox flavors does not have an azcopy network throughput capping
        Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
        azcopy cp $sourceFolder/*$sas $Env:ArcBoxVMDir --recursive=true --check-length=false --log-level=ERROR
    }

    # Create the nested VMs
    Write-Header "Create Hyper-V VMs"
    $Win2k19vmName = "ArcBox-Win2K19"
    New-VM -Name $Win2k19vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${Win2k19vmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $Win2k19vmName -Count 2

    $Win2k22vmName = "ArcBox-Win2K22"
    New-VM -Name $Win2k22vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${Win2k22vmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $Win2k22vmName -Count 2

    $SQLvmName = "ArcBox-SQL"
    New-VM -Name $SQLvmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${SQLvmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMProcessor -VMName $SQLvmName -Count 2

    $Ubuntu01vmName = "ArcBox-Ubuntu-01"
    New-VM -Name $Ubuntu01vmName -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${Ubuntu01vmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMFirmware -VMName $Ubuntu01vmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    Set-VMProcessor -VMName $Ubuntu01vmName -Count 1

    $Ubuntu02vmName = "ArcBox-Ubuntu-02"
    New-VM -Name $Ubuntu02vmName -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath "${Env:ArcBoxVMDir}\${Ubuntu02vmName}.vhdx" -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
    Set-VMFirmware -VMName $Ubuntu02vmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    Set-VMProcessor -VMName $Ubuntu02vmName -Count 1

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Header "Set VM Auto Start/Stop"
    Set-VM -Name $Win2k19vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    Set-VM -Name $Win2k22vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    Set-VM -Name $SQLvmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    Set-VM -Name $Ubuntu01vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    Set-VM -Name $Ubuntu02vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Header "Enabling Guest Integration Service"
    Get-VM | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

    # Start all the VMs
    Write-Header "Starting VMs"
    Start-VM -Name $Win2k19vmName
    Start-VM -Name $Win2k22vmName
    Start-VM -Name $SQLvmName
    Start-VM -Name $Ubuntu01vmName
    Start-VM -Name $Ubuntu02vmName

    Write-Header "Creating VM Credentials"
    # Hard-coded username and password for the nested VMs
    $nestedWindowsUsername = "Administrator"
    $nestedWindowsPassword = "ArcDemo123!!"
    $nestedLinuxUsername = "arcdemo"
    $nestedLinuxPassword = "ArcDemo123!!"

    # Create Windows credential object
    $secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
    $winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

    # Create Linux credential object
    $secLinuxPassword = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
    $linCreds = New-Object System.Management.Automation.PSCredential ($nestedLinuxUsername, $secLinuxPassword)

    # Restarting Windows VM Network Adapters
    Write-Header "Restarting Network Adapters"
    Start-Sleep -Seconds 20
    Invoke-Command -VMName $Win2k19vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Invoke-Command -VMName $SQLvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 5

    # Configuring the local SQL VM
    Write-Host "Setting local SQL authentication and adding a SQL login"
    $localSQLUser = $Env:AZDATA_USERNAME
    $localSQLPassword = $Env:AZDATA_PASSWORD
    Invoke-Command -VMName ArcBox-SQL -Credential $winCreds -ScriptBlock {
        Install-Module -Name SqlServer -AllowClobber -Force
        $server = "localhost"
        $user = $Using:localSQLUser
        $LoginType = "SqlLogin"
        $pass = ConvertTo-SecureString -String $Using:localSQLPassword -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pass
        Add-SqlLogin -ServerInstance $Server -LoginName $User -LoginType $LoginType -DefaultDatabase AdventureWorksLT2019 -Enable -GrantConnectSql -LoginPSCredential $Credential
        $svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
        $svr.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
        $svr.Alter()
        Restart-Service -Force MSSQLSERVER
        $svrole = $svr.Roles | where { $_.Name -eq 'sysadmin' }
        $svrole.AddMember($user)
    }

    # Creating Hyper-V Manager desktop shortcut
    Write-Host "Creating Hyper-V Shortcut"
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force


    # Configure the ArcBox Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
    Write-Header "Blocking IMDS"
    Write-Output "Configure the ArcBox VM to allow the nested VMs onboard as Azure Arc-enabled servers"
    Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
    Stop-Service WindowsAzureGuestAgent -Force -Verbose
    New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

    # Getting the Ubuntu nested VM IP address
    $Ubuntu01VmIp = Get-VM -Name "ArcBox-Ubuntu-01" | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0
    $Ubuntu02VmIp = Get-VM -Name "ArcBox-Ubuntu-02" | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0

    # Check if Service Principal has 'Microsoft.Authorization/roleAssignments/write' permissions to target Resource Group
    $requiredActions = @('*', 'Microsoft.Authorization/roleAssignments/write', 'Microsoft.Authorization/*', 'Microsoft.Authorization/*/write')

    $roleDefinitions = az role definition list --out json | ConvertFrom-Json
    $spnObjectId = az ad sp show --id $Env:spnClientID --query id -o tsv
    $rolePermissions = az role assignment list --include-inherited --include-groups --scope "/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}" | ConvertFrom-Json
    $authorizedRoles = $roleDefinitions | ForEach-Object { $_ | Where-Object { (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.actions | Select-Object) -ExcludeDifferent -IncludeEqual) -and -not (Compare-Object -ReferenceObject $requiredActions -DifferenceObject @($_.permissions.notactions | Select-Object) -ExcludeDifferent -IncludeEqual) } } | Select-Object -ExpandProperty roleName
    $hasPermission = $rolePermissions | Where-Object { ($_.principalId -eq $spnObjectId) -and ($_.roleDefinitionName -in $authorizedRoles) }

    # Create appropriate onboard script to SQL VM depending on whether or not the Service Principal has permission to peroperly onboard it to Azure Arc
    if (-not $hasPermission) {
    (Get-Content -path "$agentScript\installArcAgent.ps1" -Raw) | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
    }
    else {
    (Get-Content -path "$agentScript\installArcAgentSQLSP.ps1" -Raw) | Set-Content -Path "$agentScript\installArcAgentSQLModified.ps1"
    }
    (Get-Content -path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"

    # Copy installation script to nested Windows VMs
    Write-Output "Transferring installation script to nested Windows VMs..."
    Copy-VMFile $Win2k19vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host
    Copy-VMFile $Win2k22vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host
    Copy-VMFile $SQLvmName -SourcePath "$agentScript\installArcAgentSQLModified.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host

    # Copy installation script to nested Linux VMs
    Write-Output "Transferring installation script to nested Linux VMs..."
    Set-SCPItem -ComputerName $Ubuntu01VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force
    Set-SCPItem -ComputerName $Ubuntu02VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force

    Write-Header "Onboarding Arc-enabled Servers"

    # Onboarding the nested VMs as Azure Arc-enabled servers
    Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"

    $nestedVMArcBoxDir = $Env:ArcBoxDir
    $spnClientId = $env:spnClientId
    $spnClientSecret = $env:spnClientSecret
    $spnTenantId = $env:spnTenantId
    $subscriptionId = $env:subscriptionId
    $azureLocation = $env:azureLocation
    $resourceGroup = $env:resourceGroup
    Invoke-Command -VMName $Win2k19vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds
    Invoke-Command -VMName $Win2k22vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation} -Credential $winCreds

    Write-Output "Onboarding the nested Linux VMs as an Azure Arc-enabled servers"

    $ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
    $Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
    $(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

    $ubuntuSession = New-SSHSession -ComputerName $Ubuntu02VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
    $Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
    $(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

    # Configure SSH on the nested Windows VMs
    Write-Output "Configuring SSH via Azure Arc agent on the nested Windows VMs"

    Invoke-Command -VMName "ArcBox-SQL","ArcBox-Win2K19","ArcBox-Win2K22" -ScriptBlock {

        # Allow SSH via Azure Arc agent
        azcmagent config set incomingconnections.ports 22

    } -Credential $winCreds

    # Creating Hyper-V Manager desktop shortcut
    Write-Header "Creating Hyper-V Shortcut"
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

    # Prepare ArcBox-SQL onboarding script and create shortcut on desktop if the current Service Principal doesn't have appropriate permission to onboard the VM to Azure Arc
    if (-not $hasPermission) {
        Write-Header "Creating Arc-enabled SQL Shortcut"

        # Replace variables in Arc-enabled SQL onboarding scripts
        $sqlServerName = $SQLvmName

    (Get-Content -path "$Env:ArcBoxDir\installArcAgentSQLUser.ps1" -Raw) -replace '<subscriptionId>', "$Env:subscriptionId" -replace '<resourceGroup>', "$Env:resourceGroup" -replace '<location>', "$Env:azureLocation" | Set-Content -Path "$Env:ArcBoxDir\installArcAgentSQLUser.ps1"
    (Get-Content -path "$Env:ArcBoxDir\ArcSQLManualOnboarding.ps1" -Raw) -replace '<subscriptionId>', "$Env:subscriptionId" -replace '<resourceGroup>', "$Env:resourceGroup" -replace '<sqlServerName>', "$sqlServerName" | Set-Content -Path "$Env:ArcBoxDir\ArcSQLManualOnboarding.ps1"

        # Set Edge as the Default Browser
        & SetDefaultBrowser.exe HKLM "Microsoft Edge"

        # Disable Edge 'First Run' Setup
        $edgePolicyRegistryPath = 'HKLM:SOFTWARE\Policies\Microsoft\Edge'
        $desktopSettingsRegistryPath = 'HKCU:SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
        $firstRunRegistryName = 'HideFirstRunExperience'
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
        $shortcut.IconLocation = "${Env:ArcBoxIconDir}\arcsql.ico, 0"
        $shortcut.WindowStyle = 3
        $shortcut.Save()
    }

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

    $DataServicesLogonScript = Get-WmiObject win32_process -filter 'name="powershell.exe"' | Select-Object CommandLine | ForEach-Object { $_ | Select-String "DataServicesLogonScript.ps1" }

    if (-not $DataServicesLogonScript) {
        Write-Header "Changing Wallpaper"
        $imgPath = "$Env:ArcBoxDir\wallpaper.png"
        Add-Type $code
        [Win32.Wallpaper]::SetWallpaper($imgPath)
    }

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

    Stop-Transcript
}

if ($Env:flavor -ne "DevOps")
{
    Start-Transcript -Path $Env:ArcBoxLogsDir\SQLAssessment-Defender.log

    # Enable Best practices assessment
    # Create custom log analytics table for SQL assessment
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
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:remoteScriptFileFile} -Credential $winCreds

    Stop-Transcript
}