$ExcludeRules=$args[0]
$RootFiles=$args[1]

$skip = $ExcludeRules.split(',')
$results = Invoke-ScriptAnalyzer -Recurse -ExcludeRule $skip "$RootFiles\*.ps1"
Write-Output $results
if ($results.Severity -contains "Error" -or $results.Severity -contains "Warning") {Write-Error -Message "Test Failed"}
