Start-Transcript -Path C:\tmp\config.log

Invoke-WebRequest "https://github.com/microsoft/azure_arc/raw/master/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/AdventureWorksLT2019.bak" -OutFile "C:\tmp\AdventureWorksLT2019.bak"
Start-Sleep -Seconds 3
Restore-SqlDatabase -ServerInstance $env:COMPUTERNAME -Database "AdventureWorksLT2019" -BackupFile "C:\tmp\AdventureWorksLT2019.bak" -AutoRelocateFile -PassThru -Verbose

# These settings will be replaced by the portal when the script is generated
$subId = "${subId}"
$resourceGroup = "${resourceGroup}"
$location = "${location}"

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
$servicePrincipalAppId = "${servicePrincipalAppId}"
$servicePrincipalTenantId = "${servicePrincipalTenantId}"
$servicePrincipalSecret = "${servicePrincipalSecret}"

# Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254
# New-NetFirewallRule -Name AllowODS -DisplayName "Allow ODS opinsights" -Enabled True -Profile Any -Direction Outbound -Action Allow -RemoteAddress *.ods.opinsights.azure.com
# New-NetFirewallRule -Name AllowODS -DisplayName "Allow OMS opinsights" -Enabled True -Profile Any -Direction Outbound -Action Allow -RemoteAddress *.ods.opinsights.azure.com
# New-NetFirewallRule -Name AllowODS -DisplayName "Allow ODS opinsights" -Enabled True -Profile Any -Direction Outbound -Action Allow -RemoteAddress *.ods.opinsights.azure.com
New-NetFirewallRule -Name AllowAnyInbound -DisplayName "Allow Any Inbound" -Enabled True -Profile Any -Direction Inbound -Protocol Any -Action Allow -RemoteAddress Any


$azurePassword = ConvertTo-SecureString $env:servicePrincipalSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalAppId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:servicePrincipalTenantId -ServicePrincipal

Register-AzResourceProvider -ProviderNamespace Microsoft.AzureData

function registerArcForServers() {
    # Download the package
    #
    $ProgressPreference = "SilentlyContinue"; 
    Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi
    
    # Install the package
    #
    Write-Host "Installing the Azure Arc for Servers package"
    $params = @("/i", "AzureConnectedMachineAgent.msi", "/l*v", "installationlog.txt", "/qn")
    
    $install_success = (Start-Process -FilePath msiexec.exe -ArgumentList $params -Wait -Passthru).ExitCode
    if ($install_success -ne 0) {
        Write-Error -Message "Azure Arc for Servers package installation failed."
        return
    }

    if ($proxy) {
        # Set the proxy environment variable. Note that authenticated proxies are not supported for Public Preview.
        [System.Environment]::SetEnvironmentVariable("https_proxy", $proxy, "Machine")
        $env:https_proxy = [System.Environment]::GetEnvironmentVariable("https_proxy", "Machine")
        
        # The agent service needs to be restarted after the proxy environment variable is set in order for the changes to take effect.
        Restart-Service -Name himds
    }

    Write-Host "Running Azure Connected Machine Agent"
    $context = Get-AzContext

    if ($env:servicePrincipalAppId -And $env:servicePrincipalTenantId -And $env:servicePrincipalSecret) {
        & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
            --service-principal-id $env:servicePrincipalAppId `
            --service-principal-secret $env:servicePrincipalSecret `
            --resource-group $env:resourceGroup `
            --location $env:location `
            --subscription-id $env:subId `
            --tenant-id $context.Tenant `
            --tags "Project=jumpstart_azure_arc_sql"
    }
    else {
        & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
            --resource-group $env:resourceGroup `
            --location $env:location `
            --subscription-id $env:subId `
            --tenant-id $context.Tenant `
            --tags "Project=jumpstart_azure_arc_sql"
    }

    if ($LastExitCode -ne 0) {
        Write-Error -Message "Failure when connecting Azure Connected Machine Agent."
        return
    }
}

