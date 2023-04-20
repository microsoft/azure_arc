<#
.Description
Copyright (c) Microsoft Corporation. All rights reserved.

This script creates a keytab file and a Kubernetes Secret spec holding the keytab content.

Requirements:
1. ktpass.exe should be installed on the Windows machine running this script.  
   This utility is pre-installed on Windows Server OS. ktpass is not installed on Windows client computers normally.  Use Windows Server.

2. ktpass.exe requires connectivity to the AD domain.

3. Create a Secure-String object and pass it to the -CurrentPassword and -NewPassword parameters.  Example: $currentsqlmipassword = Read-Host -AsSecureString

Example Usage:
$currentsqlmipassword = Read-Host -AsSecureString
$newsqlmipassword = Read-Host -AsSecureString
.\rotate-sql-keytab.ps1 -SqlMiName arc-sqlmi -CurrentPassword $currentsqlmipassword -NewPassword $newsqlmipassword -SecretName sqlmi-update-keytab-secret -Namespace sqlmi-ns

Required Parameters:

SqlMiName          : Deployed SQL MI name to rotate keytab.
CurrentPassword    : Current password for the Active Directory account name pre-created for the SQL MI instance.
NewPassword        : New password for the Active Directory account name pre-created for the SQL MI instance.
SecretName         : Keytab secret name to generate.
Namespace          : SQL MI namespace.
KeytabFile         : Keytab file name to generate.
#>

param(
    [Parameter(Mandatory)]$SqlMiName,
    [Parameter(Mandatory)][SecureString]$CurrentPassword,
    [Parameter(Mandatory)][SecureString]$NewPassword,
    [Parameter(Mandatory)]$SecretName,
    [Parameter(Mandatory)]$Namespace,
    [Parameter(Mandatory)]$KeytabFile
)

function CreateKeytab
{
  param (
    [Parameter(Mandatory)]$Kvno, # Kvno number to be used when creating the keytab file
    [Parameter(Mandatory)]$AppendToExistingKeytab, # Flag to indicate whether we need to append the entries to an existing file given by the global $KeytabFile param
    [Parameter(Mandatory)]$Password # The password associated with the $Account
  )

  if (!$AppendToExistingKeytab)
  {
    Write-Host "Creating new keytab"
    ktpass /princ $Account@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /out $KeytabFile -setpass /pass $Password
  }
  else
  {
    Write-Host "Appending existing keytab"
    ktpass /princ $Account@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass /pass $Password
  }

  ktpass /princ $Account@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

  ktpass /princ MSSQLSvc/$PrimaryDnsName@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
  ktpass /princ MSSQLSvc/$PrimaryDnsName@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

  ktpass /princ MSSQLSvc/${PrimaryDnsName}:$PrimaryPort@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
  ktpass /princ MSSQLSvc/${PrimaryDnsName}:$PrimaryPort@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

  if (![string]::IsNullOrEmpty($SecondaryDnsName))
  {
    ktpass /princ MSSQLSvc/$SecondaryDnsName@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
    ktpass /princ MSSQLSvc/$SecondaryDnsName@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password

    if (![string]::IsNullOrEmpty($SecondaryPort))
    {
      ktpass /princ MSSQLSvc/${SecondaryDnsName}:$SecondaryPort@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto aes256-sha1 /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
      ktpass /princ MSSQLSvc/${SecondaryDnsName}:$SecondaryPort@$Realm /ptype KRB5_NT_PRINCIPAL /kvno $Kvno /crypto rc4-hmac-nt /mapuser $NetbiosDomainName\$Account /in $KeytabFile /out $KeytabFile -setpass -setupn /pass $Password
    }
  }
}

$CurrentRegularPasswordIntPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CurrentPassword)
$CurrentRegularPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($CurrentRegularPasswordIntPtr)

$NewRegularPasswordIntPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
$NewRegularPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($NewRegularPasswordIntPtr)

# Get required keytab details from sqlmi spec i.e. Realm, Account, PrimaryDnsName, PrimaryPort, SecondaryDnsName, SecondaryPort
#
$PrimaryDnsName = kubectl get sqlmi $SqlMiName -n $Namespace -o 'jsonpath={.spec.services.primary.dnsName}'
$HostName, $Realm = $PrimaryDnsName.Split(".", 2)[0, -1] # DnsName is Hostname.Realm
$Realm = $Realm.ToUpper()
$NetbiosDomainName = $Realm.Split(".", 2)[0] #NetbiosDomainName is the first part of the Realm name.
$Account = kubectl get sqlmi $SqlMiName -n $Namespace -o 'jsonpath={.spec.security.activeDirectory.accountName}'
$PrimaryPort = kubectl get sqlmi $SqlMiName -n $Namespace -o 'jsonpath={.spec.services.primary.port}'
$SecondaryDnsName = kubectl get sqlmi $SqlMiName -n $Namespace -o 'jsonpath={.spec.services.readableSecondaries.dnsName}'
$SecondaryPort = kubectl get sqlmi $SqlMiName -n $Namespace -o 'jsonpath={.spec.services.readableSecondaries.port}'

