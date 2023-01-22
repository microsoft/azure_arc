# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

$WarningPreference = "SilentlyContinue"

Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-SQLMI.log

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$context = Get-AzContext # Azure credential

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes -Confirm:$false
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration -Confirm:$false

# Install latest versions of Nuget and PowershellGet
Write-Header "Install latest versions of Nuget and PowershellGet"
Invoke-Command -VMName $SDNConfig.HostList -Credential $adcred -ScriptBlock {
    Enable-PSRemoting -Force
    Install-PackageProvider -Name NuGet -Force 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module -Name PowershellGet -Force
}

# Install necessary AZ modules and initialize akshci on each node
Write-Header "Install necessary AZ modules, AZ CLI extensions, plus AksHCI module and initialize akshci on each node"

Invoke-Command -VMName $SDNConfig.HostList  -Credential $adcred -ScriptBlock {
    Write-Host "Installing Required Modules"
    Install-Module -Name AksHci -Force -AcceptLicense
    Import-Module Az.Accounts
    Import-Module Az.Resources
    Import-Module AzureAD
    Import-Module AksHci
    Initialize-AksHciNode
}

# Downloading artifacts for Azure Arc Data services
Write-Header "Downloading artifacts for Azure Arc Data services"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:HCIBoxKVDir\dataController.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:HCIBoxKVDir\dataController.parameters.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/adConnector.json") -OutFile $Env:HCIBoxKVDir\adConnector.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/adConnector.parameters.json") -OutFile $Env:HCIBoxKVDir\adConnector.parameters.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmiAD.json") -OutFile $Env:HCIBoxKVDir\sqlmiAD.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmiAD.parameters.json") -OutFile $Env:HCIBoxKVDir\sqlmiAD.parameters.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile $Env:HCIBoxKVDir\settingsTemplate.json
Invoke-WebRequest ("https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable") -OutFile $Env:HCIBoxKVDir\azuredatastudio.zip

Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.json" -DestinationPath "C:\VHD\dataController.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.parameters.json" -DestinationPath "C:\VHD\dataController.parameters.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\adConnector.json" -DestinationPath "C:\VHD\adConnector.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\adConnector.parameters.json" -DestinationPath "C:\VHD\adConnector.parameters.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\sqlmiAD.json" -DestinationPath "C:\VHD\sqlmiAD.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\sqlmiAD.parameters.json" -DestinationPath "C:\VHD\sqlmiAD.parameters.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\settingsTemplate.json" -DestinationPath "C:\VHD\settingsTemplate.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\azuredatastudio.zip" -DestinationPath "C:\VHD\azuredatastudio.zip" -FileSource Host

# Generate unique name for workload cluster
$rand = New-Object System.Random
$prefixLen = 5
[string]$namingPrefix = ''
for ($i = 0; $i -lt $prefixLen; $i++) {
    $namingPrefix += [char]$rand.Next(97, 122)
}
$clusterName = $SDNConfig.AKSDataSvcsworkloadClusterName + "-" + $namingPrefix
[System.Environment]::SetEnvironmentVariable('AKS-DataSvcs-ClusterName', $clusterName, [System.EnvironmentVariableTarget]::Machine)

# Initializing variables
$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$adminUsername = $env:adminUsername
$adminPassword = $env:adminPassword
$workspaceName = $env:workspaceName
$customLocationObjectId = $env:customLocationObjectId
$dataController = "arcbox-dc-$namingPrefix"
$sqlMI = "jumpstart-sql"
$customLocation = "jumpstart-cl-$namingPrefix"
$domainName = "jumpstart"
$defaultDomainPartition = "DC=$domainName,DC=local"

# Create new AKS target cluster and connect it to Azure
Write-Header "Creating AKS target cluster"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-AksHciCluster -name $using:clusterName -nodePoolName sqlminodepool -nodecount 3 -osType linux -nodeVmSize Standard_D8s_v3
    Enable-AksHciArcConnection -name $using:clusterName
}

Write-Header "Checking AKS-HCI nodes and running pods"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl get nodes
    kubectl get pods -A
}

