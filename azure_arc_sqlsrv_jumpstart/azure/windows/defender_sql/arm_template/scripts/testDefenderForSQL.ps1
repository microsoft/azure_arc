# Execute sql commands to generate defender for cloud alerts
Write-Host "Executing Defender for SQL threat simulation script."
$attempts = 0

while ($attempts -le 5)
{
    $moduleFile = (Get-ChildItem -Path "$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\" -File SqlAdvancedThreatProtectionShell.psm1 -Recurse -ErrorAction SilentlyContinue).FullName
    $attempts = $attempts + 1
    if ($true -eq [System.IO.File]::Exists($moduleFile))
    {
        Write-Host "Found module file $moduleFile installed."
        break
    }
    else 
    {
        Write-Host "Module file $moduleFile not installed. Waiting for the module to be installed. Attempt: $attempts"
        Start-Sleep(60) # Wait for agent to isntall all modules
    }
}

if ($true -ne [System.IO.File]::Exists($moduleFile))
{
    Write-Host "Module file $moduleFile not installed. Try running script mannually later. Search for PowerShell module file 'SqlAdvancedThreatProtectionShell.psm1' in one of the '$Env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State\Resources\' sub folders to re-run this test script."
    Exit
}

# Verify if modules are installed. If not wait until it is available
Import-Module $moduleFile
Get-Command -Module SqlAdvancedThreatProtectionShell

Write-Host "Executing SQL injection"
$saPasswordEncrypted = ConvertTo-SecureString -String "ArcDemo123!!" -AsPlainText -Force
Test-SqlAtpInjection -UserName sa -Password $saPasswordEncrypted # High risk
Start-Sleep(30) # Wait between tests

# Run brute  force test to generate alerts
Write-Host "Executing brute force attack"
Test-SqlAtpBruteForce # High risk
Start-Sleep(30) # Wait between tests

# Run shell obfuscation test
Write-Host "Executing SQL shell obfuscation"
Test-SqlATpShellObfuscation -UserName sa -Password $saPasswordEncrypted # Medium risk