function checkResourceCreation($newResource, $instProp, $name) {
    if ($null -eq $newResource) {
        Write-Host ("Failed to create resource: {0}" -f $name)
        return
    }
    else {
        Write-Host ("SQL Server - Azure Arc resource: {0} created" -f $resource_name)
    }
    $errors = New-Object System.Collections.ArrayList
    foreach ($key in $instProp.Keys) {
        # check that key exists in created resource
        if (Get-Member -inputobject $newResource.Properties -name $key -Membertype Properties) {
            $expectedvalue = $instProp[$key]
            $foundValue = ($newResource.Properties).$key
            if ($expectedvalue -ne $foundValue) {
                $errors.Add("Property {0} has value of {1}, but expected {2}" -f $key, $foundValue, $expectedvalue) > $null
            }
        }
        else {
            $errors.Add("Property {0} expected, but not present in Azure Resource" -f $key) > $null
        }
    }
    if ($errors.Count -ne 0) {
        Write-Host ("Errors found when creating resource: {0}" -f $newResource.Name)
        foreach ($e in $errors) {
            Write-Error $e
        }
    }
    else {
        $newResource
    }
}

# Initial checks
# Make sure that we've logged in, and that modules are installed
#
if (-Not (Get-Module -ListAvailable -Name Az.Resources, Az.Accounts)) {
    Write-Error -Category NotInstalled -Message "Install Azure module with `"Install-Module -Name Az -AllowClobber`" before continuing."
    return
}

$context = Get-AzContext
if (!$context) {
    Write-Error -Category AuthenticationError -Message "Please connect your Azure account with `"Connect-AzAccount`" before continuing."
    return
}

Set-AzContext -Subscription $env:subId
$arcResource = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -Name $env:computername

if ($null -eq $arcResource) {
    Write-Host "Arc for Servers resource not found. Registering the current machine now."  
    
    registerArcForServers

    $timeout = New-TimeSpan -Seconds 30
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        $arcResource = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -Name $env:computername
        start-sleep -seconds 10
    } while ($null -eq $arcResource -and $stopwatch.elapsed -lt $timeout)

    if ($null -eq $arcResource) {
        Write-Error -Message "Failed to find Arc for Servers resource, registration failed."
        return
    }
}

# Iterate over SQL Instances
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server') {
    $inst = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
    if ($inst.Count -eq 0) {
        Write-Error -Category NotInstalled -Message "SQL Server is not installed on this machine."
        return
    }
    foreach ($i in $inst) {
        # Read registry data
        #
        $p = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$i        
        $setupValues = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup")
        $instEdition = ($setupValues.Edition -split ' ')[0]
        $portInfo = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\MSSQLServer\SuperSocketNetLib\Tcp\IPAll")
        $currentVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\MSSQLServer\CurrentVersion")

        switch -wildcard ($setupValues.Version) {
            "15*" { $versionname = "SQL Server 2019"; }
            "14*" { $versionname = "SQL Server 2017"; }
            "13*" { $versionname = "SQL Server 2016"; }
            "12*" { $versionname = "SQL Server 2014"; }
            "11*" { $versionname = "SQL Server 2012"; }
            "10.5*" { $versionname = "SQL Server 2008 R2"; }
            "10.4*" { $versionname = "SQL Server 2008"; }
            "10.3*" { $versionname = "SQL Server 2008"; }
            "10.2*" { $versionname = "SQL Server 2008"; }
            "10.1*" { $versionname = "SQL Server 2008"; }
            "10.0*" { $versionname = "SQL Server 2008"; }
            "9*" { $versionname = "SQL Server 2005"; }
            "8*" { $versionname = "SQL Server 2000"; }
            default { $versionname = $setupValues.Version; }
        }

        $createTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss tt")

        # Populate instance properties
        #
        $instProp = @{
            version             = $versionname
            edition             = $instEdition
            containerResourceId = $arcResource.Name
            createTime          = $createTime
            status              = 'Connected'
            patchLevel          = $setupValues.PatchLevel
            instanceName        = $i
            collation           = $setupValues.Collation
            currentVersion      = $currentVersion.CurrentVersion
        }
        if ($null -ne $setupValues.ProductID) {
            $instProp["productId"] = $setupValues.ProductID
        }
        if ("" -ne $portInfo.TcpPort) {
            $instProp["tcpPorts"] = $portInfo.TcpPort
        }
        if ("" -ne $portInfo.TcpDynamicPorts) {
            $instProp["tcpDynamicPorts"] = $portInfo.TcpDynamicPorts
        }
            
        # Locate the error log
        # Retry finding the error log for up to3 seconds, in case the error log is unavailable
        #
        $errorLogPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").SQLPath

        $timeout = New-TimeSpan -Seconds 3
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            $metadata_files = Select-String -Path "$errorLogPath\Log\ERRORLOG*" -Pattern "SQL Server is starting" -List
        }  while ($metadata_files.count -eq 0 -and $stopwatch.elapsed -lt $timeout)
            
        if ($metadata_files.count -gt 0) {
            $error_log = ($metadata_files | ForEach-Object -Process { Get-item $_.Path } | Sort-Object LastWriteTime -Descending)[0]
            $licensing_info_line = Select-String -Path $error_log.FullName -Pattern "SQL Server licensing" -List
                
            if ( $null -ne $licensing_info_line ) {
                    
                ((Select-String -Path $error_log.FullName -Pattern "SQL Server licensing" -List).Line -split ';')[1] -match "(?<vCores>\d)"
                    
                if ($Matches.ContainsKey("vCores")) {
                    $instProp.Add("vCore", $Matches.vCores)
                }
            }                
        }
        else {
            Write-Warning -Message "Could not locate SQL Server startup errorlog at $errorLogPath\Log. The vCore property will not be present in the registered resource."
        }

        $resource_name = $env:computername
        if ($i -ne "MSSQLSERVER") {
            $resource_name = '{0}_{1}' -f $env:computername, $i
        }

        # Create resource
        #
        $newResource = New-AzResource -Location $env:location -Properties $instProp -ResourceName $resource_name -ResourceType Microsoft.AzureData/sqlServerInstances -ResourceGroupName $env:resourceGroup -Tag @{Project="jumpstart_azure_arc_sql"} -Force 
        checkResourceCreation -newResource $newResource -instProp $instProp -name $resource_name
    }
}
else {
    Write-Error -Category NotInstalled -Message "SQL Server is not installed on this machine." 
}




