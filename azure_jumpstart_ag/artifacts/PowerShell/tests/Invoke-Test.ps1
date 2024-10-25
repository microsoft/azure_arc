#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.6.0"}


Invoke-Pester -Path "$AgTestsDir\common.tests.ps1" -Output Detailed -PassThru -OutVariable tests_common
$tests_passed = $tests_common.Passed.Count
$tests_failed = $tests_common.Failed.Count


Invoke-Pester -Path "$AgTestsDir\k8s.tests.ps1" -Output Detailed -PassThru -OutVariable tests_k8s
$tests_passed = $tests_passed + $tests_k8s.Passed.Count
$tests_failed = $tests_failed + $tests_k8s.Failed.Count


Write-Output "Tests succeeded: $tests_passed"
Write-Output "Tests failed: $tests_failed"

Write-Header "Adding deployment test results to wallpaper using BGInfo"

Set-Content "$Env:windir\TEMP\agora-tests-succeeded.txt" $tests_passed
Set-Content "$Env:windir\TEMP\agora-tests-failed.txt" $tests_failed

bginfo.exe $AgTestsDir\ag-bginfo.bgi /timer:0 /NOLICPROMPT