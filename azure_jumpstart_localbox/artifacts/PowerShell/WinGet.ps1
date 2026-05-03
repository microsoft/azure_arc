$ErrorActionPreference = $env:ErrorActionPreference

$Env:LocalBoxLogsDir = "$Env:LocalBoxDir\Logs"
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$resourceGroup = $env:resourceGroup

$logFilePath = Join-Path -Path $Env:LocalBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Login to Azure PowerShell
Connect-AzAccount -Identity -Tenant $Env:tenantId -Subscription $Env:subscriptionId

Update-AzDeploymentProgressTag -ProgressString 'Installing WinGet packages...' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Install WinGet PowerShell modules
# Pinned to version 1.11.460 to avoid known issue: https://github.com/microsoft/winget-cli/issues/5826
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460

# Install DSC resources required for ArcBox
Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Update WinGet package manager to the latest version (running twice due to a known issue regarding WinAppSDK)
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose

Get-WinGetVersion

Write-Output 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Apply WinGet Configuration files
& $winget configure --file "$($Env:LocalBoxDir)\DSC\packages.dsc.yml" --accept-configuration-agreements --disable-interactivity
& $winget configure --file "$($Env:LocalBoxDir)\DSC\hyper-v.dsc.yml" --accept-configuration-agreements --disable-interactivity

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false

# Temporary fix until LocalBox PowerShell module is updated
# Define the file path
$filePath = "C:\Program Files\WindowsPowerShell\Modules\Azure.Arc.Jumpstart.LocalBox\1.0.8\Azure.Arc.Jumpstart.LocalBox.psm1"

# Check if the file exists
if (Test-Path -Path $filePath) {
    Write-Host "File found: $filePath" -ForegroundColor Green

    # Read the file content
    $content = Get-Content -Path $filePath -Raw

    # Define the line to search for and the replacement
    $searchString = '$ParentDiskPath = "C:\VMs\Base\AzL-node.vhdx"'
    $replaceString = '$ParentDiskPath = "C:\VMs\Base\GUI.vhdx"'

    # Check if the search string exists in the file
    if ($content -match [regex]::Escape($searchString)) {
        Write-Host "Found the line to replace." -ForegroundColor Yellow

        # Replace the string
        $newContent = $content -replace [regex]::Escape($searchString), $replaceString

        # Write the updated content back to the file
        Set-Content -Path $filePath -Value $newContent -NoNewline

        Write-Host "Successfully replaced the line!" -ForegroundColor Green
    }
    else {
        Write-Host "The specified line was not found in the file." -ForegroundColor Red
    }
}
else {
    Write-Host "File not found: $filePath" -ForegroundColor Yellow
}

Stop-Transcript