az login --service-principal --username $env:servicePrincipalAppId --password $env:servicePrincipalSecret --tenant $env:servicePrincipalTenantId

# Set Log Analytics Workspace Environment Variables
$WorkspaceName = "log-analytics-" + (Get-Random -Maximum 99999)

# Get the Resource Group
Get-AzResourceGroup -Name $env:resourceGroup -ErrorAction Stop -Verbose

# Create the workspace
New-AzOperationalInsightsWorkspace -Location $env:location -Name $WorkspaceName -Sku Standard -ResourceGroupName $env:resourceGroup -Verbose

Write-Host "Enabling Log Analytics Solutions"
$Solutions = "Security", "Updates", "SQLAssessment"
foreach ($solution in $Solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $env:resourceGroup -WorkspaceName $WorkspaceName -IntelligencePackName $solution -Enabled $true -Verbose
}

# Get the workspace ID and Key
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $WorkspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $WorkspaceName --query primarySharedKey -o tsv)

# Deploy MMA Azure Extension ARM Template
New-AzResourceGroupDeployment -Name MMA `
  -ResourceGroupName $env:resourceGroup `
  -arcServerName $env:computername `
  -location $env:location `
  -workspaceId $workspaceId `
  -workspaceKey $workspaceKey `
  -TemplateFile C:\tmp\mma.json

Write-Host "Configuring SQL Azure Assessment"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/Microsoft.PowerShell.Oms.Assessments.zip" -OutFile "C:\tmp\Microsoft.PowerShell.Oms.Assessments.zip"
Expand-Archive "C:\tmp\Microsoft.PowerShell.Oms.Assessments.zip" -DestinationPath 'C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell'
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Fusion" -Name "EnableLog" -Value 1 -PropertyType "DWord"
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\"
Import-Module "C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\Microsoft.PowerShell.Oms.Assessments.dll"
$SecureString = ConvertTo-SecureString $env:adminPassword -AsPlainText -Force
Add-SQLAssessmentTask -SQLServerName $env:computername -WorkingDirectory "C:\sql_assessment\work_dir" -RunWithManagedServiceAccount $False -ScheduledTaskUsername $env:USERNAME -ScheduledTaskPassword $SecureString



Stop-Transcript