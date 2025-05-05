#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.6.0"}

$Env:LocalBoxTestsDir = "$Env:LocalBoxDir\Tests"

# Import Configuration data file
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile

function Wait-AzDeployment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentName,

        [Parameter(Mandatory = $true)]
        [string]$ClusterName,

        [int]$TimeoutMinutes = 240  # Default timeout of 4 hours
    )

    $startTime = Get-Date
    $endTime = $startTime.AddMinutes($TimeoutMinutes)

    $clusterObject = Get-AzStackHciCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction Ignore

    if ($clusterObject) {

        Write-Host "Waiting for deployment '$DeploymentName' in resource group '$ResourceGroupName' to complete..."

        while ($true) {
            $deployment = Get-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName

            if ($deployment.ProvisioningState -ne 'InProgress') {
                Write-Host "Deployment completed with state: $($deployment.ProvisioningState)"
                return $deployment.ProvisioningState
            }

            if (Get-Date -gt $endTime) {
                Write-Host 'Timeout reached. Deployment still in progress.'
                return 'Timeout'
            }

            Write-Host 'Deployment still in progress. Checking again in 1 minute...'
            Start-Sleep -Seconds 60
        }
    } else {
        Write-Host "Cluster '$ClusterName' does not exist - skipping deployment status check..."
    }
}

function Wait-AzLocalClusterConnectivity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$ClusterName,

        [int]$TimeoutMinutes = 60  # Default timeout of 60 minutes
    )

    $startTime = Get-Date
    $endTime = $startTime.AddMinutes($TimeoutMinutes)

    $clusterObject = Get-AzStackHciCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction Ignore

    if ($clusterObject) {

        Write-Host "Waiting for cluster '$ClusterName' in resource group '$ResourceGroupName' to be 'Connected'..."

        while ($true) {
            $clusterObject = Get-AzStackHciCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction Ignore

            if ($clusterObject -and $clusterObject.ConnectivityStatus -eq 'Connected') {
                Write-Host "Cluster '$ClusterName' is now Connected."
                return $true
            }

            if ([DateTime]::Now -gt $endTime) {
                Write-Host "Timeout reached. Cluster '$ClusterName' is still not Connected."
                return $false
            }

            Write-Host "Cluster '$ClusterName' is still not Connected. Checking again in 30 seconds..."
            Start-Sleep -Seconds 30
        }
    } else {
        Write-Host "Cluster '$ClusterName' does not exist - skipping connectivity check..."
    }
}

if ('True' -eq $env:autoDeployClusterResource) {

    # Wait for the deployment to complete
    Wait-AzDeployment -ResourceGroupName $env:resourceGroup -DeploymentName localcluster-deploy -ClusterName $LocalBoxConfig.ClusterName

    # Wait for the cluster to be connected
    Wait-AzLocalClusterConnectivity -ResourceGroupName $env:resourceGroup -ClusterName $LocalBoxConfig.ClusterName

}

Invoke-Pester -Path "$Env:LocalBoxTestsDir\common.tests.ps1" -Output Detailed -PassThru -OutVariable tests_common
$tests_passed = $tests_common.Passed.Count
$tests_failed = $tests_common.Failed.Count


Invoke-Pester -Path "$Env:LocalBoxTestsDir\azlocal.tests.ps1" -Output Detailed -PassThru -OutVariable tests_azlocal
$tests_passed = $tests_passed + $tests_azlocal.Passed.Count
$tests_failed = $tests_failed + $tests_azlocal.Failed.Count


Write-Output "Tests succeeded: $tests_passed"
Write-Output "Tests failed: $tests_failed"

Write-Output 'Exporting deployment test results to resource group tag DeploymentStatus'

$DeploymentStatusString = "Tests succeeded: $tests_passed Tests failed: $tests_failed"

$tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

if ($tests_failed -gt 0) {
    $DeploymentProgressString = 'Failed'
} else {
    $DeploymentProgressString = 'Completed'
}

if ($null -ne $tags) {
    $tags['DeploymentStatus'] = $DeploymentStatusString
    $tags['DeploymentProgress'] = $DeploymentProgressString
} else {
    $tags = @{
        'DeploymentStatus'   = $DeploymentStatusString
        'DeploymentProgress' = $DeploymentProgressString
    }
}

$null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
$null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

Write-Header 'Adding deployment test results to wallpaper using BGInfo'

Set-Content "$Env:windir\TEMP\localbox-tests-succeeded.txt" $tests_passed
Set-Content "$Env:windir\TEMP\localbox-tests-failed.txt" $tests_failed

bginfo.exe $Env:LocalBoxTestsDir\localbox-bginfo.bgi /timer:0 /NOLICPROMPT

# Setup scheduled task for running tests on each logon
$TaskName = 'Pester tests'
$ActionScript = 'C:\LocalBox\Tests\Invoke-Test.ps1'

# Check if the scheduled task exists
if (Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }) {
    Write-Host "Scheduled task '$TaskName' already exists."
} else {
    # Create the task trigger
    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    # Create the task action to use pwsh.exe
    $Action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $ActionScript"

    $UserName = $Env:UserName

    # Register the scheduled task for the current user
    Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -User $UserName

    Write-Header "Scheduled task $TaskName created successfully for the currently logged-on user, using pwsh.exe."

    Stop-Transcript

    # logoff the user to apply the wallpaper in proper scaling and refresh tests results at first logon
    logoff.exe
}