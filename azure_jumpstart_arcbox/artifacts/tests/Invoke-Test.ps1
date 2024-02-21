$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"

Invoke-Pester -Path "$Env:ArcBoxTestsDir\common.tests.ps1" -Output Detailed -PassThru -OutVariable tests_common
$tests_passed = $tests_common.Passed.Count
$tests_failed = $tests_common.Failed.Count

switch ($env:flavor) {
    'DevOps' {
        Invoke-Pester -Path "$Env:ArcBoxTestsDir\devops.tests.ps1" -Output Detailed -PassThru -OutVariable tests_devops
        $tests_passed = $tests_passed + $tests_devops.Passed.Count
        $tests_failed = $tests_failed +  $tests_devops.Failed.Count
}
    'DataOps' {
        Invoke-Pester -Path "$Env:ArcBoxTestsDir\dataops.tests.ps1" -Output Detailed -PassThru -OutVariable tests_dataops
        $tests_passed = $tests_passed + $tests_dataops.Passed.Count
        $tests_failed = $tests_failed +  $tests_dataops.Failed.Count
    }
    'ITPro' {
        Invoke-Pester -Path "$Env:ArcBoxTestsDir\itpro.tests.ps1" -Output Detailed -PassThru -OutVariable tests_itpro
        $tests_passed = $tests_passed + $tests_itpro.Passed.Count
        $tests_failed = $tests_failed +  $tests_itpro.Failed.Count
}
    'Full' {
        Invoke-Pester -Path "$Env:ArcBoxTestsDir\devops.tests.ps1" -Output Detailed -PassThru -OutVariable tests_devops
        $tests_passed = $tests_passed + $tests_devops.Passed.Count
        $tests_failed = $tests_failed +  $tests_devops.Failed.Count

        Invoke-Pester -Path "$Env:ArcBoxTestsDir\dataops.tests.ps1" -Output Detailed -PassThru -OutVariable tests_dataops
        $tests_passed = $tests_passed + $tests_dataops.Passed.Count
        $tests_failed = $tests_failed +  $tests_dataops.Failed.Count

        Invoke-Pester -Path "$Env:ArcBoxTestsDir\itpro.tests.ps1" -Output Detailed -PassThru -OutVariable tests_itpro
        $tests_passed = $tests_passed + $tests_itpro.Passed.Count
        $tests_failed = $tests_failed +  $tests_itpro.Failed.Count
    }
}

Write-Output "Tests succeeded: $tests_passed"
Write-Output "Tests failed: $tests_failed"

Write-Header "Adding deployment test results to wallpaper using BGInfo"

Set-Content "$Env:windir\TEMP\arcbox-tests-succeeded.txt" $tests_passed
Set-Content "$Env:windir\TEMP\arcbox-tests-failed.txt" $tests_failed

bginfo.exe $Env:ArcBoxTestsDir\arcbox-bginfo.bgi /timer:0 /NOLICPROMPT