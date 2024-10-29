#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.6.0"}

$AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgTestsDir = $AgConfig.AgDirectories["AgTestsDir"]
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


$DeploymentStatusPath = "C:\Ag\Logs\DeploymentStatus.log"

Write-Header "Exporting deployment test results to $DeploymentStatusPath"

Write-Output "Deployment Status" | Out-File -FilePath $DeploymentStatusPath

Write-Output "`nTests succeeded: $tests_passed" | Out-File -FilePath $DeploymentStatusPath -Append
Write-Output "Tests failed: $tests_failed`n" | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "To get an updated deployment status, open Windows Terminal and run:" | Out-File -FilePath $DeploymentStatusPath -Append
Write-Output "C:\Ag\Tests\Invoke-Test.ps1`n" | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "Failed:" | Out-File -FilePath $DeploymentStatusPath -Append
$tests_common.Failed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_k8s.Failed | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "Passed:" | Out-File -FilePath $DeploymentStatusPath -Append
$tests_k8s.Passed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_common.Passed | Out-File -FilePath $DeploymentStatusPath -Append

Write-Header "Exporting deployment test results to resource group tag DeploymentStatus"

$DeploymentStatusString = "Tests succeeded: $tests_passed Tests failed: $tests_failed"

$tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

if ($null -ne $tags) {
    $tags["DeploymentStatus"] = $DeploymentStatusString
} else {
    $tags = @{"DeploymentStatus" = $DeploymentStatusString}
}

$null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags