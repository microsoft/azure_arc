# Execute sql commands to generate defender for cloud alerts
do
{
    Start-Sleep(20) # Wait for agent to isntall all modules
    $moduleFile = (Get-ChildItem -Path “$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\” -File SqlAdvancedThreatProtectionShell.psm1 -Recurse).FullName
}while ($true = [System.IO.File]::Exists($moduleFile))

# Verify if modules are installed. If not wait until it is available
Import-Module $moduleFile
Get-Command -Module SqlAdvancedThreatProtectionShell

#$encrypted = ConvertFrom-SecureString -SecureString $saPassword -AsPlainText -Force
#$saPasswordEncrypted = ConvertTo-SecureString -String $encrypted
#test-SqlAtpInjection -UserName sa -Password $saPasswordEncrypted
# Run brute  force test to generate alerts
Test-SqlAtpBruteForce