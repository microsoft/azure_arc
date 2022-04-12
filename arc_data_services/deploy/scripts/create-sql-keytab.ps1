<#
.Description
Copyright (c) Microsoft Corporation. All rights reserved.

This script creates a keytab file and a Kubernetes Secret spec holding the keytab content.

Requirements:
1. ktpass.exe should be installed on the Windows machine running this script.  
   This utility is pre-installed on Windows Server OS. ktpass is not installed on Windows client computers normally.  Use Windows Server.

2. ktpass.exe requires connectivity to the AD domain.

3. Create a Secure-String object and pass it to the --Password parameter.  Example: $sqlmipassword = Read-Host -AsSecureString

Example Usage:
.\create-sql-keytab.ps1 -Realm CONTOSO.LOCAL -NetbiosDomainName CONTOSO -Account sqlmi-account -Password <password> -DnsName sqlmi.contoso.local -Port 31433 -KeytabFile mssql.keytab -SecretName sqlmi-keytab-secret -SecretNamespace sqlmi-ns -SecretFile sqlmi-secret.yaml

Required Parameters:

Realm              : Active Directory domain name or Kerberos realm (upper case).
NetbiosDomainName  : NetBIOS name of the AD domain. Typically the first label of the realm (upper case).
Account            : Active Directory account name pre-created for the SQL MI instance.
Password           : Password for the Active Directory account name pre-created for the SQL MI instance.
DnsName            : Fully-qualified DNS name for the SQL endpoint.
Port               : External port number for the SQL endpoint.
KeytabFile         : Keytab file name to generate.
SecretName         : Keytab secret name to generate.
SecretNamespace    : Keytab secret namespace.
SecretFile         : Keytab secret file name to generate.
#>

param(
    [Parameter(Mandatory)]$Realm,
    [Parameter(Mandatory)]$NetbiosDomainName,
    [Parameter(Mandatory)]$Account,
    [Parameter(Mandatory)][SecureString] $Password,
    [Parameter(Mandatory)]$DnsName,
    [Parameter(Mandatory)]$Port,
    [Parameter(Mandatory)]$KeytabFile,
    [Parameter(Mandatory)]$SecretName,
    [Parameter(Mandatory)]$SecretNamespace,
    [Parameter(Mandatory)]$SecretFile
) 


# Generate keytab using ktpass.exe.
#
ktpass /princ $Account@$Realm /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /out $KeytabFile -setpass /pass $Password
ktpass /princ $Account@$Realm /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

ktpass /princ MSSQLSvc/$DnsName@$Realm /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
ktpass /princ MSSQLSvc/$DnsName@$Realm /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

ktpass /princ MSSQLSvc/${DnsName}:$Port@$Realm /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
ktpass /princ MSSQLSvc/${DnsName}:$Port@$Realm /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

Write-Host ""
Write-Host "Wrote Keytab to file '$KeytabFile'."

# Base64 Encode file
#
$keytabContentEncoded = [convert]::ToBase64String((Get-Content -path $KeytabFile -Encoding byte))

# Generate Kubernetes secret template.
#
$secretContent =
"apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: $SecretName
  namespace: $SecretNamespace
data:
  keytab:
    $keytabContentEncoded"

Write-Host ""
Write-Host "Generated Kubernetes Secret Template: "
Write-Host $secretContent

$secretContent | Out-File -FilePath $SecretFile
Write-Host ""
Write-Host "Wrote Kubernetes Secret Template to file '$SecretFile'."