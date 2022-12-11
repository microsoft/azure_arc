param (
    [string]$saPassword
)

# Execute sql commands to generate defender for cloud alerts
Import-Module (Get-ChildItem -Path “$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\” -File SqlAdvancedThreatProtectionShell.psm1 -Recurse).FullName ; Get-Command -Module SqlAdvancedThreatProtectionShell

$encrypted = ConvertFrom-SecureString -SecureString $saPassword
$saPasswordEncrypted = ConvertTo-SecureString -String $encrypted
test-SqlAtpInjection -UserName sa -Password $saPasswordEncrypted