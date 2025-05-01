param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$githubAccount,
    [Parameter(Mandatory=$true)]
    [string]$githubBranch
)

Write-Host "Starting VM Run Command to wait for deployment and retrieve Pester test results from ArcBox-Client in resource group $ResourceGroupName"

$Location = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name ArcBox-Client).Location

# Check if a RetrievePesterResults run command is already running
$existingJob = Get-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName ArcBox-Client -RunCommandName RetrievePesterResults -ErrorAction SilentlyContinue
if ($existingJob) {
    Write-Host "A RetrievePesterResults run command is already provisioned. Skipping new execution." -ForegroundColor Yellow
} else {
    Set-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName ArcBox-Client -RunCommandName RetrievePesterResults -Location $Location -SourceScriptUri "https://raw.githubusercontent.com/$githubAccount/azure_arc/$githubBranch/azure_jumpstart_arcbox/artifacts/integration_tests/scripts/Send-PesterResult.ps1" -AsyncExecution
}

$timeoutMinutes = 180 # 3 hours timeout
$elapsedMinutes = 0

do {

    $job = Get-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName ArcBox-Client -RunCommandName RetrievePesterResults -Expand InstanceView

    Write-Host "Instance view of job:" -ForegroundColor Green
    $job.InstanceView
    Start-Sleep -Seconds 60
    $elapsedMinutes += 1

    if ($elapsedMinutes -ge $timeoutMinutes) {
        Write-Host "Timeout of 60 minutes reached. Exiting wait loop to avoid authentication token cache expiration." -ForegroundColor Yellow
        break
    }

} while ($job.InstanceView.ExecutionState -eq "Running")

Write-Host "Job status:" -ForegroundColor Green
$job