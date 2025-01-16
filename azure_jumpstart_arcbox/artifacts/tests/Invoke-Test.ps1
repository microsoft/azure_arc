#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.6.0"}

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
}

Write-Output "Tests succeeded: $tests_passed"
Write-Output "Tests failed: $tests_failed"

Write-Output "Adding deployment test results to wallpaper using BGInfo"

Set-Content "$Env:windir\TEMP\arcbox-tests-succeeded.txt" $tests_passed
Set-Content "$Env:windir\TEMP\arcbox-tests-failed.txt" $tests_failed

Set-JSDesktopBackground -ImagePath "$Env:ArcBoxDir\wallpaper.bmp"

bginfo.exe $Env:ArcBoxTestsDir\arcbox-bginfo.bgi /timer:0 /NOLICPROMPT

$DeploymentStatusPath = "C:\ArcBox\Logs\DeploymentStatus.log"

Write-Header "Exporting deployment test results to $DeploymentStatusPath"

Write-Output "Deployment Status" | Out-File -FilePath $DeploymentStatusPath

Write-Output "`nTests succeeded: $tests_passed" | Out-File -FilePath $DeploymentStatusPath -Append
Write-Output "Tests failed: $tests_failed`n" | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "To get an updated deployment status, open Windows Terminal and run:" | Out-File -FilePath $DeploymentStatusPath -Append
Write-Output "C:\ArcBox\Tests\Invoke-Test.ps1`n" | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "Failed:" | Out-File -FilePath $DeploymentStatusPath -Append
$tests_common.Failed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_dataops.Failed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_devops.Failed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_itpro.Failed | Out-File -FilePath $DeploymentStatusPath -Append

Write-Output "Passed:" | Out-File -FilePath $DeploymentStatusPath -Append
$tests_common.Passed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_dataops.Passed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_devops.Passed | Out-File -FilePath $DeploymentStatusPath -Append
$tests_itpro.Passed | Out-File -FilePath $DeploymentStatusPath -Append

Write-Header "Exporting deployment test results to resource group tag DeploymentStatus"

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
$null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType "microsoft.compute/virtualmachines" -Tag $tags -Force

# Setup scheduled task for running tests on each logon
$TaskName = "ArcBox Pester tests"
$ActionScript = "C:\ArcBox\Tests\Invoke-Test.ps1"

# Check if the scheduled task exists
if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $TaskName}) {
    Write-Host "Scheduled task '$TaskName' already exists."
} else {
    # Create the task trigger
    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    # Create the task action to use pwsh.exe
    $Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File $ActionScript"

    if ($env:flavor -eq "DataOps") {
        $UserName = "jumpstart\" + $Env:UserName

        # Rename the local user account to avoid scheduled task triggering issues
        Rename-LocalUser -Name $Env:UserName -NewName "$($Env:UserName)_local"

    } else {
        $UserName = $Env:UserName
    }

    # Register the scheduled task for the current user
    Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -User $UserName

    Write-Header "Scheduled task $TaskName created successfully for the currently logged-on user, using pwsh.exe."

    Write-Header "Creating deployment logs bundle"

    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    $LogsBundleTempDirectory = "$Env:windir\TEMP\LogsBundle-$RandomString"
    $null = New-Item -Path $LogsBundleTempDirectory -ItemType Directory -Force

    #required to avoid "file is being used by another process" error when compressing the logs
    Copy-Item -Path "$Env:ArcBoxLogsDir\*.log" -Destination $LogsBundleTempDirectory -Force -PassThru
    Compress-Archive -Path "$LogsBundleTempDirectory\*.log" -DestinationPath "$Env:ArcBoxLogsDir\LogsBundle-$RandomString.zip" -PassThru

    # Enabling Azure VM Auto-shutdown
    if ($env:autoShutdownEnabled -eq "true") {

        Write-Header "Enabling Azure VM Auto-shutdown"

        $ScheduleResource = Get-AzResource -ResourceGroup $env:resourceGroup -ResourceType Microsoft.DevTestLab/schedules
        $Uri = "https://management.azure.com$($ScheduleResource.ResourceId)?api-version=2018-09-15"

        $Schedule = Invoke-AzRestMethod -Uri $Uri

        $ScheduleSettings = $Schedule.Content | ConvertFrom-Json
        $ScheduleSettings.properties.status = "Enabled"

        Invoke-AzRestMethod -Uri $Uri -Method PUT -Payload ($ScheduleSettings | ConvertTo-Json)

    } else {

        Write-Header "Auto-shutdown is not enabled, skipping."

    }

    Stop-Transcript

    # logoff the user to apply the wallpaper in proper scaling and refresh tests results at first logon
    logoff.exe

}