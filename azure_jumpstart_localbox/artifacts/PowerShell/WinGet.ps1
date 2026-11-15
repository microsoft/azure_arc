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
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

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


#############################################################
# Repair LocalBox module before starting deployment scripts
#############################################################

$module = Get-Module -ListAvailable Azure.Arc.Jumpstart.LocalBox |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $module) {
    throw 'Azure.Arc.Jumpstart.LocalBox is not installed.'
}

$manifestPath = $module.Path

$moduleCodePath = Join-Path `
    $module.ModuleBase `
    'Azure.Arc.Jumpstart.LocalBox.psm1'

if (-not (Test-Path -LiteralPath $moduleCodePath -PathType Leaf)) {
    throw "LocalBox module implementation was not found: $moduleCodePath"
}

$backupPath = "$moduleCodePath.before-localbox-repair"

Copy-Item `
    -LiteralPath $moduleCodePath `
    -Destination $backupPath `
    -Force

# Decode the Gallery module explicitly as UTF-8.
$bytes = [System.IO.File]::ReadAllBytes($moduleCodePath)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)

# Remove any BOM character decoded into the text. A single BOM will be
# added as encoding metadata when the repaired file is written.
$text = $text.TrimStart([char]0xFEFF)

# New-RouterVM must use the Windows Server GUI image.
$oldRouterParent =
    '$ParentDiskPath = "C:\VMs\Base\AzL-node.vhdx"'

$newRouterParent =
    '$ParentDiskPath = "C:\VMs\Base\GUI.vhdx"'

if ($text.Contains($oldRouterParent)) {
    $text = $text.Replace(
        $oldRouterParent,
        $newRouterParent
    )
}
elseif (-not $text.Contains($newRouterParent)) {
    throw 'Could not locate the New-RouterVM parent-disk setting.'
}

# Write UTF-8 with BOM so Windows PowerShell 5.1 reads Unicode correctly.
[System.IO.File]::WriteAllText(
    $moduleCodePath,
    $text,
    (New-Object System.Text.UTF8Encoding($true))
)

# Validate the repaired source before any deployment task starts.
$tokens = $null
$parseErrors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    $moduleCodePath,
    [ref]$tokens,
    [ref]$parseErrors
) | Out-Null

if ($parseErrors.Count -gt 0) {
    $parseErrors |
        Select-Object `
            Message,
            @{n='Line';e={$_.Extent.StartLineNumber}},
            @{n='Column';e={$_.Extent.StartColumnNumber}},
            @{n='Text';e={$_.Extent.Text}} |
        Format-Table -Wrap

    Copy-Item `
        -LiteralPath $backupPath `
        -Destination $moduleCodePath `
        -Force

    throw 'LocalBox module repair failed parsing; original module restored.'
}

Remove-Module Azure.Arc.Jumpstart.LocalBox `
    -Force `
    -ErrorAction SilentlyContinue

try {
    Import-Module $manifestPath -Force -ErrorAction Stop
}
catch {
    Copy-Item `
        -LiteralPath $backupPath `
        -Destination $moduleCodePath `
        -Force

    throw "LocalBox module import failed; original module restored. $($_.Exception.Message)"
}

$requiredCommands = @(
    'Test-InternetConnect'
    'New-InternalSwitch'
    'Set-HostNAT'
    'New-ManagementVM'
    'Set-MgmtVhdx'
    'New-AzLocalNodeVM'
    'New-RouterVM'
)

$availableCommands = @(
    Get-Command $requiredCommands -ErrorAction SilentlyContinue
)

$missingCommands = @(
    $requiredCommands |
        Where-Object { $_ -notin $availableCommands.Name }
)

if ($missingCommands.Count -gt 0) {
    Copy-Item `
        -LiteralPath $backupPath `
        -Destination $moduleCodePath `
        -Force

    throw "Repaired module is missing required commands: $($missingCommands -join ', ')"
}

Write-Host 'LocalBox module encoding and router image verified.' `
    -ForegroundColor Green

$availableCommands |
    Sort-Object Name |
    Format-Table Name,ModuleName,Version -AutoSize

#############################################################
# Start remaining scripts only after module verification
#############################################################

Get-ScheduledTask *LogonScript* |
    Start-ScheduledTask

# Cleanup this provisioning task.
Unregister-ScheduledTask `
    -TaskName 'WinGetLogonScript' `
    -Confirm:$false

Stop-Transcript
