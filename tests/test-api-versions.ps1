# Install PSRule.Rules.Azure if not already installed
if (-not (Get-Module -ListAvailable -Name PSRule.Rules.Azure)) {
    Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force
}

# Create output directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "./reports"

# Run the scan
$results = Get-ChildItem -Recurse -Filter "*.bicep" | 
    Assert-PSRule -Module PSRule.Rules.Azure -Outcome Fail -OutputFormat Detail

if ($results) {
    Write-Host "Found outdated API versions:" -ForegroundColor Yellow
    $results | Format-Table RuleName, TargetName, Message -AutoSize
} else {
    Write-Host "No outdated API versions found!" -ForegroundColor Green
}
