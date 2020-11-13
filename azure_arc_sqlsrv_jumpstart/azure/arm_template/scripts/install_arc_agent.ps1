# These settings will be replaced by the portal when the script is generated
$subId = "${subscriptionId}"
$resourceGroup = "${resourceGroup}"
$location = "${location}"

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
$servicePrincipalAppId = "${appId}"
$servicePrincipalTenantId = "${tenantId}"
$servicePrincipalSecret = "${password}"

$azurePassword = ConvertTo-SecureString $servicePrincipalSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($servicePrincipalAppId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $servicePrincipalTenantId -ServicePrincipal

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

    if ($servicePrincipalAppId -And $servicePrincipalTenantId -And $servicePrincipalSecret) {
        & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
            --service-principal-id $servicePrincipalAppId `
            --service-principal-secret $servicePrincipalSecret `
            --resource-group $resourceGroup `
            --location $location `
            --subscription-id $subId `
            --tenant-id $context.Tenant `
            --tags "Project=jumpstart_azure_arc_sql"
    }
    else {
        & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
            --resource-group $resourceGroup `
            --location $location `
            --subscription-id $subId `
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

Set-AzContext -Subscription $subId
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
        $newResource = New-AzResource -Location $location -Properties $instProp -ResourceName $resource_name -ResourceType Microsoft.AzureData/sqlServerInstances -ResourceGroupName $resourceGroup -Tag @{Project="jumpstart_azure_arc_sql"} -Force 
        checkResourceCreation -newResource $newResource -instProp $instProp -name $resource_name
    }
}
else {
    Write-Error -Category NotInstalled -Message "SQL Server is not installed on this machine." 
}