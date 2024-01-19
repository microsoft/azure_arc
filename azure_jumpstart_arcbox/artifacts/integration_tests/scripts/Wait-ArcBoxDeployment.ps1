param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

Write-Host "Starting VM Run Command to wait for deployment and retrieve Pester test results from ArcBox-Client in resource group $ResourceGroupName"

$Location = (Get-AzVM -ResourceGroupName $ResourceGroupName).Location
Set-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName ArcBox-Client -RunCommandName RetrievePesterResults -Location $Location -SourceScriptUri "https://gist.githubusercontent.com/janegilring/0df14b6b45cde9ebc3060aad995ce173/raw/337a867488b532ccfaece62b5c805d3a31d44c2b/Send-PesterResult.ps1" -AsyncExecution

do {
    $job = Get-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName ArcBox-Client -RunCommandName RetrievePesterResults -Expand InstanceView

    Write-Host "Instance view of job:" -ForegroundColor Green
    $job.InstanceView
    Start-Sleep -Seconds 60

} while ($job.InstanceView.ExecutionState -eq "Running")

Write-Host "Job completed" -ForegroundColor Green
$job