# Execute sql commands to generate defender for cloud alerts
Write-Information "Executing Defender for SQL threat simulation script."
$attempts = 0

while ($attempts -le 3)
{
    $moduleFile = (Get-ChildItem -Path "$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\" -File SqlAdvancedThreatProtectionShell.psm1 -Recurse).FullName
    $attempts = $attempts + 1
    if ($true -eq [System.IO.File]::Exists($moduleFile))
    {
        Write-Error "Foud module file $moduleFile installed."
        break
    }
    else 
    {
        Write-Information "Module file $moduleFile not installed. Waiting for the module to be installed. Attempt: $attempts"
        Start-Sleep(20) # Wait for agent to isntall all modules
    }
}

if ($true -ne [System.IO.File]::Exists($moduleFile))
{
    Write-Error "Module file $moduleFile not installed. Try running script mannually later."
    Exit
}

# Verify if modules are installed. If not wait until it is available
Import-Module $moduleFile
Get-Command -Module SqlAdvancedThreatProtectionShell

Write-Information "Executing SQL injection"
$saPasswordEncrypted = ConvertTo-SecureString -String "ArcDemo123!!" -AsPlainText -Force
Test-SqlAtpInjection -UserName sa -Password $saPasswordEncrypted # High risk
Start-Sleep(30) # Wait between tests

# Run brute  force test to generate alerts
Write-Information "Executing brute force attack"
Test-SqlAtpBruteForce # High risk
Start-Sleep(30) # Wait between tests

# Run shell obfuscation test
Write-Information "Executing SQL shell obfuscation"
Test-SqlATpShellObfuscation -UserName sa -Password $saPasswordEncrypted # Medium risk
