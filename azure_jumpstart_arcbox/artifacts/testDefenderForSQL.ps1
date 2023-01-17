# Execute sql commands to generate defender for cloud alerts
do
{
    Start-Sleep(20) # Wait for agent to isntall all modules
    $moduleFile = (Get-ChildItem -Path "$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\" -File SqlAdvancedThreatProtectionShell.psm1 -Recurse).FullName
}while ($true -ne [System.IO.File]::Exists($moduleFile))

# Verify if modules are installed. If not wait until it is available
Import-Module $moduleFile
Get-Command -Module SqlAdvancedThreatProtectionShell

$saPasswordEncrypted = ConvertTo-SecureString -String "ArcDemo123!!" -AsPlainText -Force
Test-SqlAtpInjection -UserName sa -Password $saPasswordEncrypted # High risk
Start-Sleep(30) # Wait between tests

# Run brute  force test to generate alerts
Test-SqlAtpBruteForce # High risk
Start-Sleep(30) # Wait between tests

# Run shell obfuscation test
Test-SqlATpShellObfuscation -UserName sa -Password $saPasswordEncrypted # Medium risk
