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

    [pscustomobject]@{instanceName = 'arcboxsqlcapi'; dataController = 'arcbox-capi-dc'; customLocation = 'arcbox-capi-cl' ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'capi' }

    [pscustomobject]@{instanceName = 'arcboxsqlaks'; dataController = 'arcbox-aks-dc'; customLocation = 'arcbox-aks-cl' ; storageClassName = 'managed-premium' ; licenseType = 'LicenseIncluded' ; context = 'aks' }

    [pscustomobject]@{instanceName = 'arcboxsqldr'; dataController = 'arcbox-aksdr-dc'; customLocation = 'arcbox-aksdr-cl' ; storageClassName = 'managed-premium' ; licenseType = 'DisasterRecovery' ; context = 'aks-dr' }

)
$sqlmiouName = "ArcSQLMI"
$sqlmiOUDN = "OU=" + $sqlmiouName + "," + $dcInfo.DefaultPartition

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


# Create dedicated service account for AD connector
$arcsaname = "sa-sqlmi-cmk"
$arcsapass = "ArcDSA#Pwd123$"
$arcsasecpass = $arcsapass | ConvertTo-SecureString -AsPlainText -Force
$sqlmisaupn = $arcsaname + "@" + $dcInfo.domain

$samaccountname = $arcsaname
$domain_netbios_name = $dcInfo.domain.split('.')[0].ToUpper();
$domain_name = $dcInfo.domain.ToUpper()
$nameserverIPAddresses = @("dcInfo.IPv4Address")
#$sqlmi_port = "32400"

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

# Deploying Active Directory connector and Azure Arc SQL MI
Write-Header "Deploying Active Directory connector"

foreach ($sqlInstance in $sqlInstances) {
    kubectx $sqlInstance.context
    $sqlMIName = $sqlInstance.instanceName
    $sqlmi_fqdn_name = $sqlMIName + "." + $dcInfo.domain
    # Geneate key tab
    setspn -A MSSQLSvc/${sqlmi_fqdn_name} ${domain_netbios_name}\${samaccountname}
    setspn -A MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port} ${domain_netbios_name}\${samaccountname}
    $keytab_file = "$Env:ArcBoxDir\mssql.keytab"
    ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /out $keytab_file -setpass -setupn /pass $arcsapass
    ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
    ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
    ktpass /princ MSSQLSvc/${sqlmi_fqdn_name}:${sqlmi_port}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
    ktpass /princ ${samaccountname}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
    ktpass /princ ${samaccountname}@${domain_name} /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser ${domain_netbios_name}\${samaccountname} /in $keytab_file /out $keytab_file -setpass -setupn /pass $arcsapass
    # Convert key tab file into base64 data
    $keytabrawdata = Get-Content $keytab_file -Encoding byte
    $b64keytabtext = [System.Convert]::ToBase64String($keytabrawdata)
    # Grant permission to DSA account on SQLMI OU 
    # Convert SQL Admin credentials into base64 format
    $b64UserName = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:AZDATA_USERNAME))
    $b64Password = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:AZDATA_PASSWORD))

    Copy-Item "$Env:ArcBoxDir\adConnector.parameters.json" -Destination "$Env:ArcBoxDir\adConnector-stage.parameters.json"
    $adConnectorParams = "$Env:ArcBoxDir\adConnector-stage.parameters.json"
    $adConnectorName = $sqlInstance.dataController+"/adarc"
    $serviceAccountProvisioning = "automatic"

(Get-Content -Path $adConnectorParams) -replace 'serviceAccountPassword-stage', $arcsapass | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'serviceAccountUsername-stage', $arcsaname | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'connectorName-stage', $adConnectorName | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'domainController-stage', $dcInfo.HostName | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'netbiosDomainName-stage', $domain_netbios_name | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'ouDistinguishedName-stage', $sqlmiOUDN | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'realm-stage', $dcInfo.domain.ToUpper() | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'serviceAccountProvisioning-stage', $serviceAccountProvisioning | Set-Content -Path $adConnectorParams
(Get-Content -Path $adConnectorParams) -replace 'domainName-stage', $dcInfo.domain.Tolower() | Set-Content -Path $adConnectorParams

