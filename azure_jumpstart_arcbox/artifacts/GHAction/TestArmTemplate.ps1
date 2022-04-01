param (
    [Parameter()]
    [String]$TemplatePath,
    [string]$skipTests
)

$skip = $skipTests.split(',')
Test-AzTemplate -TemplatePath $TemplatePath -Skip $skip -Pester