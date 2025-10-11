$ErrorActionPreference = $env:ErrorActionPreference

$Env:ArcBoxDir = 'C:\ArcBox'
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxVMDir = 'F:\Virtual Machines'
$Env:ArcBoxIconDir = "$Env:ArcBoxDir\Icons"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"
$Env:ArcBoxDscDir = "$Env:ArcBoxDir\DSC"
$agentScript = "$Env:ArcBoxDir\agentScript"

# Set variables to execute remote powershell scripts on guest VMs
$nestedVMArcBoxDir = $Env:ArcBoxDir
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup
$resourceTags = $env:resourceTags
$namingPrefix = $env:namingPrefix

# Moved VHD storage account details here to keep only in place to prevent duplicates.
$vhdSourceFolder = 'https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/*'

# Archive existing log file and create new one
$logFilePath = "$Env:ArcBoxLogsDir\ArcServersLogonScript.log"
if (Test-Path $logFilePath) {
    $archivefile = "$Env:ArcBoxLogsDir\ArcServersLogonScript-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Rename-Item -Path $logFilePath -NewName $archivefile -Force
}

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Remove registry keys that are used to automatically logon the user (only used for first-time setup)
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$keys = @('AutoAdminLogon', 'DefaultUserName', 'DefaultPassword')

foreach ($key in $keys) {
    try {
        $property = Get-ItemProperty -Path $registryPath -Name $key -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath -Name $key
        Write-Host "Removed registry key that are used to automatically logon the user: $key"
    } catch {
        Write-Verbose "Key $key does not exist."
    }
}

# Create desktop shortcut for Logs-folder
$WshShell = New-Object -ComObject WScript.Shell
$LogsPath = 'C:\ArcBox\Logs'
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

# Configure Windows Terminal as the default terminal application
$registryPath = 'HKCU:\Console\%%Startup'

if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
} else {
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
}


