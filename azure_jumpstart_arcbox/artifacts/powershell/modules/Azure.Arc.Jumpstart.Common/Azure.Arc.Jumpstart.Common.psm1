# Load functions from module subfolder
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

Resolve-Path "$ModuleRoot\Functions\Public\*.ps1" | ForEach-Object -Process {
    . $_.ProviderPath
}

<#
Resolve-Path "$ModuleRoot\Functions\Private\*.ps1" | ForEach-Object -Process {
    . $_.ProviderPath
}
#>