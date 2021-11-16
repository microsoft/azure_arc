param (
    [string]$servicePrincipalAppId,
    [string]$servicePrincipalSecret,        
    [string]$servicePrincipalTenantId
)

Start-Transcript -Path C:\Temp\installArcAgentSQL.log
$ErrorActionPreference = 'SilentlyContinue'

# These settings will be replaced by the portal when the script is generated
$subId = $subscriptionId
$resourceGroup = $myResourceGroup
$location = $Azurelocation
$proxy=""
$resourceTags= @{"Project"="jumpstart_arcbox"}
$workspaceName = $logAnalyticsWorkspaceName

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
# For security purposes, passwords should be stored in encrypted files as secure strings
#
$servicePrincipalAppId = $spnClientId
$servicePrincipalTenantId = $spnTenantId
$servicePrincipalSecret = $spnClientSecret

$azurePassword = ConvertTo-SecureString $servicePrincipalSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($servicePrincipalAppId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $servicePrincipalTenantId -ServicePrincipal

# Register-AzResourceProvider -ProviderNamespace Microsoft.AzureData

$unattended = $servicePrincipalAppId -And $servicePrincipalTenantId -And $servicePrincipalSecret

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

    Write-Host "Connecting Azure Connected Machine Agent"
    $context = Get-AzContext
    $params = @("connect", "--resource-group", $resourceGroup, "--location", $location, "--subscription-id", $subId, "--tenant-id", $context.Tenant, "--tags", $resourceTags, "--correlation-id", "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a")

    if ($unattended) {
        $password = $servicePrincipalSecret
        if ($servicePrincipalSecret -is [SecureString]) {
            $cred = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipalAppId, $servicePrincipalSecret)
            $password = $cred.GetNetworkCredential().Password
        } 
        $params += "--service-principal-id"
        $params += $servicePrincipalAppId
        $params += "--service-principal-secret"
        $params += $password
    }
    elseif (Get-InstalledModule -Name Az.Accounts -MinimumVersion 2.2) {
        # New versions of Az.Account support getting access tokens
        #
        $token = Get-AzAccessToken
        $params += "--access-token"
        $params += $token.Token
    }

    & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" $params

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
            Write-Warning $e
        }
    }
    else {
        $newResource
    }
}

function installPowershellModule() {
    # Ask for user confirmation if running manually
    #
    if ( ! $unattended) {
        $title = 'Confirm Dependency Installation'
        $question = 'The Azure PowerShell Module is required in order to register SQL Server - Azure Arc resources. Would you like to install it now?'
        $choices = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 1) {
            Write-Warning "Azure module install declined."
            return
        }
    }
    # Check if requirements are met for Powershell module install
    #
    $version = $PSVersionTable.PSVersion
    if ([version]$version -lt [version]"5.1") {
        Write-Error "Could not install Az module: Az module requires Powershell version 5.1.* or above."
        return
    }
    if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
        if ([version]$version -lt [version]"6.2.4") {
            Write-Error -Message ("Could not install Az module: Powershell $version does not support having both the AzureRM and Az modules installed. " + 
                "If you need to keep AzureRM available on your system, install the Az module for PowerShell 6.2.4 or later. " +
                "For more information, see: https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az")
            return
        }
            
        Write-Warning -Message "The Az module will be installed alongside the existing AzureRM module."
    }

    Write-Host "Installing Az module for PowerShell"
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
}

# Confirm that Azure powershell module is installed, and install if not present
#
if (-Not (Get-Module -ListAvailable -Name Az.Resources, Az.Accounts -ErrorAction SilentlyContinue)) {
    installPowershellModule
    if (-Not (Get-Module -ListAvailable -Name Az.Resources, Az.Accounts)) {
        Write-Error -Category NotInstalled -Message "Failed to install Azure Powershell Module. Please confirm that Az module is installed before continuing."
        return
    }
}

# For manual Azure Arc registration, an access token prevents a duplicate Azure login
# Getting an access token is only supported in Az.Accounts 2.2 or up
#
if (-Not (Get-InstalledModule -Name Az.Accounts -MinimumVersion 2.2) -and -Not $unattended) {
    Write-Warning "For the best user experience, we recommend updating the Az.Accounts module"
    Update-Module -Name Az.Accounts -Confirm
}