az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\adConnector.json" --parameters "$Env:ArcBoxDir\adConnector-stage.parameters.json"
Write-Host "`n"

    Write-Host "`n"
    Do {
        Write-Host "Waiting for AD connector deployment. Hold tight, this might take a few minutes...(30s sleeping loop)"
        Start-Sleep -Seconds 30
        $adcStatus = $(if (kubectl get adc adarc -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($adcStatus -eq "Nope")

    Write-Host "`n"
    Write-Host "Azure Arc AD connector ready!"
    Write-Host "`n"

    Remove-Item "$Env:ArcBoxDir\adConnector-stage.parameters.json" -Force
    # Deploying Azure Arc SQL Managed Instance

    Write-Header "Deploying Azure Arc SQL Managed Instance"
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
    $dataStorageSize = "5"
    $logsStorageSize = "5"
    $dataLogsStorageSize = "5"

    # High Availability
    $replicas = 3 # Deploy SQL MI "Business Critical" tier
    #######################################################

    Copy-Item "$Env:ArcBoxDir\SQLMI.parameters.json" -Destination "$Env:ArcBoxDir\SQLMI-stage.parameters.json"
    $SQLParams = "$Env:ArcBoxDir\SQLMI-stage.parameters.json"

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
(Get-Content -Path $SQLParams) -replace 'domainName-stage' , $dcInfo.domain.Tolower() | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'port-stage' , "31433" | Set-Content -Path $SQLParams

    az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\SQLMI.json" --parameters "$Env:ArcBoxDir\SQLMI-stage.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc SQL Managed Instance is ready!"
    Write-Host "`n"

    Remove-Item "$Env:ArcBoxDir\SQLMI-stage.parameters.json" -Force

    # Update Service Port from 1433 to Non-Standard
    $payload = '{\"spec\":{\"ports\":[{\"name\":\"port-mssql-tds\",\"port\":11433,\"targetPort\":1433}]}}'
    kubectl patch svc "$sqlMIName-external-svc" -n arc --type merge --patch $payload
    Start-Sleep 5 # To allow the CRD to update

    # Create windows account in SQLMI to support AD authentication and grant sysadmin role
    $podname = "${sqlMIName}-0"
    kubectl exec $podname -c arc-sqlmi -n arc -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P "$env:AZDATA_PASSWORD" -Q "CREATE LOGIN [${domain_netbios_name}\$env:adminUsername] FROM WINDOWS"
    Write-Host "Created Windows user account ${domain_netbios_name}\$env:AZDATA_USERNAME in SQLMI instance."

    kubectl exec $podname -c arc-sqlmi -n arc -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P "$env:AZDATA_PASSWORD" -Q "EXEC master..sp_addsrvrolemember @loginame = N'${domain_netbios_name}\$env:adminUsername', @rolename = N'sysadmin'"
    Write-Host "Granted sysadmin role to user account ${domain_netbios_name}\$env:AZDATA_USERNAME in SQLMI instance."

    # Downloading demo database and restoring onto SQL MI
    Write-Host "`n"
    Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
    Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $Env:AZDATA_USERNAME -P "$Env:AZDATA_PASSWORD" -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
    Write-Host "Restoring AdventureWorks database completed."

    # Retrieving SQL MI connection endpoint
    $sqlmiEndPoint = kubectl get SqlManagedInstance $sqlMIName -n arc -o=jsonpath='{.status.endpoints.primary}'

    Write-Host "SQL Managed Instance with AD authentication endpoint: $sqlmiEndPoint"
    
}
<#

# Get public ip of the SQLMI endpoint
$nodeRG = (az aks show --name $Env:clusterName -g $Env:resourceGroup --query "nodeResourceGroup")
$lbName = "kubernetes"
$lbrule = (az network lb rule list -g $nodeRG --lb-name  $lbName --query "[?contains(id, '$sqlmi_port')]") | ConvertFrom-Json
if ($null -eq $lbrule -or $lbrule.Count -le 0) {
    Write-Host "Could not find LoadBalancer for SQLMI."
    Stop-Transcript
    Exit
}

$frontendIpConfId = $lbrule.frontendIpConfiguration.id
$pubipid = (az network lb frontend-ip list --lb-name $lbName -g $nodeRG --query "[?id=='$frontendIpConfId'].{id:publicIpAddress.id}") | ConvertFrom-Json
$publicIp = (az network public-ip show --ids $pubipid.id --query "ipAddress").trim('"')
Write-Host "SQLMI public ip address $publicIp"

# Create DNS record
Add-DnsServerResourceRecord -ComputerName $dcInfo.HostName -ZoneName $dcInfo.Domain -A -Name $sqlMIName -AllowUpdateAny -IPv4Address $publicIp -TimeToLive 01:00:00 -AgeRecord
Write-Host "Creted SQLMI DNS A record with public ip address $publicIp"

# Write endpoint information in the file
$filename = "SQLMIEndpoints.txt"
$file = New-Item -Path $Env:TempDir -Name $filename -ItemType "file"
$Endpoints = $file.FullName

Add-Content $Endpoints "Primary SQL Managed Instance external endpoint DNS name for AD Authentication:"
$sqlmiEndPoint | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance username:"
$env:AZDATA_USERNAME | Add-Content $Endpoints

Add-Content $Endpoints ""
Add-Content $Endpoints "SQL Managed Instance password:"
$env:AZDATA_PASSWORD | Add-Content $Endpoints


# Create database connection in Azure Data Studio
Write-Host "`n"
Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection with AD Authentication."

$settingsTemplateFile = "$Env:TempDir\settingsTemplate.json"

$templateContent = @"
{
    "options": {
      "connectionName": "ArcSQLMI",
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

Write-Host "Creating Azure Data Studio connections settings template file $settingsTemplateJson"

$settingsTemplateJson = Get-Content $settingsTemplateFile | ConvertFrom-Json
$settingsTemplateJson.'datasource.connections' += ConvertFrom-Json -InputObject $templateContent
ConvertTo-Json -InputObject $settingsTemplateJson -Depth 3 | Set-Content -Path $settingsTemplateFile

Write-Host "Created Azure Data Studio connections settings template file."

Write-Host "`n"
Write-Host "Creating SQLMI Endpoints file Desktop shortcut"
Write-Host "`n"
$TargetFile = $Endpoints
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\SQLMI Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Creating SQL Server Management Studio desktop shortcut
Write-Host "`n"
Write-Host "Creating SQL Server Management Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio 18.lnk"

# Verify if shortcut already exists
if ([System.IO.File]::Exists($ShortcutFile)) {
    Write-Host "SQL Server Management Studio Desktop shortcut already exists."
}
else {
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
    Write-Host "Created SQL Server Management Studio Desktop shortcut"
}

# Strop transcrip
Stop-Transcript

#>