# Setting up azure cli
Write-Host "Setting up azure cli"
foreach ($VM in $SDNConfig.HostList) {
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path + ";C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin", [System.EnvironmentVariableTarget]::Machine)
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $ErrorActionPreference = "Continue"
        az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
        az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId
        az extension add --name arcdata --system --only-show-errors
    }
}

# Deploying the Arc Data Controller
Write-Host "Deploying the Arc Data Controller"
Write-Host "`n"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $WarningPreference = "SilentlyContinue"
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    Write-Host "Installing the Arc Data extension"
    Write-Host "`n"
    az k8s-extension create --name arc-data-services `
        --extension-type microsoft.arcdataservices `
        --cluster-type connectedClusters `
        --cluster-name $using:clusterName `
        --resource-group $using:rg `
        --auto-upgrade false `
        --scope cluster `
        --release-namespace arc `
        --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper `
        --only-show-errors
        

    Write-Host "`n"

    Do {
        Write-Host "Waiting for bootstrapper pod, hold tight..."
        Write-Host "`n"
        kubectl get pods -n arc
        Write-Host "`n"
        Start-Sleep -Seconds 20
        $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($podStatus -eq "Nope")
    Write-Host "Bootstrapper pod is ready!"
    Write-Host "`n"
}

# Configuring Azure Arc Custom Location on the cluster
Write-Header "Configuring Azure Arc Custom Location"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $WarningPreference = "SilentlyContinue"
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    $connectedClusterId = az connectedk8s show --name $using:clusterName --resource-group $using:rg --query id -o tsv
    az connectedk8s enable-features -n $using:clusterName -g $using:rg --custom-locations-oid $using:customLocationObjectId --features cluster-connect custom-locations --only-show-errors
    $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $using:clusterName --resource-group $using:rg --query id -o tsv
    Start-Sleep -Seconds 20
    az customlocation create --name $using:customLocation --resource-group $using:rg --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId 

    $customLocationId = $(az customlocation show --name $using:customLocation --resource-group $using:rg --query id -o tsv)

    $workspaceId = $(az resource show --resource-group $using:rg --name $using:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $using:rg --workspace-name $using:workspaceName --query primarySharedKey -o tsv)

    $dataControllerParams = "C:\VHD\dataController.parameters.json"

    (Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', $using:dataController | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $using:rg | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $using:adminUsername | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $using:adminPassword | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $using:subId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $using:spnClientId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $using:spnTenantId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $using:spnSecret | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

    az deployment group create --resource-group $using:rg --template-file "C:\VHD\dataController.json" --parameters "C:\VHD\dataController.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
        Start-Sleep -Seconds 55
        Write-Host "`n"
        kubectl get pods -n arc
        Write-Host "`n"
        Start-Sleep -Seconds 10
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc data controller is ready!"
    Write-Host "`n"
}