# Confirm that user is signed in to Azure powershell module
#
$context = Get-AzContext
if (!$context) {
    if ($unattended) {
        $securePassword = $servicePrincipalSecret
        if ($servicePrincipalSecret -is [String]) {
            Write-Warning -Message "Saving a plaintext password presents a security risk. Consider storing your password in a secure file."
            $securePassword = ConvertTo-SecureString -String $servicePrincipalSecret -AsPlainText -Force
        } 
        $pscredential = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipalAppId, $securePassword)
        Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $servicePrincipalTenantId
    }
    else {
        Connect-AzAccount -UseDeviceAuthentication
    }
    $context = Get-AzContext
    if (!$context) {
        Write-Error -Category AuthenticationError -Message "Please connect your Azure account with `"Connect-AzAccount`" before continuing."
            return
       }
}
Set-AzContext -Subscription $subId

# Check if machine is registered with Azure Arc for Servers
# Register machine if necessary
#
$arcResource = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -Name $env:computername -ResourceGroupName $resourceGroup
if ($null -eq $arcResource) {
    Write-Host "Arc for Servers resource not found. Registering the current machine now."

    registerArcForServers

    $timeout = New-TimeSpan -Seconds 30
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        $arcResource = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -Name $env:computername -ResourceGroupName $resourceGroup
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

        # Populate instance properties
        #
    $instProp = @{
        version             = $versionname
            edition             = $instEdition
            containerResourceId = $arcResource.ResourceId
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
        $instProp["tcpStaticPorts"] = $portInfo.TcpPort
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
    } while ($metadata_files.count -eq 0 -and $stopwatch.elapsed -lt $timeout)

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

    $resource_name = hostname
    if ($i -ne "MSSQLSERVER") {
        $resource_name = '{0}_{1}' -f $env:computername, $i
    }

        # Create resource
        #
    $newResource = New-AzResource -Location $location -Properties $instProp -ResourceName $resource_name -Tags $resourceTags -ResourceType Microsoft.AzureArcData/sqlServerInstances -ResourceGroupName $resourceGroup -Force
    checkResourceCreation -newResource $newResource -instProp $instProp -name $resource_name
}
}
else {
    Write-Error -Category NotInstalled -Message "SQL Server is not installed on this machine."
}

az login --service-principal --username $servicePrincipalAppId --password $servicePrincipalSecret --tenant $servicePrincipalTenantId
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Fusion" -Name "EnableLog" -Value 1 -PropertyType "DWord"

If(-not(Get-InstalledModule SQLServer -ErrorAction silentlycontinue)){
    Install-Module SQLServer -Confirm:$False -Force
}

Write-Host "Enable SQL TCP"
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules"
Import-Module -Name "sqlps"
$smo = 'Microsoft.SqlServer.Management.Smo.'  
$wmi = new-object ($smo + 'Wmi.ManagedComputer').  
# List the object properties, including the instance names.  
$Wmi

# Enable the TCP protocol on the default instance.  
$uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']" 
$Tcp = $wmi.GetSmoObject($uri)  
$Tcp.IsEnabled = $true  
$Tcp.Alter()  
$Tcp

# Enable the named pipes protocol for the default instance.  
$uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']"  
$Np = $wmi.GetSmoObject($uri)  
$Np.IsEnabled = $true  
$Np.Alter()  
$Np

Restart-Service -Name 'MSSQLSERVER' -Force

# Get the resource group
Get-AzResourceGroup -Name $resourceGroup -ErrorAction Stop -Verbose

Write-Host "Enabling Log Analytics Solutions"
$Solutions = "Security", "Updates", "SQLAssessment"
foreach ($solution in $Solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $resourceGroup -WorkspaceName $workspaceName -IntelligencePackName $solution -Enabled $true -Verbose
}

# Get the workspace ID and Key
$workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName --query primarySharedKey -o tsv)

$Setting = @{ "workspaceId" = $workspaceId }
$protectedSetting = @{ "workspaceKey" = $workspaceKey }
New-AzConnectedMachineExtension -Name "MicrosoftMonitoringAgent" -ResourceGroupName $resourceGroup -MachineName $env:computername -Location $location -Publisher "Microsoft.EnterpriseCloud.Monitoring" -TypeHandlerVersion "1.0.18040.2" -Settings $Setting -ProtectedSetting $protectedSetting -ExtensionType "MicrosoftMonitoringAgent"

$nestedWindowsUsername = "Administrator"
$nestedWindowsPassword = "ArcDemo123!!"

Write-Host "Create SQL Azure Assessment"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/Microsoft.PowerShell.Oms.Assessments.zip" -OutFile "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip"
Expand-Archive "C:\Temp\Microsoft.PowerShell.Oms.Assessments.zip" -DestinationPath 'C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell'
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\"
Import-Module "C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\Microsoft.PowerShell.Oms.Assessments.dll"
$SecureString = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
Add-SQLAssessmentTask -SQLServerName $env:computername -WorkingDirectory "C:\sql_assessment\work_dir" -RunWithManagedServiceAccount $False -ScheduledTaskUsername $env:USERNAME -ScheduledTaskPassword $SecureString

$name = "Recurring HealthService Restart"
$repeat = (New-TimeSpan -Minutes 10)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Restart-Service -Name HealthService -Force"
$duration = (New-TimeSpan -Days 1)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval $repeat -RepetitionDuration $duration
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -RunLevel Highest -User $nestedWindowsUsername -Password $nestedWindowsPassword -Settings $settings
Start-Sleep -Seconds 3
Start-ScheduledTask -TaskName $name

Stop-Transcript