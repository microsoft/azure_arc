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
$vhdSourceFolder = "https://jsvhds.blob.core.windows.net/arcbox/*"

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
if ($Env:flavor -ne "DevOps") {
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

    # Set custom DNS if flaver is DataOps
    if ($Env:flavor -eq 'DataOps') {
        Add-DhcpServerInDC -DnsName "arcbox-client.jumpstart.local"
        Restart-Service dhcpserver
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
    az account set -s $Env:subscriptionId

    # Register Azure providers
    Write-Header "Registering Providers"
    az provider register --namespace Microsoft.HybridCompute --wait --only-show-errors
    az provider register --namespace Microsoft.HybridConnectivity --wait --only-show-errors
    az provider register --namespace Microsoft.GuestConfiguration --wait --only-show-errors
    az provider register --namespace Microsoft.AzureArcData --wait --only-show-errors

    # Enable defender for cloud for SQL Server
    # Verify existing plan and update accordingly
    $currentsqlplan = (az security pricing show -n SqlServerVirtualMachines --subscription $subscriptionId | ConvertFrom-Json)
    if ($currentsqlplan.pricingTier -eq "Free") {
        # Update to standard plan
        Write-Header "Current Defender for SQL plan is $($currentsqlplan.pricingTier). Updating to standard plan."
        az security pricing create -n SqlServerVirtualMachines --tier 'standard' --subscription $subscriptionId --only-show-errors

        # Set defender for cloud log analytics workspace
        Write-Header "Updating Log Analytics workspacespace for defender for cloud for SQL Server"
        az security workspace-setting create -n default --target-workspace "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$env:workspaceName" --only-show-errors
    }
    else {
        Write-Header "Current Defender for SQL plan is $($currentsqlplan.pricingTier)"
    }

    # Deploy SQLAdvancedThreatProtection solution to support Defender for SQL
    Write-Host "Deploying SQLAdvancedThreatProtection solution to support Defender for SQL server."
    $extExists = $false
    $extensionList = az monitor log-analytics solution list --resource-group $resourceGroup | ConvertFrom-Json
    foreach ($extension in $extensionList.value) { if ($extension.Name -match "SQLAdvancedThreatProtection") { $extExists = $true; break; } }
    if (!$extExists) {
        az monitor log-analytics solution create --resource-group $resourceGroup --solution-type SQLAdvancedThreatProtection --workspace $Env:workspaceName --only-show-errors --no-wait
    }

    # Before deploying ArcBox SQL set resource group tag ArcSQLServerExtensionDeployment=Disabled to opt out of automatic SQL onboarding
    az tag create --resource-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup" --tags ArcSQLServerExtensionDeployment=Disabled

    $SQLvmName = "ArcBox-SQL"
    $SQLvmvhdPath = "$Env:ArcBoxVMDir\${SQLvmName}.vhdx"

    Write-Host "Fetching SQL VM"

    # Verify if VHD files already downloaded especially when re-running this script
    if (!([System.IO.File]::Exists($SQLvmvhdPath) )) {
        <# Action when all if and elseif conditions are false #>
        $Env:AZCOPY_BUFFER_GB = 4
        # Other ArcBox flavors does not have an azcopy network throughput capping
        Write-Output "Downloading nested VMs VHDX file for SQL. This can take some time, hold tight..."
        azcopy cp $vhdSourceFolder --include-pattern "${SQLvmName}.vhdx" $Env:ArcBoxVMDir --check-length=false --cap-mbps 1200 --log-level=ERROR
    }

    # Create the nested VMs if not already created
    Write-Header "Create Hyper-V VMs"

    # Create the nested SQL VM
    Write-Host "Create SQL VM"
    if ((Get-VM -Name $SQLvmName -ErrorAction SilentlyContinue).State -ne "Running") {
        Remove-VM -Name $SQLvmName -Force -ErrorAction SilentlyContinue
        New-VM -Name $SQLvmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $SQLvmvhdPath -Path $Env:ArcBoxVMDir -Generation 2 -Switch $switchName
        Set-VMProcessor -VMName $SQLvmName -Count 2
        Set-VM -Name $SQLvmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    }

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Host "Set VM Auto Start/Stop"
    Set-VM -Name $SQLvmName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Host "Enabling Guest Integration Service"
    Get-VM -Name $SQLvmName | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

    # Start all the VMs
    Write-Host "Starting SQL VM"
    Start-VM -Name $SQLvmName


    # Restarting Windows VM Network Adapters
    Write-Host "Restarting Network Adapters"
    Start-Sleep -Seconds 20
    Invoke-Command -VMName $SQLvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 5

    # Copy installation script to nested Windows VMs
    Write-Output "Transferring installation script to nested Windows VMs..."
    Copy-VMFile $SQLvmName -SourcePath "$agentScript\installArcAgentSQLSP.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force

    Write-Header "Onboarding Arc-enabled servers"

    # Onboarding the nested VMs as Azure Arc-enabled servers
    Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

    # Configure SSH on the nested Windows VMs
    Write-Output "Configuring SSH via Azure Arc agent on the nested Windows VMs"
    Invoke-Command -VMName $SQLvmName -ScriptBlock {
        # Allow SSH via Azure Arc agent
        azcmagent config set incomingconnections.ports 22
    } -Credential $winCreds


    # Install Log Analytics extension to support Defender for SQL
    $mmaExtension = az connectedmachine extension list --machine-name $SQLvmName --resource-group $resourceGroup --query "[?name=='MicrosoftMonitoringAgent']" | ConvertFrom-Json
    if ($mmaExtension.Count -le 0) {
        # Get workspace information
        $workspaceID = (az monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $Env:workspaceName --query "customerId" -o tsv)
        $workspaceKey = (az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $Env:workspaceName --query "primarySharedKey" -o tsv)

        Write-Host "Deploying Microsoft Monitoring Agent to test Defender for SQL."
        az connectedmachine extension create --machine-name $SQLvmName --name "MicrosoftMonitoringAgent" --settings "{'workspaceId':'$workspaceID'}" --protected-settings "{'workspaceKey':'$workspaceKey'}" --resource-group $resourceGroup --type-handler-version "1.0.18067.0" --type "MicrosoftMonitoringAgent" --publisher "Microsoft.EnterpriseCloud.Monitoring" --no-wait
        Write-Host "Microsoft Monitoring Agent deployment initiated."
    }

    # Azure Monitor Agent extension is deployed automatically using Azure Policy. Wait until extension status is Succeded.
    $retryCount = 0
    do {
        Start-Sleep(60)
        $amaExtension = az connectedmachine extension list --machine-name $SQLvmName --resource-group $resourceGroup --query "[?name=='AzureMonitorWindowsAgent']" | ConvertFrom-Json
        if ($amaExtension[0].properties.instanceView.status.code -eq 0) {
            Write-Host "Azure Monitoring Agent extension installation complete."
            break
        }

        $retryCount = $retryCount + 1
        Write-Host "Waiting for Azure Monitoring Agent extension installation to complete ... Retry count: $retryCount"

        if ($retryCount -gt 5) {
            Write-Host "WARNING: Azure Monitor Agent extenstion is taking longger than expected. Enable SQL BPA later through Azure portal."
        }

    } while ($retryCount -le 5)

    # Enable Best practices assessment
    if ($amaExtension[0].properties.instanceView.status.code -eq 0) {

        # Create custom log analytics table for SQL assessment
        az monitor log-analytics workspace table create --resource-group $resourceGroup --workspace-name $Env:workspaceName -n SqlAssessment_CL --columns RawData=string TimeGenerated=datetime --only-show-errors

        # Verify if Arc-enabled server and SQL server extensions are installed
        $ArcServer = az connectedmachine show --name $SQLvmName --resource-group $resourceGroup
        if ($null -ne $ArcServer) {
            $sqlExtension = az connectedmachine extension list --machine-name $SQLvmName --resource-group $resourceGroup --query "[?name=='WindowsAgent.SqlServer']" | ConvertFrom-Json
            if ($null -ne $sqlExtension) {
                # SQL server extension is installed and ready to run SQL BPA
                Write-Host "SQL server extension is installed and ready to run SQL BPA."
            }
            else {
                # Arc SQL Server extension is not installed or still in progress.
                Write-Host "SQL server extension is not installed and can't run SQL BPA."
                Exit
            }
        }
        else {
            # ArcBox-SQL Arc-enabled server resource not found
            Write-Host "ArcBox-SQL Arc-enabled server resource not found. Re-run onboard script to fix this issue."
            Exit
        }


        # Verify if ArcBox SQL resource is created
        $arcSQLStatus = az resource list --resource-group $resourceGroup --query "[?type=='Microsoft.AzureArcData/SqlServerInstances'].[provisioningState]" -o tsv
        if ($arcSQLStatus -ne "Succeeded"){
            Write-Host "WARNING: ArcBox-SQL Arc-enabled server resource not found. Wait for the resource to be created and follow troubleshooting guide to run assessment manually."
        }
        else {
            <# Action when all if and elseif conditions are false #>
            Write-Host "Enabling SQL server best practices assessment"
            $bpaDeploymentTemplateUrl = "$Env:templateBaseUrl/artifacts/sqlbpa.json"
            az deployment group create --resource-group $resourceGroup --template-uri $bpaDeploymentTemplateUrl --parameters workspaceName=$Env:workspaceName vmName=$SQLvmName arcSubscriptionId=$subscriptionId

            # Run Best practices assessment
            Write-Host "Execute SQL server best practices assessment"

            # Wait for a minute to finish everyting and run assessment
            Start-Sleep(60)

            # Get access token to make ARM REST API call for SQL server BPA
            $armRestApiEndpoint = "https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer?api-version=2019-08-02-preview"
            $token = (az account get-access-token --subscription $subscriptionId --query accessToken --output tsv)
            $headers = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

            # Build API request payload
            $worspaceResourceId = "/subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/microsoft.operationalinsights/workspaces/$Env:workspaceName".ToLower()
            $sqlExtensionId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer"
            $sqlbpaPayloadTemplate = "$Env:templateBaseUrl/artifacts/sqlbpa.payload.json"
            $settingsSaveTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $apiPayload = (Invoke-WebRequest -Uri $sqlbpaPayloadTemplate).Content -replace '{{RESOURCEID}}', $sqlExtensionId -replace '{{LOCATION}}', $azureLocation -replace '{{WORKSPACEID}}', $worspaceResourceId -replace '{{SAVETIME}}', $settingsSaveTime

            # Call REST API to run best practices assessment
            $httpResp = Invoke-WebRequest -Method Patch -Uri $armRestApiEndpoint -Body $apiPayload -Headers $headers
            if (($httpResp.StatusCode -eq 200) -or ($httpResp.StatusCode -eq 202)){
                Write-Host "Arc-enabled SQL server best practices assessment executed. Wait for assessment to complete to view results."
            }
            else {
                <# Action when all if and elseif conditions are false #>
                Write-Host "SQL Best Practices Assessment faild. Please refer troubleshooting guide to run manually."
            }
        }
    } # End of SQL BPA

    # Test Defender for SQL
    Write-Header "Simulating SQL threats to generate alerts from Defender for Cloud"
    $remoteScriptFileFile = "$agentScript\testDefenderForSQL.ps1"
    Copy-VMFile $SQLvmName -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath $remoteScriptFileFile -CreateFullPath -FileSource Host -Force
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:remoteScriptFileFile } -Credential $winCreds

    if (($Env:flavor -eq "Full") -or ($Env:flavor -eq "ITPro")) {
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
            if ($Env:flavor -eq "Full") {
                # The "Full" ArcBox flavor has an azcopy network throughput capping
                Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
                azcopy cp $vhdSourceFolder $Env:ArcBoxVMDir --include-pattern "${Win2k19vmName}.vhdx;${Win2k22vmName}.vhdx;${Ubuntu01vmName}.vhdx;${Ubuntu02vmName}.vhdx;" --recursive=true --check-length=false --cap-mbps 1200 --log-level=ERROR
            }
            else {
                # Other ArcBox flavors does not have an azcopy network throughput capping
                Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."
                azcopy cp $vhdSourceFolder $Env:ArcBoxVMDir --include-pattern "${Win2k19vmName}.vhdx;${Win2k22vmName}.vhdx;${Ubuntu01vmName}.vhdx;${Ubuntu02vmName}.vhdx;" --recursive=true --check-length=false --log-level=ERROR
            }
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

        # Create appropriate onboard script to SQL VM depending on whether or not the Service Principal has permission to peroperly onboard it to Azure Arc
        (Get-Content -path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$spnClientId', "'$Env:spnClientId'" -replace '\$spnClientSecret', "'$Env:spnClientSecret'" -replace '\$resourceGroup', "'$Env:resourceGroup'" -replace '\$spnTenantId', "'$Env:spnTenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$Env:subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"

        # Copy installation script to nested Linux VMs
        Write-Output "Transferring installation script to nested Linux VMs..."
        Set-SCPItem -ComputerName $Ubuntu01VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force
        Set-SCPItem -ComputerName $Ubuntu02VmIp -Credential $linCreds -Destination "/home/$nestedLinuxUsername" -Path "$agentScript\installArcAgentModifiedUbuntu.sh" -Force

        Write-Header "Onboarding Arc-enabled servers"

        # Onboarding the nested VMs as Azure Arc-enabled servers
        Write-Output "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
        Invoke-Command -VMName $Win2k19vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds
        Invoke-Command -VMName $Win2k22vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

        Write-Output "Onboarding the nested Linux VMs as an Azure Arc-enabled servers"
        $ubuntuSession = New-SSHSession -ComputerName $Ubuntu01VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
        $Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
        $(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

        $ubuntuSession = New-SSHSession -ComputerName $Ubuntu02VmIp -Credential $linCreds -Force -WarningAction SilentlyContinue
        $Command = "sudo sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"
        $(Invoke-SSHCommand -SSHSession $ubuntuSession -Command $Command -Timeout 600 -WarningAction SilentlyContinue).Output

        # Configure SSH on the nested Windows VMs
        Write-Output "Configuring SSH via Azure Arc agent on the nested Windows VMs"
        Invoke-Command -VMName $Win2k19vmName, $Win2k22vmName -ScriptBlock {
            # Allow SSH via Azure Arc agent
            azcmagent config set incomingconnections.ports 22
        } -Credential $winCreds
    }

    # Removing the LogonScript Scheduled Task so it won't run on next reboot
    Write-Header "Removing Logon Task"
    if ($null -ne (Get-ScheduledTask -TaskName "ArcServersLogonScript" -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName "ArcServersLogonScript" -Confirm:$false
    }
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
$DataServicesLogonScript = Get-WmiObject win32_process -filter 'name="powershell.exe"' | Select-Object CommandLine | ForEach-Object { $_ | Select-String "DataServicesLogonScript.ps1" }
if (-not $DataServicesLogonScript) {
    Write-Header "Changing Wallpaper"
    $imgPath = "$Env:ArcBoxDir\wallpaper.png"
    Add-Type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
}

Stop-Transcript