# Preparing AD for SQL MI AD authenticaion
Write-Header "Preparing Active directory for SQL MI AD authenticaion"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    $WarningPreference = "SilentlyContinue"
    Add-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
    Add-WindowsFeature -Name "RSAT-DNS-Server" -IncludeAllSubFeature
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    $dcInfo = Get-ADDomainController -discover -domain $using:domainName
    $sqlmiouName = "ArcSQLMI"
    $sqlmiOUDN = "OU=" + $sqlmiouName + "," + $using:defaultDomainPartition
    $sqlmi_port = 11433
    $dcIPv4 = ([System.Net.IPAddress]$dcInfo.IPv4Address).GetAddressBytes()
    $reverseLookupCidr = [System.String]::Concat($dcIPv4[0], '.', $dcIPv4[1], '.', $dcIPv4[2], '.0/24')

    Write-Host "Reverse lookup zone CIDR $reverseLookupCidr"
    # Setup reverse lookup zone
    # check if reverse DNS already setup
    $ReverseDnsZone = Get-DnsServerZone -ComputerName $dcInfo.HostName | Where-Object { $_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true }
    if ($null -eq $ReverseDnsZone) {
        try {
            Add-DnsServerPrimaryZone -NetworkId $reverseLookupCidr -ReplicationScope Domain -ComputerName $dcInfo.HostName
            Write-Host "Successfully created reverse DNS Zone."

            $ReverseDnsZone = Get-DnsServerZone -ComputerName $dcInfo.HostName | Where-Object { $_.IsAutoCreated -eq $false -and $_.IsReverseLookupZone -eq $true }
        }
        catch {
            # Reverse DNS already setup
            Write-Host "Failed to create Reverse DNS Zone."
            Exit
        }
    }
    else {
        Write-Host "Reverse DNS Zone ${ReverseDnsZone.Name} already exists for this domain controller."
    }

    # Create reverse DNS for domain controller
    if ($null -ne $ReverseDnsZone) {
        try {
            Add-DNSServerResourceRecordPTR -ZoneName $ReverseDnsZone.ZoneName -Name $dcIPv4[3] -PTRDomainName $dcInfo.HostName -ComputerName  $dcInfo.HostName
            Write-Host "Created PTR record for domain controller."
        }
        catch {
            Write-Host "Failed to create domain controller PTR record or PTR record already exists."
        }
    }
    else {
        Write-Host "Failed to create reverse DNS lookup zone or zone does not exist."
        Exit
    }

    # Create ArcSQLMI OU
    Write-Host "Creating the SQL MI OU in Active directory"
    Write-Host "`n"
    try {
        $ou = Get-ADOrganizationalUnit -Identity $sqlmiOUDN
        if ($null -ne $ou -and $ou.Name.Length -gt 0) {
            Write-Host "Organization Unit $sqlmiouName already exist. Skipping this step."
        }
        else {
            Write-Host "Organization Unit $sqlmiouName does not exist. Creating new OU."
            New-ADOrganizationalUnit -Name $sqlmiouName -Path $using:defaultDomainPartition -ProtectedFromAccidentalDeletion $False
        }
    }
    catch {
        Write-Host "Organization Unit $sqlmiOu does not exist. Creating new OU."
        New-ADOrganizationalUnit -Name $sqlmiouName -Path $using:defaultDomainPartition -ProtectedFromAccidentalDeletion $False
    }

    # Deploying Active Directory connector and Azure Arc SQL MI
    Write-Host "Deploying Active Directory connector"
    Write-Host "`n"

    # Creating endpoints file
    Write-Host "Creating endpoints file"
    Write-Host "`n"
    $filename = "SQLMIEndpoints.txt"
    $file = New-Item -Path "C:\VHD" -Name $filename -ItemType "file"
    $Endpoints = $file.FullName

    $sqlMIName = $using:sqlMI
    $sqlmi_fqdn_name = $sqlMIName + "." + $dcInfo.domain
    $sqlmi_secondary_fqdn_name = $sqlMIName + "-secondary." + $dcInfo.domain

    # Create dedicated service account for AD connector
    Write-Host "Creating dedicated service account for AD connector"
    Write-Host "`n"
    $arcsaname = "sa-$sqlMIName"
    $arcsapass = "ArcDSA#Pwd123$"
    $arcsasecpass = $arcsapass | ConvertTo-SecureString -AsPlainText -Force
    $sqlmisaupn = $arcsaname + "@" + $dcInfo.domain

    $samaccountname = $arcsaname
    $domain_netbios_name = $dcInfo.domain.split('.')[0].ToUpper();
    $domain_name = $dcInfo.domain.ToUpper()

    try {
        New-ADUser -Name $arcsaname `
            -UserPrincipalName $sqlmisaupn `
            -Path $sqlmiOUDN `
            -AccountPassword $arcsasecpass `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires $true
    }
    catch {
        # User already exists
        Write-Host "User $arcsaname already existings in the directory."
    }

    Start-Sleep -Seconds 10
    # Geneate key tab
    Write-Host "Gerating key tab for primary and secondary SQL MI instance"
    Write-Host "`n"
    try {
        setspn -A MSSQLSvc/${sqlmi_fqdn_name} ${domain_netbios_name}\${samaccountname}
        setspn -A MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port} ${domain_netbios_name}\${samaccountname}
    
        # Secondary instance spn
        setspn -A MSSQLSvc/${sqlmi_secondary_fqdn_name} ${domain_netbios_name}\${samaccountname}
        setspn -A MSSQLSvc/${sqlmi_secondary_fqdn_name}:${sqlmi_port} ${domain_netbios_name}\${samaccountname}
    
        $keytab_file = "C:\VHD\$sqlMIName.keytab"
        ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        
        # Generate Keytab for secondary
        ktpass /princ MSSQLSvc/${sqlmi_secondary_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_secondary_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_secondary_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ MSSQLSvc/${sqlmi_secondary_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        
        ktpass /princ ${samaccountname}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        ktpass /princ ${samaccountname}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
        # Convert key tab file into base64 data
        $keytabrawdata = Get-Content $keytab_file -Encoding byte
        $b64keytabtext = [System.Convert]::ToBase64String($keytabrawdata)
        # Grant permission to DSA account on SQLMI OU
    }
    catch {

    }

    Start-Sleep -Seconds 10

    Write-Host "Deploying Azure Arc AD connecter"
    Write-Host "`n"
    $adConnectorParams = "C:\VHD\adConnector.parameters.json"
    $adConnectorName = $using:dataController + "/adarc"
    $serviceAccountProvisioning = "manual"
        (Get-Content -Path $adConnectorParams) -replace 'connectorName-stage', $adConnectorName | Set-Content -Path $adConnectorParams
        (Get-Content -Path $adConnectorParams) -replace 'domainController-stage', $dcInfo.HostName | Set-Content -Path $adConnectorParams
        (Get-Content -Path $adConnectorParams) -replace 'netbiosDomainName-stage', $domain_netbios_name | Set-Content -Path $adConnectorParams
        (Get-Content -Path $adConnectorParams) -replace 'realm-stage', $dcInfo.domain.ToUpper() | Set-Content -Path $adConnectorParams
        (Get-Content -Path $adConnectorParams) -replace 'serviceAccountProvisioning-stage', $serviceAccountProvisioning | Set-Content -Path $adConnectorParams
        (Get-Content -Path $adConnectorParams) -replace 'domainName-stage', $dcInfo.domain.Tolower() | Set-Content -Path $adConnectorParams

    az deployment group create --resource-group $using:rg --name $sqlmiName --template-file "C:\VHD\adConnector.json" --parameters "C:\VHD\adConnector.parameters.json"
    Write-Host "`n"
    Do {
        Write-Host "Waiting for AD connector deployment. Hold tight, this might take a few minutes...(30s sleeping loop)"
        Write-Host "`n"
        kubectl get pods -n arc
        Write-Host "`n"
        Start-Sleep -Seconds 30
        $adcStatus = $(if (kubectl get adc adarc -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($adcStatus -eq "Nope")

    Write-Host "`n"
    Write-Host "Azure Arc AD connector ready!"
    Write-Host "`n"

    # Deploying the Azure Arc-enabled SQL Managed Instance
    Write-Host "Deploying the Azure Arc-enabled SQL Managed Instance"
    Write-Host "`n"

    $dataControllerId = $(az resource show --resource-group $using:rg --name $using:dataController --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
    $customLocationId = $(az customlocation show --name $using:customLocation --resource-group $using:rg --query id -o tsv)

    ################################################
    # Localize ARM template
    ################################################
    $ServiceType = "LoadBalancer"
    $readableSecondaries = $ServiceType

    # Resource Requests
    $vCoresRequest = "2"
    $memoryRequest = "4Gi"
    $vCoresLimit = "4"
    $memoryLimit = "8Gi"

    # Storage
    $StorageClassName = "default"
    $dataStorageSize = "10Gi"
    $logsStorageSize = "10Gi"
    $dataLogsStorageSize = "10Gi"

    # High Availability
    $replicas = 3 # Deploy SQL MI "Business Critical" tier
    #######################################################



    Copy-Item "C:\VHD\sqlmiAD.parameters.json" -Destination "C:\VHD\sqlmiAD.parameters.json"
    $SQLParams = "C:\VHD\sqlmiAD.parameters.json"

(Get-Content -Path $SQLParams) -replace 'resourceGroup-stage', $using:rg | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataControllerId-stage', $dataControllerId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'subscriptionId-stage', $using:subId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'azdataUsername-stage', $using:adminUsername | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'azdataPassword-stage', $using:adminPassword | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'serviceType-stage', $ServiceType | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'readableSecondaries-stage', $readableSecondaries | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'vCoresRequest-stage', $vCoresRequest | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'memoryRequest-stage', $memoryRequest | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'vCoresLimit-stage', $vCoresLimit | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'memoryLimit-stage', $memoryLimit | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'logsStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataLogStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataSize-stage', $dataStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'logsSize-stage', $logsStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataLogSize-stage', $dataLogsStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'replicasStage' , $replicas | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'sqlInstanceName-stage' , $using:sqlMI | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'keyTab-stage' , $b64keytabtext | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'adAccountName-stage' , $arcsaname | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'adConnectorName-stage' , "adarc" | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dnsName-stage' , $sqlmi_fqdn_name | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dnsNameSecondary-stage' , $sqlmi_secondary_fqdn_name | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'port-stage' , $sqlmi_port | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'licenseType-stage' , "LicenseIncluded" | Set-Content -Path $SQLParams

    az deployment group create --resource-group $using:rg --name $using:sqlMI --template-file "C:\VHD\sqlmiAD.json" --parameters "C:\VHD\sqlmiAD.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Write-Host "`n"
        kubectl get pods -n arc
        Write-Host "`n"
        Start-Sleep -Seconds 65
        $dcStatus = $(if (kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc SQL Managed Instance is ready!"
    Write-Host "`n"

    # Create windows account in SQLMI to support AD authentication and grant sysadmin role
    $podname = "${sqlMIName}-0"
    kubectl exec $podname -c arc-sqlmi -n arc -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $using:adminUsername -P "$using:adminPassword" -Q "CREATE LOGIN [${domain_netbios_name}\$env:adminUsername] FROM WINDOWS"
    Write-Host "Created Windows user account ${domain_netbios_name}\$using:adminUsername in SQLMI instance."

    kubectl exec $podname -c arc-sqlmi -n arc -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $using:adminUsername -P "$using:adminPassword" -Q "EXEC master..sp_addsrvrolemember @loginame = N'${domain_netbios_name}\$env:adminUsername', @rolename = N'sysadmin'"
    Write-Host "Granted sysadmin role to user account ${domain_netbios_name}\$using:adminUsername in SQLMI instance."

    # Downloading demo database and restoring onto SQL MI
    Write-Host "`n"
    Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
    Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $using:adminPassword -P "$using:adminPassword" -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
    Write-Host "Restoring AdventureWorks database completed."
}

# Install Azure Data Studio
Invoke-Command -ComputerName admincenter -Credential $adcred -ScriptBlock {

    Write-Host "Installing Azure Data Studio"
    Expand-Archive "C:\VHD\azuredatastudio.zip" -DestinationPath 'C:\Program Files\Azure Data Studio'
    Start-Process msiexec.exe -Wait -ArgumentList "/I C:\VHD\AZDataCLI.msi /quiet"
    Write-Host "Installing Azure Data Studio extensions"
    $Env:argument1 = "--install-extension"
    $Env:argument2 = "microsoft.azcli"
    $Env:argument3 = "Microsoft.arc"

    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument2
    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument3

    # Create Azure Data Studio desktop shortcut
    Write-Host "Creating Azure Data Studio Desktop Shortcut"
    $TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
    $ShortcutFile = "C:\Users\$using:adminUsername\Desktop\Azure Data Studio.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()

    
}

Write-Header "Configure ADS"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Write-Host "Generating endpoints file"
    Write-host "`n"

    # Retrieving SQL MI connection endpoint
    $sqlMIName = $using:sqlMI
    $dcInfo = Get-ADDomainController -discover -domain $using:domainName
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    $sqlmiEndPoint = kubectl get SqlManagedInstance $sqlMIName -n arc -o=jsonpath='{.status.endpoints.primary}'
    $sqlmiSecondaryEndPoint = kubectl get SqlManagedInstance $sqlMIName -n arc -o=jsonpath='{.status.endpoints.secondary}'
    Write-host "`n"

    # Get public ip of the SQLMI endpoint
    $sqlmiIpaddress = kubectl get svc -n arc "$sqlMIName-external-svc"  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name $sqlMIName -AllowUpdateAny -IPv4Address $sqlmiIpaddress -TimeToLive 01:00:00 -AgeRecord

    # Get public ip of the secondary SQLMI endpoint
    $sqlmiSecondaryIpaddress = kubectl get svc -n arc "$sqlMIName-secondary-external-svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name "$sqlMIName-secondary" -AllowUpdateAny -IPv4Address $sqlmiSecondaryIpaddress -TimeToLive 01:00:00 -AgeRecord

    # Write endpoint information in the file

    Start-Sleep -Seconds 5
    $filename = "SQLMIEndpoints.txt"
    $Endpoints = "c:\vhd\$filename.txt"

    Add-Content $Endpoints "======================================================================"
    Add-Content $Endpoints ""
    Add-Content $Endpoints "$sqlMIName external endpoint DNS name for AD Authentication:"
    $sqlmiEndPoint | Add-Content $Endpoints

    Add-Content $Endpoints ""
    Add-Content $Endpoints "$sqlMIName secondary external endpoint DNS name for AD Authentication:"
    $sqlmiSecondaryEndPoint | Add-Content $Endpoints

    Add-Content $Endpoints ""
    Add-Content $Endpoints "SQL Managed Instance SQL login username:"
    $using:adminUsername | Add-Content $Endpoints

    Add-Content $Endpoints ""
    Add-Content $Endpoints "SQL Managed Instance SQL login password:"
    $using:adminPassword | Add-Content $Endpoints
    Add-Content $Endpoints ""

    Add-Content $Endpoints "======================================================================"
    Add-Content $Endpoints ""

    Copy-Item "c:\VHD\$filename.txt" -Destination "\\admincenter\c$\users\$using:adminUsername\desktop\endpoints.txt" -Force

    write-host "Configuring ADS"

    $settingsTemplate = "c:\VHD\settingsTemplate.json"
    $ADSConnections = @"
{
 "options": {
      "connectionName": "SQLMI",
      "server": "$sqlmiEndPoint",
      "database": "",
      "authenticationType": "Integrated",
      "applicationName": "azdata",
      "groupId": "C777F06B-202E-4480-B475-FA416154D458",
      "databaseDisplayName": ""
    },
    "groupId": "C777F06B-202E-4480-B475-FA416154D458",
    "providerName": "MSSQL",
    "savePassword": true,
    "id": "ac333479-a04b-436b-88ab-3b314a201295"
}
"@

    $settingsTemplateJson = Get-Content $settingsTemplate | ConvertFrom-Json
    $settingsTemplateJson.'datasource.connections'[0] = ConvertFrom-Json -InputObject $ADSConnections
    ConvertTo-Json -InputObject $settingsTemplateJson -Depth 3 | Set-Content -Path $settingsTemplate

    New-Item -Path "\\admincenter\c$\users\$using:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path $settingsTemplate -Destination "\\admincenter\c$\users\$using:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

}

Write-Header "Configure Grafana and Kibana shortcuts"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    # Creating desktop url shortcuts for built-in Grafana and Kibana services
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    $GrafanaURL = kubectl get service/metricsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $GrafanaURL = "https://" + $GrafanaURL + ":3000"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut("c:\VHD\Grafana.url")
    $Favorite.TargetPath = $GrafanaURL;
    $Favorite.Save()

    $KibanaURL = kubectl get service/logsui-external-svc -n arc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $KibanaURL = "https://" + $KibanaURL + ":5601"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut("c:\VHD\Desktop\Kibana.url")
    $Favorite.TargetPath = $KibanaURL;
    $Favorite.Save()

    Copy-Item -Path "c:\VHD\Grafana.url" -Destination "\\admincenter\c$\users\$using:adminUsername\Desktop\Grafana.url"
    Copy-Item -Path "c:\VHD\Kibana.url" -Destination "\\admincenter\c$\users\$using:adminUsername\Desktop\Kibana.url"

}

# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deploySQLMI', 'true', [System.EnvironmentVariableTarget]::Machine)

Stop-Transcript