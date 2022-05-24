$ArmFile=$args[0]
$ExcludeRules=$args[1]

git clone https://github.com/Azure/arm-ttk.git --quiet .\arm-ttk
Import-Module .\arm-ttk\arm-ttk
Install-Module Pester -AllowClobber -RequiredVersion 4.10.1 -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module Pester -RequiredVersion 4.10.1 -ErrorAction Stop
$results = Invoke-Pester -Script @{Path = ".\tests\TestArmTemplate.ps1"; Parameters = @{TemplatePath = "$ArmFile"; Skip = "$ExcludeRules"}} -OutputFormat NUnitXml -OutputFile TEST-arm_template.xml -PassThru
if ($results.TestResult.Result -contains "Failed") {Write-Error -Message "Test Failed"}