################################################
# Setup Hyper-V server before deploying VMs for each flavor
################################################
if ($Env:flavor -ne 'DevOps') {
    # Install and configure DHCP service (used by Hyper-V nested VMs)
    Write-Host 'Configuring DHCP Service'
    $dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq 'Ethernet' }
    $dhcpScope = Get-DhcpServerv4Scope
    if ($dhcpScope.Name -ne 'ArcBox') {
        Add-DhcpServerv4Scope -Name 'ArcBox' `
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
        Add-DhcpServerInDC -DnsName "$namingPrefix-client.jumpstart.local"
        Restart-Service dhcpserver
    }

    # Create the NAT network
    Write-Host 'Creating Internal NAT'
    $natName = 'InternalNat'
    $netNat = Get-NetNat
    if ($netNat.Name -ne $natName) {
        New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24
    }

    Write-Host 'Creating VM Credentials'
    # Hard-coded username and password for the nested VMs
    $nestedWindowsUsername = 'Administrator'
    $nestedWindowsPassword = 'JS123!!'

    # Create Windows credential object
    $secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
    $winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

    # Creating Hyper-V Manager desktop shortcut
    Write-Host 'Creating Hyper-V Shortcut'
    Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk' -Destination 'C:\Users\All Users\Desktop' -Force

    $cliDir = New-Item -Path "$Env:ArcBoxDir\.cli\" -Name '.servers' -ItemType Directory -Force
    if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
        $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
        $folder.Attributes += [System.IO.FileAttributes]::Hidden
    }

    # Install Azure CLI extensions
    Write-Header 'Az CLI extensions'

    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors

    @('ssh', 'log-analytics-solution', 'connectedmachine', 'monitor-control-service') |
    ForEach-Object -Parallel {
        az extension add --name $PSItem --yes --only-show-errors
    }

    # Required for CLI commands
    Write-Header 'Az CLI Login'
    az login --identity
    az account set -s $subscriptionId

    Write-Header 'Az PowerShell Login'
    Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId

    $DeploymentProgressString = 'Started ArcServersLogonScript'

    $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
    $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

    $existingVMDisk = Get-AzDisk -ResourceGroupName $env:resourceGroup | Where-Object name -Like *VMsDisk

    # Update disk IOPS and throughput before downloading nested VMs
    az disk update --resource-group $env:resourceGroup --name $existingVMDisk.Name --disk-iops-read-write 80000 --disk-mbps-read-write 1200

    # Enable defender for cloud for SQL Server
    # Get workspace information
    $workspaceResourceID = (az monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $Env:workspaceName --query 'id' -o tsv)

    # Before deploying ArcBox SQL set resource group tag ArcSQLServerExtensionDeployment=Disabled to opt out of automatic SQL onboarding
    az tag create --resource-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup" --tags ArcSQLServerExtensionDeployment=Disabled

    $vhdImageToDownload = 'ArcBox-SQL-DEV.vhdx'
    if ($Env:sqlServerEdition -eq 'Standard') {
        $vhdImageToDownload = 'ArcBox-SQL-STD.vhdx'
    } elseif ($Env:sqlServerEdition -eq 'Enterprise') {
        $vhdImageToDownload = 'ArcBox-SQL-ENT.vhdx'
    }


    $DeploymentProgressString = 'Downloading and configuring nested SQL VM'

    $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
    $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

    Write-Host 'Fetching SQL VM'
    $SQLvmName = "$namingPrefix-SQL"
    $SQLvmvhdPath = "$Env:ArcBoxVMDir\$namingPrefix-SQL.vhdx"

    # Verify if VHD files already downloaded especially when re-running this script
    if (!(Test-Path $SQLvmvhdPath)) {
        Write-Output 'Downloading nested VMs VHDX file for SQL. This can take some time, hold tight...'
        azcopy cp $vhdSourceFolder $Env:ArcBoxVMDir --include-pattern "$vhdImageToDownload" --recursive=true --check-length=false --log-level=ERROR

        # Rename VHD file
        Rename-Item -Path "$Env:ArcBoxVMDir\$vhdImageToDownload" -NewName $SQLvmvhdPath -Force
    }

    # Create the nested VMs if not already created
    Write-Header 'Create Hyper-V VMs'

    # Create the nested SQL VMs
    $sqlDscConfigurationFile = "$Env:ArcBoxDscDir\virtual_machines_sql.dsc.yml"
    (Get-Content -Path $sqlDscConfigurationFile) -replace 'namingPrefixStage', $namingPrefix | Set-Content -Path $sqlDscConfigurationFile
    winget configure --file C:\ArcBox\DSC\virtual_machines_sql.dsc.yml --accept-configuration-agreements --disable-interactivity

    # Restarting Windows VM Network Adapters
    Write-Host 'Restarting Network Adapters'
    Start-Sleep -Seconds 5
    Invoke-Command -VMName $SQLvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 20

    # Rename server if hostname is not as ArcBox-SQL or doesn't match naming prefix
    $hostname = Invoke-Command -VMName $SQLvmName -ScriptBlock { hostname } -Credential $winCreds

    if ($hostname -ne $SQLvmName) {

        Write-Header 'Renaming the nested SQL VM'
        Invoke-Command -VMName $SQLvmName -ScriptBlock { Rename-Computer -NewName $using:SQLvmName -Restart } -Credential $winCreds

        Get-VM *SQL* | Wait-VM -For IPAddress

        Write-Host 'Waiting for the nested Windows SQL VM to come back online...waiting for 30 seconds'
        Start-Sleep -Seconds 30

        # Wait for VM to start again
        while ((Get-VM -vmName $SQLvmName).State -ne 'Running') {
            Write-Host 'Waiting for VM to start...'
            Start-Sleep -Seconds 5
        }

        Write-Host 'VM has rebooted successfully!'
    }

    # Enable Windows Firewall rule for SQL Server
    Invoke-Command -VMName $SQLvmName -ScriptBlock { New-NetFirewallRule -DisplayName 'Allow SQL Server TCP 1433' -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow } -Credential $winCreds

    # Download SQL assessment preparation script
    Invoke-WebRequest ($Env:templateBaseUrl + 'artifacts/prepareSqlServerForAssessment.ps1') -OutFile $nestedVMArcBoxDir\prepareSqlServerForAssessment.ps1
    Copy-VMFile $SQLvmName -SourcePath "$Env:ArcBoxDir\prepareSqlServerForAssessment.ps1" -DestinationPath "$nestedVMArcBoxDir\prepareSqlServerForAssessment.ps1" -CreateFullPath -FileSource Host -Force
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\prepareSqlServerForAssessment.ps1 } -Credential $winCreds

    # Copy installation script to nested Windows VMs
    Write-Output 'Transferring installation script to nested Windows VMs...'
    Copy-VMFile $SQLvmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force

    Write-Header 'Onboarding Arc-enabled servers'

    # Onboarding the nested VMs as Azure Arc-enabled servers
    Write-Output 'Onboarding the nested Windows VMs as Azure Arc-enabled servers'
    $accessToken = ConvertFrom-SecureString ((Get-AzAccessToken -AsSecureString).Token) -AsPlainText
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -accessToken $using:accessToken, -tenantId $Using:tenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

    # Wait for the Arc-enabled server installation to be completed
    $retryCount = 0
    do {
        $ArcServer = Get-AzConnectedMachine -Name $SQLvmName -ResourceGroupName $resourceGroup
        if (($null -ne $ArcServer) -and ($ArcServer.ProvisioningState -eq 'Succeeded')) {
            Write-Host 'Onboarding the nested SQL VM as Azure Arc-enabled server successful.'
            $azConnectedMachineId = $ArcServer.Id
            break;
        } else {
            $retryCount = $retryCount + 1
            if ($retryCount -gt 5) {
                Write-Host "WARNING: Timeout exceeded for onboarding nested SQL VM as Azure Arc-enabled server ... Retry count: $retryCount."
                Exit
            } else {
                Write-Host "Waiting for onboarding nested SQL VM as Azure Arc-enabled server ... Retry count: $retryCount"
                Start-Sleep(30)
            }
        }
    } while ($retryCount -le 5)

    # Create SQL server extension as policy to auto deployment is disabled
    Write-Host "Installing SQL Server extension on the Arc-enabled Server.`n"
    az connectedmachine extension create --machine-name $SQLvmName --name 'WindowsAgent.SqlServer' --resource-group $resourceGroup --type 'WindowsAgent.SqlServer' --publisher 'Microsoft.AzureData' --settings '{\"LicenseType\":\"Paid\", \"SqlManagement\": {\"IsEnabled\":true}}' --tags $resourceTags --location $azureLocation --only-show-errors --no-wait
    Write-Host 'SQL Server extension installation on the Arc-enabled Server successful.'

    $retryCount = 0
    do {
        # Verify if Arc-enabled server and SQL server extensions are installed
        $sqlExtension = Get-AzConnectedMachine -Name $SQLvmName -ResourceGroupName $resourceGroup | Select-Object -ExpandProperty Resource | Where-Object { $PSItem.Name -eq 'WindowsAgent.SqlServer' }
        if ($sqlExtension -and ($sqlExtension.ProvisioningState -eq 'Succeeded')) {
            # SQL server extension is installed and ready to run SQL BPA
            Write-Host "SQL server extension is installed and ready to run SQL BPA.`n"
            break;
        } else {
            # Arc SQL Server extension is not installed or still in progress.
            $retryCount = $retryCount + 1
            if ($retryCount -gt 10) {
                Write-Warning "Timeout exceeded installing SQL server extension. Retry count: $retryCount."
            } else {
                Write-Host "Waiting for SQL server extension installation ... Retry count: $retryCount"
                Start-Sleep(30)
            }
        }
    } while ($retryCount -le 10)

    # Azure Monitor Agent extension is deployed automatically using Azure Policy. Wait until extension status is Succeded.
    Write-Host "Installing Azure Monitoring Agent extension.`n"
    az connectedmachine extension create --machine-name $SQLvmName --name AzureMonitorWindowsAgent --publisher Microsoft.Azure.Monitor --type AzureMonitorWindowsAgent --resource-group $resourceGroup --location $azureLocation --only-show-errors --no-wait

    $retryCount = 0
    do {
        $amaExtension = Get-AzConnectedMachine -Name $SQLvmName -ResourceGroupName $resourceGroup | Select-Object -ExpandProperty Resource | Where-Object { $PSItem.Name -eq 'AzureMonitorWindowsAgent' }
        if ($amaExtension.StatusCode -eq 0) {
            Write-Host 'Azure Monitoring Agent extension installation complete.'
            break
        } else {
            $retryCount = $retryCount + 1
            if ($retryCount -gt 10) {
                Write-Host 'WARNING: Azure Monitor Agent extenstion is taking longger than expected. Enable SQL BPA later through Azure portal.'
                break
            } else {
                Write-Host "Waiting for Azure Monitoring Agent extension installation to complete ... Retry count: $retryCount"
                Start-Sleep(60)
            }
        }
    } while ($retryCount -le 10)

    # Get access token to make ARM REST API call for SQL server BPA and migration assessments
    $token = (az account get-access-token --subscription $subscriptionId --query accessToken --output tsv)
    $headers = @{'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }

    # Enable Best practices assessment
    if ($amaExtension.StatusCode -eq 0) {

        # Create custom log analytics table for SQL assessment
        Write-Host "Creating Log Analytis workspace table for SQL best practices assessment.`n"
        az monitor log-analytics workspace table create --resource-group $resourceGroup --workspace-name $Env:workspaceName -n SqlAssessment_CL --columns RawData=string TimeGenerated=datetime --only-show-errors

        # Verify if ArcBox SQL resource is created
        Write-Host "Enabling SQL server best practices assessment.`n"
        $bpaDeploymentTemplateUrl = "$Env:templateBaseUrl/artifacts/sqlbpa.json"
        az deployment group create --resource-group $resourceGroup --template-uri $bpaDeploymentTemplateUrl --parameters workspaceName=$Env:workspaceName vmName=$SQLvmName arcSubscriptionId=$subscriptionId

        # Run Best practices assessment
        Write-Host "Execute SQL server best practices assessment.`n"

        # Wait for a minute to finish everyting and run assessment
        Start-Sleep(60)

        $armRestApiEndpoint = "https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer?api-version=2019-08-02-preview"

        # Build API request payload
        $worspaceResourceId = "/subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/microsoft.operationalinsights/workspaces/$Env:workspaceName".ToLower()
        $sqlExtensionId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$SQLvmName/extensions/WindowsAgent.SqlServer"
        $sqlbpaPayloadTemplate = "$Env:templateBaseUrl/artifacts/sqlbpa.payload.json"
        $settingsSaveTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $apiPayload = (Invoke-WebRequest -Uri $sqlbpaPayloadTemplate).Content -replace '{{RESOURCEID}}', $sqlExtensionId -replace '{{LOCATION}}', $azureLocation -replace '{{WORKSPACEID}}', $worspaceResourceId -replace '{{SAVETIME}}', $settingsSaveTime

        # Call REST API to run best practices assessment
        $httpResp = Invoke-WebRequest -Method Patch -Uri $armRestApiEndpoint -Body $apiPayload -Headers $headers
        if (($httpResp.StatusCode -eq 200) -or ($httpResp.StatusCode -eq 202)) {
            Write-Host 'Arc-enabled SQL server best practices assessment executed. Wait for assessment to complete to view results.'
        } else {
            <# Action when all if and elseif conditions are false #>
            Write-Host 'SQL Best Practices Assessment faild. Please refer troubleshooting guide to run manually.'
        }
    } # End of SQL BPA

    # Run SQL Server Azure Migration Assessment
    Write-Host "Enabling SQL Server Azure Migration Assessment.`n"
    $migrationApiURL = 'https://management.azure.com/batch?api-version=2020-06-01'
    $assessmentName = (New-Guid).Guid
    $payLoad = @"
{"requests":[{"httpMethod":"POST","name":"$assessmentName","requestHeaderDetails":{"commandName":"Microsoft_Azure_HybridData_Platform."},"url":"https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.AzureArcData/SqlServerInstances/$SQLvmName/runMigrationAssessment?api-version=2024-05-01-preview"}]}
"@

    $httpResp = Invoke-WebRequest -Method Post -Uri $migrationApiURL -Body $payLoad -Headers $headers
    if (($httpResp.StatusCode -eq 200) -or ($httpResp.StatusCode -eq 202)) {
        Write-Host 'Arc-enabled SQL server migration assessment executed. Wait for assessment to complete to view results.'
    } else {
        <# Action when all if and elseif conditions are false #>
        Write-Host 'SQL Server Migration Assessment faild. Please refer troubleshooting guide to run manually.'
    }

    #Install SQLAdvancedThreatProtection solution
    Write-Host "Installing SQLAdvancedThreatProtection Log Analytics solution.`n"
    az monitor log-analytics solution create --resource-group $resourceGroup --solution-type SQLAdvancedThreatProtection --workspace $Env:workspaceName --only-show-errors

    #Install SQLVulnerabilityAssessment solution
    Write-Host "Install SQLVulnerabilityAssessment Log Analytics solution.`n"
    az monitor log-analytics solution create --resource-group $resourceGroup --solution-type SQLVulnerabilityAssessment --workspace $Env:workspaceName --only-show-errors

    # Update Azure Monitor data collection rule template with Log Analytics workspace resource ID
    $sqlDefenderDcrFile = "$Env:ArcBoxDir\defendersqldcrtemplate.json"
    (Get-Content -Path $sqlDefenderDcrFile) -replace '{LOGANLYTICS_WORKSPACEID}', $workspaceResourceID | Set-Content -Path $sqlDefenderDcrFile

    # Create data collection rules for Defender for SQL
    Write-Host "Creating Azure Monitor data collection rule.`n"
    $dcrName = 'Jumpstart-DefenderForSQL-DCR'
    az monitor data-collection rule create --resource-group $resourceGroup --location $env:azureLocation --name $dcrName --rule-file $sqlDefenderDcrFile

    # Associate DCR with Azure Arc-enabled Server resource
    Write-Host "Creating Azure Monitor data collection rule assocation for Arc-enabled server.`n"
    $dcrRuleId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"
    az monitor data-collection rule association create --name "$SQLvmName" --rule-id $dcrRuleId --resource $azConnectedMachineId

    # Test Defender for SQL
    Write-Header "Simulating SQL threats to generate alerts from Defender for Cloud.`n"
    $remoteScriptFileFile = "$Env:ArcBoxDir\testDefenderForSQL.ps1"
    Copy-VMFile $SQLvmName -SourcePath "$Env:ArcBoxDir\SqlAdvancedThreatProtectionShell.psm1" -DestinationPath "$Env:ArcBoxDir\SqlAdvancedThreatProtectionShell.psm1" -CreateFullPath -FileSource Host -Force
    Copy-VMFile $SQLvmName -SourcePath "$Env:ArcBoxDir\testDefenderForSQL.ps1" -DestinationPath $remoteScriptFileFile -CreateFullPath -FileSource Host -Force
    Invoke-Command -VMName $SQLvmName -ScriptBlock { powershell -File $Using:remoteScriptFileFile } -Credential $winCreds

    # Enable least privileged access
    Write-Host "Enabling Arc-enabled SQL server least privileged access.`n"
    az sql server-arc extension feature-flag set --name LeastPrivilege --enable true --resource-group $resourceGroup --machine-name $SQLvmName

    # Enable automated backups
    Write-Host "Enabling Arc-enabled SQL server automated backups.`n"
    az sql server-arc backups-policy set --name $SQLvmName --resource-group $resourceGroup --retention-days 31 --full-backup-days 7 --diff-backup-hours 12 --tlog-backup-mins 5

    # Onboard nested Windows and Linux VMs to Azure Arc
    if ($Env:flavor -eq 'ITPro') {
        Write-Header 'Fetching Nested VMs'

        $Win2k22vmName = "$namingPrefix-Win2K22"
        $Win2k22vmvhdPath = "${Env:ArcBoxVMDir}\$namingPrefix-Win2K22.vhdx"

        $Win2k25vmName = "$namingPrefix-Win2K25"
        $Win2k25vmvhdPath = "${Env:ArcBoxVMDir}\$namingPrefix-Win2K25.vhdx"

        $Ubuntu01vmName = "$namingPrefix-Ubuntu-01"
        $Ubuntu01vmvhdPath = "${Env:ArcBoxVMDir}\$namingPrefix-Ubuntu-01.vhdx"

        $Ubuntu02vmName = "$namingPrefix-Ubuntu-02"
        $Ubuntu02vmvhdPath = "${Env:ArcBoxVMDir}\$namingPrefix-Ubuntu-02.vhdx"

        $files = 'ArcBox-Win2K22.vhdx;ArcBox-Win2K25.vhdx;ArcBox-Ubuntu-01.vhdx;ArcBox-Ubuntu-02.vhdx;'

        $DeploymentProgressString = 'Downloading and configuring nested VMs'

        $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

        if ($null -ne $tags) {
            $tags['DeploymentProgress'] = $DeploymentProgressString
        } else {
            $tags = @{'DeploymentProgress' = $DeploymentProgressString }
        }

        $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
        $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

        # Verify if VHD files already downloaded especially when re-running this script
        if (!((Test-Path $Win2K25vmvhdPath) -and (Test-Path $Win2k22vmvhdPath) -and (Test-Path $Ubuntu01vmvhdPath) -and (Test-Path $Ubuntu02vmvhdPath))) {
            <# Action when all if and elseif conditions are false #>
            $Env:AZCOPY_BUFFER_GB = 4
            Write-Output 'Downloading nested VMs VHDX files. This can take some time, hold tight...'
            azcopy cp $vhdSourceFolder $Env:ArcBoxVMDir --include-pattern $files --recursive=true --check-length=false --log-level=ERROR
        }

        if ($namingPrefix -ne 'ArcBox') {

            # Split the string into an array
            $fileList = $files -split ';' | Where-Object { $_ -ne '' }

            # Set the path to search for files
            $searchPath = $Env:ArcBoxVMDir

            # Loop through each file and rename if found
            foreach ($file in $fileList) {
                $filePath = Join-Path -Path $searchPath -ChildPath $file
                if (Test-Path $filePath) {
                    $newFileName = $file -replace 'ArcBox', $namingPrefix

                    Rename-Item -Path $filePath -NewName $newFileName
                    Write-Output "Renamed $file to $newFileName"
                } else {
                    Write-Output "$file not found in $searchPath"
                }
            }
        }

        # Update disk IOPS and throughput after downloading nested VMs (note: a disk's performance tier can be downgraded only once every 12 hours)
        az disk update --resource-group $env:resourceGroup --name $existingVMDisk.Name --disk-iops-read-write $existingVMDisk.DiskIOPSReadWrite --disk-mbps-read-write $existingVMDisk.DiskMBpsReadWrite

        # Create the nested VMs if not already created
        Write-Header 'Create Hyper-V VMs'
        $serversDscConfigurationFile = "$Env:ArcBoxDscDir\virtual_machines_itpro.dsc.yml"
        (Get-Content -Path $serversDscConfigurationFile) -replace 'namingPrefixStage', $namingPrefix | Set-Content -Path $serversDscConfigurationFile
        winget configure --file C:\ArcBox\DSC\virtual_machines_itpro.dsc.yml --accept-configuration-agreements --disable-interactivity

    # Configure automatic start & stop action for the nested VMs
    Get-VM | Where-Object {$_.State -eq "Running"} |
        ForEach-Object -Parallel {
            Stop-VM -Force -Name $PSItem.Name
            Set-VM -Name $PSItem.Name -AutomaticStopAction ShutDown -AutomaticStartAction Start
            Start-VM -Name $PSItem.Name
        }
    Start-Sleep -Seconds 30

        Write-Header 'Creating VM Credentials'
        # Hard-coded username and password for the nested VMs
        $nestedLinuxUsername = 'jumpstart'
        $nestedLinuxPassword = 'JS123!!'

        # Create Linux credential object
        $secLinuxPassword = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
        $linCreds = New-Object System.Management.Automation.PSCredential ($nestedLinuxUsername, $secLinuxPassword)

        # Restarting Windows VM Network Adapters
        Write-Header 'Restarting Network Adapters'
        Start-Sleep -Seconds 5
        Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
        Invoke-Command -VMName $Win2k25vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
        Start-Sleep -Seconds 10

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested VMs
            Write-Header 'Renaming the nested Windows VMs'
            Invoke-Command -VMName $Win2k22vmName -ScriptBlock {

                if ($env:computername -cne $using:Win2k22vmName) {
                    Rename-Computer -NewName $using:Win2k22vmName -Restart
                }

            } -Credential $winCreds

            Invoke-Command -VMName $Win2k25vmName -ScriptBlock {

                if ($env:computername -cne $using:Win2k25vmName) {
                    Rename-Computer -NewName $using:Win2k25vmName -Restart
                }

            } -Credential $winCreds

            Write-Host 'Waiting for the nested Windows VMs to come back online...'

            Get-VM *Win* | Restart-VM -Force
            Get-VM *Win* | Wait-VM -For Heartbeat


        }

        # Getting the Ubuntu nested VM IP address
        $Ubuntu01VmIp = Get-VM -Name $Ubuntu01vmName | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0
        $Ubuntu02VmIp = Get-VM -Name $Ubuntu02vmName | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0

        # Configuring SSH for accessing Linux VMs
        Write-Output 'Generating SSH key for accessing nested Linux VMs'

        $null = New-Item -Path ~ -Name .ssh -ItemType Directory
        ssh-keygen -t rsa -N '' -f $Env:USERPROFILE\.ssh\id_rsa

        Copy-Item -Path "$Env:USERPROFILE\.ssh\id_rsa.pub" -Destination "$Env:TEMP\authorized_keys"

        # Automatically accept unseen keys but will refuse connections for changed or invalid hostkeys.
        Add-Content -Path "$Env:USERPROFILE\.ssh\config" -Value 'StrictHostKeyChecking=accept-new'

        Get-VM *Ubuntu*  | Wait-VM -For Heartbeat
        Get-VM *Ubuntu* | Copy-VMFile -SourcePath "$Env:TEMP\authorized_keys" -DestinationPath "/home/$nestedLinuxUsername/.ssh/" -FileSource Host -Force -CreateFullPath

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested linux VMs
            Write-Output 'Renaming the nested Linux VMs'

            Invoke-Command -HostName $Ubuntu01VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername -ScriptBlock {

                Invoke-Expression "sudo hostnamectl set-hostname $using:ubuntu01vmName;sudo systemctl reboot"

            }

            Restart-VM -Name $ubuntu01vmName -Force

            Invoke-Command -HostName $Ubuntu02VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername -ScriptBlock {

                Invoke-Expression "sudo hostnamectl set-hostname $using:ubuntu02vmName;sudo systemctl reboot"

            }

            Restart-VM -Name $ubuntu02vmName -Force

        }

        Get-VM *Ubuntu* | Wait-VM -For IPAddress

        Write-Host 'Waiting for the nested Linux VMs to come back online...waiting for 10 seconds'

        Start-Sleep -Seconds 10

        # Copy installation script to nested Windows VMs
        Write-Output 'Transferring installation script to nested Windows VMs...'
        Copy-VMFile $Win2k22vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
        Copy-VMFile $Win2k25vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ArcBoxDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force

        # Update Linux VM onboarding script connect to Azure Arc, get new token as it might have been expired by the time execution reached this line.
        $accessToken = ConvertFrom-SecureString ((Get-AzAccessToken -AsSecureString).Token) -AsPlainText
        (Get-Content -Path "$agentScript\installArcAgentUbuntu.sh" -Raw) -replace '\$accessToken', "'$accessToken'" -replace '\$resourceGroup', "'$resourceGroup'" -replace '\$tenantId', "'$Env:tenantId'" -replace '\$azureLocation', "'$Env:azureLocation'" -replace '\$subscriptionId', "'$subscriptionId'" | Set-Content -Path "$agentScript\installArcAgentModifiedUbuntu.sh"

        # Copy installation script to nested Linux VMs
        Write-Output 'Transferring installation script to nested Linux VMs...'

        Get-VM *Ubuntu* | Copy-VMFile -SourcePath "$agentScript\installArcAgentModifiedUbuntu.sh" -DestinationPath "/home/$nestedLinuxUsername" -FileSource Host -Force

        Write-Output 'Activating operating system on Windows VMs...'

        Invoke-Command -VMName $Win2k22vmName -ScriptBlock {

            cscript C:\Windows\system32\slmgr.vbs -ipk VDYBN-27WPP-V4HQT-9VMD4-VMK7H
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv

        } -Credential $winCreds

        Invoke-Command -VMName $Win2k25vmName -ScriptBlock {

            cscript C:\Windows\system32\slmgr.vbs -ipk D764K-2NDRG-47T6Q-P8T8W-YP6DF
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv

        } -Credential $winCreds

        Write-Header 'Onboarding Arc-enabled servers'

        # Onboarding the nested VMs as Azure Arc-enabled servers
        Write-Output 'Onboarding the nested Windows VMs as Azure Arc-enabled servers'
        Invoke-Command -VMName $Win2k22vmName, $Win2k25vmName -ScriptBlock { powershell -File $Using:nestedVMArcBoxDir\installArcAgent.ps1 -accessToken $using:accessToken, -tenantId $Using:tenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

        Write-Output 'Onboarding the nested Linux VMs as an Azure Arc-enabled servers'
        $UbuntuSessions = New-PSSession -HostName $Ubuntu01VmIp, $Ubuntu02VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername
        Invoke-JSSudoCommand -Session $UbuntuSessions -Command "sh /home/$nestedLinuxUsername/installArcAgentModifiedUbuntu.sh"

        Write-Header 'Installing Dependency Agent for Arc-enabled Windows servers'
        $VMs = @("$namingPrefix-SQL", "$namingPrefix-Win2K22", "$namingPrefix-Win2K25")
        $VMs | ForEach-Object -Parallel {

            $null = Connect-AzAccount -Identity -Tenant $using:tenantId -Subscription $using:subscriptionId -Scope Process -WarningAction SilentlyContinue

            $vm = $PSItem

            Write-Output "Invoking installation on $vm"

            # Install Dependency Agent
            $null = New-AzConnectedMachineExtension -ResourceGroupName $using:resourceGroup -MachineName $vm -Name DependencyAgentWindows -Publisher Microsoft.Azure.Monitoring.DependencyAgent -ExtensionType DependencyAgentWindows -Location $using:azureLocation -Settings @{"enableAMA" = $true} -NoWait

        }

        Write-Header 'Enabling SSH access and triggering update assessment for Arc-enabled servers'
        $VMs = @("$namingPrefix-SQL", "$namingPrefix-Ubuntu-01", "$namingPrefix-Ubuntu-02", "$namingPrefix-Win2K22", "$namingPrefix-Win2K25")
        $VMs | ForEach-Object -Parallel {
            $null = Connect-AzAccount -Identity -Tenant $using:tenantId -Subscription $using:subscriptionId -Scope Process -WarningAction SilentlyContinue

            $vm = $PSItem
            $connectedMachine = Get-AzConnectedMachine -Name $vm -ResourceGroupName $using:resourceGroup -SubscriptionId $using:subscriptionId
            $connectedMachineEndpoint = (Invoke-AzRestMethod -Method get -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default?api-version=2023-03-15").Content | ConvertFrom-Json

            if (-not ($connectedMachineEndpoint.properties | Where-Object { $_.type -eq 'default' -and $_.provisioningState -eq 'Succeeded' })) {
                Write-Output "Creating default endpoint for $($connectedMachine.Name)"
                $null = Invoke-AzRestMethod -Method put -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default?api-version=2023-03-15" -Payload '{"properties": {"type": "default"}}'
            }
            $connectedMachineSshEndpoint = (Invoke-AzRestMethod -Method get -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default/serviceconfigurations/SSH?api-version=2023-03-15").Content | ConvertFrom-Json

            if (-not ($connectedMachineSshEndpoint.properties | Where-Object { $_.serviceName -eq 'SSH' -and $_.provisioningState -eq 'Succeeded' })) {
                Write-Output "Enabling SSH on $($connectedMachine.Name)"
                $null = Invoke-AzRestMethod -Method put -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default/serviceconfigurations/SSH?api-version=2023-03-15" -Payload '{"properties": {"serviceName": "SSH", "port": 22}}'
            } else {
                Write-Output "SSH already enabled on $($connectedMachine.Name)"
            }

            Write-Output "Triggering Update Manager assessment on $($connectedMachine.Name)"
            $null = Invoke-AzRestMethod -Method POST -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$($connectedMachine.Name)/assessPatches?api-version=2020-08-15-preview" -Payload '{}'

        }
    } elseif ($Env:flavor -eq 'DataOps') {
        Write-Header 'Enabling SSH access to Arc-enabled servers'
        $null = Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId -Scope Process -WarningAction SilentlyContinue
        $connectedMachine = Get-AzConnectedMachine -Name $SQLvmName -ResourceGroupName $resourceGroup -SubscriptionId $subscriptionId
        $connectedMachineEndpoint = (Invoke-AzRestMethod -Method get -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default?api-version=2023-03-15").Content | ConvertFrom-Json
        if (-not ($connectedMachineEndpoint.properties | Where-Object { $_.type -eq 'default' -and $_.provisioningState -eq 'Succeeded' })) {
            Write-Output "Creating default endpoint for $($connectedMachine.Name)"
            $null = Invoke-AzRestMethod -Method put -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default?api-version=2023-03-15" -Payload '{"properties": {"type": "default"}}'
        }

        $connectedMachineSshEndpoint = (Invoke-AzRestMethod -Method get -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default/serviceconfigurations/SSH?api-version=2023-03-15").Content | ConvertFrom-Json
        if (-not ($connectedMachineSshEndpoint.properties | Where-Object { $_.serviceName -eq 'SSH' -and $_.provisioningState -eq 'Succeeded' })) {
            Write-Output "Enabling SSH on $($connectedMachine.Name)"
            $null = Invoke-AzRestMethod -Method put -Path "$($connectedMachine.Id)/providers/Microsoft.HybridConnectivity/endpoints/default/serviceconfigurations/SSH?api-version=2023-03-15" -Payload '{"properties": {"serviceName": "SSH", "port": 22}}'
        } else {
            Write-Output "SSH already enabled on $($connectedMachine.Name)"
        }

        Write-Output "Triggering Update Manager assessment on $($connectedMachine.Name)"
        $null = Invoke-AzRestMethod -Method POST -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$($connectedMachine.Name)/assessPatches?api-version=2020-08-15-preview" -Payload '{}'

    }

    # Removing the LogonScript Scheduled Task so it won't run on next reboot
    Write-Header 'Removing Logon Task'
    if ($null -ne (Get-ScheduledTask -TaskName 'ArcServersLogonScript' -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName 'ArcServersLogonScript' -Confirm:$false
    }
}

# Triggering Azure Policy compliance scan
Write-Header 'Triggering Azure Policy compliance scan'
Start-AzPolicyComplianceScan -ResourceGroupName $resourceGroup -AsJob

#Changing to Jumpstart ArcBox wallpaper
Write-Header 'Changing wallpaper'

# bmp file is required for BGInfo
Convert-JSImageToBitMap -SourceFilePath "$Env:ArcBoxDir\wallpaper.png" -DestinationFilePath "$Env:ArcBoxDir\wallpaper.bmp"

Set-JSDesktopBackground -ImagePath "$Env:ArcBoxDir\wallpaper.bmp"

if ($Env:flavor -eq 'ITPro') {

    Write-Header 'Running tests to verify infrastructure'

    & "$Env:ArcBoxTestsDir\Invoke-Test.ps1"

}