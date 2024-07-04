# Deployment environment variables
$Env:TempDir = "C:\Temp"
$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

Start-Transcript -Path "$Env:ArcBoxLogsDir\DeploySQLMIADAuth.log"

# Deploy AD Connector
# Prior to deploying prepare YAML file to update with Domain information
Import-Module ActiveDirectory
Import-Module DnsServer

# Get Activectory Information
$dcInfo = Get-ADDomainController

# Setup reverse DNS for AD authentication
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

$sqlInstances = @(

    [pscustomobject]@{instanceName = 'k3s-sql'; dataController = "$Env:k3sArcDataClusterName-dc"; customLocation = "$Env:k3sArcDataClusterName-cl" ; storageClassName = 'longhorn' ; licenseType = 'LicenseIncluded' ; context = 'k3s' ; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-datasvc-k3s" }

    [pscustomobject]@{instanceName = 'aks-sql'; dataController = "$Env:aksArcClusterName-dc" ; customLocation = "$Env:aksArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'aks'; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aks" }

    [pscustomobject]@{instanceName = 'aks-dr-sql'; dataController = "$Env:aksdrArcClusterName-dc" ; customLocation = "$Env:aksdrArcClusterName-cl" ; storageClassName = 'managed-premium' ; licenseType = 'DisasterRecovery' ; context = 'aks-dr'; kubeConfig = "C:\Users\$Env:adminUsername\.kube\config-aksdr" }

)
$sqlmiouName = "ArcSQLMI"
$sqlmiOUDN = "OU=" + $sqlmiouName + "," + $dcInfo.DefaultPartition
$sqlmi_port = 11433

# Create ArcSQLMI OU
try {
    $ou = Get-ADOrganizationalUnit -Identity $sqlmiOUDN
    if ($null -ne $ou -and $ou.Name.Length -gt 0) {
        Write-Host "Organization Unit $sqlmiouName already exist. Skipping this step."
    }
    else {
        Write-Host "Organization Unit $sqlmiouName does not exist. Creating new OU."
        New-ADOrganizationalUnit -Name $sqlmiouName -Path $dcInfo.DefaultPartition -ProtectedFromAccidentalDeletion $False
    }
}
catch {
    Write-Host "Organization Unit $sqlmiOu does not exist. Creating new OU."
    New-ADOrganizationalUnit -Name $sqlmiouName -Path $dcInfo.DefaultPartition -ProtectedFromAccidentalDeletion $False
}

Stop-Transcript

# Deploying Active Directory connector and Azure Arc SQL MI
Write-Header "Deploying Active Directory connector"

# Creating endpoints file
$filename = "SQLMIEndpoints.txt"
$file = New-Item -Path $Env:ArcBoxDir -Name $filename -ItemType "file"
$Endpoints = $file.FullName


$sqlInstances | Foreach-Object -ThrottleLimit 5 -Parallel {
    $ErrorActionPreference = 'SilentlyContinue'
    $WarningPreference = 'SilentlyContinue'
    $sqlInstance = $_
    $dcInfo = $using:dcInfo
    $Endpoints = $using:Endpoints
    $sqlmiOUDN = $using:sqlmiOUDN
    $sqlmi_port = $using:sqlmi_port
    $context = $sqlInstance.context

    Start-Transcript -Path "$Env:ArcBoxLogsDir\SQLMI-$context.log"

    $sqlMIName = $sqlInstance.instanceName
    $sqlmi_fqdn_name = $sqlMIName + "." + $dcInfo.domain
    $sqlmi_secondary_fqdn_name = $sqlMIName + "-secondary." + $dcInfo.domain

    # Create dedicated service account for AD connector
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
    try {
        setspn -A MSSQLSvc/${sqlmi_fqdn_name} ${domain_netbios_name}\${samaccountname}
        setspn -A MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port} ${domain_netbios_name}\${samaccountname}

        # Secondary instance spn
        setspn -A MSSQLSvc/${sqlmi_secondary_fqdn_name} ${domain_netbios_name}\${samaccountname}
        setspn -A MSSQLSvc/${sqlmi_secondary_fqdn_name}:${sqlmi_port} ${domain_netbios_name}\${samaccountname}

        $keytab_file = "$Env:ArcBoxDir\$sqlMIName.keytab"
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
    catch{

    }


    Start-Sleep -Seconds 10

    Copy-Item "$Env:ArcBoxDir\adConnector.parameters.json" -Destination "$Env:ArcBoxDir\adConnector-$context-stage.parameters.json"
    $adConnectorParams = "$Env:ArcBoxDir\adConnector-$context-stage.parameters.json"
    $adConnectorName = $sqlInstance.dataController + "/adarc"
    $serviceAccountProvisioning = "manual"
    (Get-Content -Path $adConnectorParams) -replace 'connectorName-stage', $adConnectorName | Set-Content -Path $adConnectorParams
    (Get-Content -Path $adConnectorParams) -replace 'domainController-stage', $dcInfo.HostName | Set-Content -Path $adConnectorParams
    (Get-Content -Path $adConnectorParams) -replace 'netbiosDomainName-stage', $domain_netbios_name | Set-Content -Path $adConnectorParams
    (Get-Content -Path $adConnectorParams) -replace 'realm-stage', $dcInfo.domain.ToUpper() | Set-Content -Path $adConnectorParams
    (Get-Content -Path $adConnectorParams) -replace 'serviceAccountProvisioning-stage', $serviceAccountProvisioning | Set-Content -Path $adConnectorParams
    (Get-Content -Path $adConnectorParams) -replace 'domainName-stage', $dcInfo.domain.Tolower() | Set-Content -Path $adConnectorParams

    Write-Host "Deploying Azure Arc AD connector for $sqlMIName"
    az deployment group create --resource-group $Env:resourceGroup --name $sqlInstance.instanceName --template-file "$Env:ArcBoxDir\adConnector.json" --parameters "$Env:ArcBoxDir\adConnector-$context-stage.parameters.json"
    Write-Host "`n"
    Do {
        Write-Host "Waiting for AD connector deployment for $sqlMIName. Hold tight, this might take a few minutes...(30s sleeping loop)"
        Start-Sleep -Seconds 30
        $adcStatus = $(if (kubectl get adc adarc -n arc --kubeconfig $sqlInstance.kubeConfig | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($adcStatus -eq "Nope")

    Write-Host "`n"
    Write-Host "Azure Arc AD connector ready!"
    Write-Host "`n"

    Remove-Item "$Env:ArcBoxDir\adConnector-$context-stage.parameters.json" -Force

    # Deploying Azure Arc SQL Managed Instance

    Write-Host "Deploying the $sqlMIName Azure Arc SQL Managed Instance"
    $dataControllerId = $(az resource show --resource-group $Env:resourceGroup --name $sqlInstance.dataController --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
    $customLocationId = $(az customlocation show --name $sqlInstance.customLocation --resource-group $Env:resourceGroup --query id -o tsv)

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
    $StorageClassName = $sqlInstance.storageClassName
    $dataStorageSize = "30Gi"
    $logsStorageSize = "30Gi"
    $dataLogsStorageSize = "30Gi"

    # High Availability
    $replicas = 3 # Deploy SQL MI "Business Critical" tier
    #######################################################



    Copy-Item "$Env:ArcBoxDir\sqlmiAD.parameters.json" -Destination "$Env:ArcBoxDir\sqlmiAD-$context-stage.parameters.json"
    $SQLParams = "$Env:ArcBoxDir\sqlmiAD-$context-stage.parameters.json"

    (Get-Content -Path $SQLParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataControllerId-stage', $dataControllerId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'azdataUsername-stage', $env:AZDATA_USERNAME | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'azdataPassword-stage', $env:AZDATA_PASSWORD | Set-Content -Path $SQLParams
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
    (Get-Content -Path $SQLParams) -replace 'sqlInstanceName-stage' , $sqlInstance.instanceName | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'keyTab-stage' , $b64keytabtext | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'adAccountName-stage' , $arcsaname | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'adConnectorName-stage' , "adarc" | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dnsName-stage' , $sqlmi_fqdn_name | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dnsNameSecondary-stage' , $sqlmi_secondary_fqdn_name | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'port-stage' , $sqlmi_port | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'licenseType-stage' , $sqlInstance.licenseType | Set-Content -Path $SQLParams

    az deployment group create --resource-group $Env:resourceGroup --name $sqlInstance.instanceName --template-file "$Env:ArcBoxDir\sqlmiAD.json" --parameters "$Env:ArcBoxDir\sqlmiAD-$context-stage.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get sqlmanagedinstances -n arc --kubeconfig $sqlInstance.kubeConfig | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "$sqlMIName Azure Arc SQL Managed Instance is ready!"
    Write-Host "`n"

    Remove-Item "$Env:ArcBoxDir\sqlmiAD-$context-stage.parameters.json" -Force

    # Create windows account in SQLMI to support AD authentication and grant sysadmin role
    $podname = "${sqlMIName}-0"
    kubectl exec $podname -c arc-sqlmi -n arc --kubeconfig $sqlInstance.kubeConfig -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P "$env:AZDATA_PASSWORD" -Q "CREATE LOGIN [${domain_netbios_name}\$env:adminUsername] FROM WINDOWS"
    Write-Host "Created Windows user account ${domain_netbios_name}\$env:AZDATA_USERNAME in SQLMI instance."

    kubectl exec $podname -c arc-sqlmi -n arc --kubeconfig $sqlInstance.kubeConfig -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P "$env:AZDATA_PASSWORD" -Q "EXEC master..sp_addsrvrolemember @loginame = N'${domain_netbios_name}\$env:adminUsername', @rolename = N'sysadmin'"
    Write-Host "Granted sysadmin role to user account ${domain_netbios_name}\$env:AZDATA_USERNAME in SQLMI instance."

    # Downloading demo database and restoring onto SQL MI
    if ($sqlMIName -eq "k3s-sql") {
        Write-Host "`n"
        Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
        kubectl exec $podname -n arc --kubeconfig $sqlInstance.kubeConfig -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
        Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
        kubectl exec $podname -n arc --kubeconfig $sqlInstance.kubeConfig -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $Env:AZDATA_USERNAME -P "$Env:AZDATA_PASSWORD" -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2019' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2019_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
        Write-Host "Restoring AdventureWorks database completed."
    }

    Stop-Transcript
}

Start-Transcript -Path "$Env:ArcBoxLogsDir\DeploySQLMIADAuth.log" -Append

Write-Header "Generating endpoints file"
Write-Host "`n"

foreach ($sqlInstance in $sqlInstances){

# Retrieving SQL MI connection endpoint
Write-Host "Retrieving SQL MI connection endpoint"
$sqlMIName = $sqlInstance.instanceName
$sqlmiEndPoint = kubectl get SqlManagedInstance $sqlMIName -n arc --kubeconfig $sqlInstance.kubeConfig -o=jsonpath='{.status.endpoints.primary}'
$sqlmiSecondaryEndPoint = kubectl get SqlManagedInstance $sqlMIName -n arc --kubeconfig $sqlInstance.kubeConfig -o=jsonpath='{.status.endpoints.secondary}'
write-host "`n"

# Get public ip of the SQLMI endpoint
Write-Host "Getting public Ip address of the primary SQLMI endpoint of $sqlMIName"
write-host "`n"
$sqlmiIpaddress = kubectl get svc -n arc --kubeconfig $sqlInstance.kubeConfig "$sqlMIName-external-svc"  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name $sqlMIName -AllowUpdateAny -IPv4Address $sqlmiIpaddress -TimeToLive 01:00:00 -AgeRecord

# Get public ip of the secondary SQLMI endpoint
Write-Host "Getting public Ip address of the secondary SQLMI endpoint of $sqlMIName"
write-host "`n"
$sqlmiSecondaryIpaddress = kubectl get svc -n arc --kubeconfig $sqlInstance.kubeConfig  "$sqlMIName-secondary-external-svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name "$sqlMIName-secondary" -AllowUpdateAny -IPv4Address $sqlmiSecondaryIpaddress -TimeToLive 01:00:00 -AgeRecord

# Write endpoint information in the file

Write-Host "Write endpoint information in the endpoints file"
write-host "`n"
$SQLInstanceName = $sqlInstance.context.toupper()

Start-Sleep -Seconds 5

Add-Content $Endpoints "======================================================================"
Add-Content $Endpoints ""
Add-Content $Endpoints "$SQLInstanceName external endpoint DNS name for AD Authentication:"
$sqlmiEndPoint | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "$SQLInstanceName secondary external endpoint DNS name for AD Authentication:"
$sqlmiSecondaryEndPoint | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance SQL login username:"
$env:AZDATA_USERNAME | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance SQL login password:"
$env:AZDATA_PASSWORD | Add-Content $Endpoints
Add-Content $Endpoints ""

Add-Content $Endpoints "======================================================================"
Add-Content $Endpoints ""

}

# Creating distributed DAG
Write-Header "Configuring Disaster Recovery"
Write-Host "Configuring the primary cluster DAG"
New-Item -Path "$Env:ArcBoxDir/sqlcerts" -ItemType Directory
Write-Host "`n"
kubectx $sqlInstances[0].context
az sql mi-arc get-mirroring-cert --name $sqlInstances[0].instanceName --cert-file "$Env:ArcBoxDir/sqlcerts/sqlprimary.pem" --k8s-namespace arc --use-k8s
Write-Host "`n"

Write-Host "Configuring the secondary cluster DAG"
Write-Host "`n"
kubectx $sqlInstances[2].context
az sql mi-arc get-mirroring-cert --name $sqlInstances[2].instanceName --cert-file "$Env:ArcBoxDir/sqlcerts/sqlsecondary.pem" --k8s-namespace arc --use-k8s
Write-Host "`n"

Write-Host "`n"
kubectx $sqlInstances[0].context
az sql instance-failover-group-arc create --shared-name ArcBoxDag --name primarycr --mi $sqlInstances[0].instanceName --role primary --partner-mi $sqlInstances[2].instanceName --resource-group $env:resourceGroup --partner-resource-group $env:resourceGroup
Write-Host "`n"

$cnameRecord = $sqlInstances[0].instanceName + ".jumpstart.local"
Add-DnsServerResourceRecordCName -Name "ArcBoxDag" -ComputerName $dcInfo.HostName -HostNameAlias $cnameRecord -ZoneName jumpstart.local -TimeToLive 00:05:00


Write-Header "Creating Azure Data Studio settings for SQL Managed Instance connection with AD Authentication"

$settingsTemplateFile = "$Env:ArcBoxDir\settingsTemplate.json"

$aks = $sqlInstances[1].instanceName + ".jumpstart.local" + ",$sqlmi_port"
$arcboxDag = "ArcBoxDag.jumpstart.local" + ",$sqlmi_port"
$sa_username = $env:AZDATA_USERNAME
$sa_password = $env:AZDATA_PASSWORD

$dagConnection = @"
{
 "options": {
      "connectionName": "ArcBoxDAG",
      "server": "$arcboxDag",
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


$aksConnection = @"
{
    "options": {
        "connectionName": "ArcBox-AKS",
        "server": "$aks",
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

$sqlServerConnection = @"
{
    "options": {
        "connectionName": "SQL Server",
        "server": "10.10.1.100",
        "database": "",
        "authenticationType": "SqlLogin",
        "user": "sa",
        "password": "ArcDemo123!!",
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




$settingsTemplateJson = Get-Content $settingsTemplateFile | ConvertFrom-Json
$settingsTemplateJson.'datasource.connections'[0] = ConvertFrom-Json -InputObject $dagConnection
$settingsTemplateJson.'datasource.connections'[1] = ConvertFrom-Json -InputObject $aksConnection
$settingsTemplateJson.'datasource.connections' += ConvertFrom-Json -InputObject $sqlServerConnection
ConvertTo-Json -InputObject $settingsTemplateJson -Depth 3 | Set-Content -Path $settingsTemplateFile

Write-Host "`n"
Write-Host "Copying Azure Data Studio settings template file"
New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "$Env:ArcBoxDir\settingsTemplate.json" -Destination "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"

Write-Host "`n"
Write-Header "Creating SQLMI Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\SQLMI Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()


# Unzip SqlQueryStress
Expand-Archive -Path $Env:ArcBoxDir\SqlQueryStress.zip -DestinationPath $Env:ArcBoxDir\SqlQueryStress

# Create SQLQueryStress desktop shortcut
Write-Host "`n"
Write-Host "Creating SQLQueryStress Desktop shortcut"
Write-Host "`n"
$TargetFile = "$Env:ArcBoxDir\SqlQueryStress\SqlQueryStress.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\SqlQueryStress.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Stop transcript
Stop-Transcript
