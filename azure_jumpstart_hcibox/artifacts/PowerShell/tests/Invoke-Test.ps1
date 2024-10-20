#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.6.0"}

$Env:HCIBoxTestsDir = "$Env:HCIBoxDir\Tests"

Invoke-Pester -Path "$Env:HCIBoxTestsDir\common.tests.ps1" -Output Detailed -PassThru -OutVariable tests_common
$tests_passed = $tests_common.Passed.Count
$tests_failed = $tests_common.Failed.Count


Invoke-Pester -Path "$Env:HCIBoxTestsDir\hci.tests.ps1" -Output Detailed -PassThru -OutVariable tests_hci
$tests_passed = $tests_passed + $tests_hci.Passed.Count
$tests_failed = $tests_failed + $tests_hci.Failed.Count


Write-Output "Tests succeeded: $tests_passed"
Write-Output "Tests failed: $tests_failed"

Write-Header "Adding deployment test results to wallpaper using BGInfo"

Set-Content "$Env:windir\TEMP\hcibox-tests-succeeded.txt" $tests_passed
Set-Content "$Env:windir\TEMP\hcibox-tests-failed.txt" $tests_failed

bginfo.exe $Env:HCIBoxTestsDir\hcibox-bginfo.bgi /timer:0 /NOLICPROMPT