Write-Host ""
Write-Host "Arguments:"
Write-Host "  SqlMiName           = $SqlMiName"
Write-Host "  SecretName          = $SecretName"
Write-Host "  Namespace           = $Namespace"
Write-Host "  KeytabFile          = $KeytabFile"
Write-Host "Derived Values from spec:"
Write-Host "  Realm               = $Realm"
Write-Host "  NetbiosDomainName   = $NetbiosDomainName"
Write-Host "  Account             = $Account"
Write-Host "  PrimaryDnsName      = $PrimaryDnsName"
Write-Host "  PrimaryPort         = $PrimaryPort"

if (![string]::IsNullOrEmpty($SecondaryDnsName))
{
  Write-Host "  SecondaryDnsName    = $SecondaryDnsName"
}

if (![string]::IsNullOrEmpty($SecondaryPort))
{
  Write-Host "  SecondaryPort       = $SecondaryPort"
}
Write-Host ""

# Get kvno from AD Domain
#
$SqlMiPod = $SqlMiName + "-0"
kubectl exec $SqlMiPod -c arc-sqlmi -n $Namespace -- bash -c echo "'$CurrentRegularPassword' | kinit $Account@$Realm"
$Output= kubectl exec $SqlMiPod -c arc-sqlmi -n $Namespace -- kvno $Account@$Realm

# Example output of kvno user@realm : 'user@realm: kvno = 5' Thus we need to extract the last integer from this string.
# In order to do so, we need to split the string by the '=' delimeter, get the last element of the resulting array and trim it.
#
$Kvno=($Output -split '=')[-1]
$Kvno=$Kvno.Trim()

# Increment Kvno by 1
#
$NewKvno = [System.Int32]::Parse($Kvno)
$NewKvno++

# Generate keytab using ktpass.exe and current kvno.
#
CreateKeytab -Kvno $Kvno -AppendToExistingKeytab $False -Password $CurrentRegularPassword

# Add keytab entries for new kvno using ktpass.exe.
#
CreateKeytab -Kvno $NewKvno -AppendToExistingKeytab $True -Password $NewRegularPassword

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
  namespace: $Namespace
data:
  keytab:
    $keytabContentEncoded"

Write-Host ""
Write-Host "Generated Kubernetes Secret Template: "
Write-Host $secretContent

$SecretFile = $SecretName + ".yaml"

$secretContent | Out-File -FilePath $SecretFile
Write-Host ""
Write-Host "Wrote Kubernetes Secret Template to file '$SecretFile'."

# Apply secret to the given namespace
#
kubectl apply -f $SecretFile -n $Namespace

# Edit SQL MI spec to point to the new secret
#
kubectl patch sqlmi $SqlMiName -n $Namespace --type='json' -p="[{"op": "replace", "path": "/spec/security/activeDirectory/keytabSecret", "value": ""$SecretName""}]"

# Wait until SQL MI is in Ready state
$RetryPause = 15
Start-Sleep -Seconds $RetryPause
$SqlMiState = kubectl get sqlmi $SqlMiName -o jsonpath='{.status.state}' -n $Namespace
$Tries = 0
while($SqlMiState -ne "Ready" -and $Tries -lt 40)
{
  Write-Host "'$SqlMiName' has state '$SqlMiState' which is not Ready. Retrying in $RetryPause seconds..."
  Start-Sleep -Seconds 15
  $SqlMiState = kubectl get sqlmi $SqlMiName -o jsonpath='{.status.state}' -n $Namespace
  $Tries++
}

# If we have exhausted retry attempts while waiting for SQL MI to be in ready state, print command used to check the state before exiting
#
if ($SqlMiState -ne "Ready")
{
  Write-Host "Exhausted retry attempts while waiting for SQL MI '$SqlMiName' to get to Ready state"
  Write-Host "Please check SQL MI state by running the following command:"
  Write-Host "kubectl get sqlmi $SqlMiName -o jsonpath='{.status.state}' -n $Namespace"
}
else
{
  # Exec into the SQL MI pod and kinit with the current credentials to ensure it still works
  kubectl exec $SqlMiPod -c arc-sqlmi -n $Namespace -- bash -c echo "'$CurrentRegularPassword' | kinit $Account@$Realm"
  if($?)
  {
    Write-Host "AD keytab successfully rotated for SQL MI '$SqlMiName'"
  }
  else
  {
    Write-Host "Rotation failed for AD keytab for SQL MI '$SqlMiName'"
    Write-Host "Could not kinit using the current credentials for '$Account@$Realm'"
    Write-Host "Please check the troubleshooting guide to troubleshoot the error"
  }
}
