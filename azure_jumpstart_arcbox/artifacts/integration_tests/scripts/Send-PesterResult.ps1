$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"

Start-Transcript -Path "$Env:ArcBoxLogsDir\Get-PesterResult_$($PID).log" -Force

Write-Output "Get-PesterResult.ps1 started in $(hostname.exe) as user $(whoami.exe) at $(Get-Date)"

$timeout = New-TimeSpan -Minutes 180
$endTime = (Get-Date).Add($timeout)


switch ($env:flavor) {
    'DevOps' {
        $logFilePath = "$Env:ArcBoxLogsDir\DevOpsLogonScript.log"
}
    'DataOps' {
        $logFilePath = "$Env:ArcBoxLogsDir\DataOpsLogonScript.log"
    }
    'ITPro' {
        $logFilePath = "$Env:ArcBoxLogsDir\ArcServersLogonScript.log"
    }
    'default' {
        throw "Unknown flavor $env:flavor"
    }
}

Write-Output "Adding Storage Blob Data Contributor role assignment to SPN $env:spnClientId for allowing upload of Pester test results to Azure Storage"

$null = Connect-AzAccount -Identity -Scope Process

Write-Output "Wait for Azure CLI to become available (installed by WinGet)"

# Starting time
$startTime = Get-Date

# Duration to wait (60 minutes)
$duration = New-TimeSpan -Minutes 60

do {
    # Check if the path exists
    $exists = Test-Path "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"

    # Break if the path exists
    if ($exists) {
        Write-Host "File found."
        break
    }

    # Wait for a short period before rechecking to avoid constant CPU usage
    Start-Sleep -Seconds 30

} while ((Get-Date) -lt $startTime.Add($duration))

if (-not $exists) {
    Write-Host "File not found within the 60-minute time frame."
}

# Get the current path
$currentPath = $env:Path

# Path to be added
$newPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"

# Add the new path to the current session's Path environment variable
$env:Path = $currentPath + ";" + $newPath

Write-Output "Az CLI Login"
az login --identity
az account set -s $env:subscriptionId

$ClientObjectId = Get-AzContext

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:resourceGroup

# Get the VM's resource ID
$vmResourceId = (Invoke-RestMethod -Headers @{Metadata="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01").compute.resourceId

# Get the VM resource
$vm = Get-AzResource -ResourceId $vmResourceId

# Get the identity objectId
$vm.Identity.PrincipalId

if (Get-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $StorageAccount.Id) {

    Write-Output "Role assignment already exists"

} else {

    Write-Output "Role assignment does not yet exist"
    $null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $StorageAccount.Id

    Write-Output "Wait for eventual consistency after RBAC assignment"
    Start-Sleep 120

}

Write-Output "Waiting for deployment end in $logFilePath"

do {

    if (Test-Path $logFilePath) {
    Write-Output "Log file $logFilePath exists"

    $content = Get-Content -Path $logFilePath
    if ($content -like "*Running tests to verify infrastructure*") {
        Write-Output "Deployment end detected in $logFilePath at $(Get-Date)"
        break
    } else {
        Write-Output "Deployment end not detected in $logFilePath at $(Get-Date) - waiting 60 seconds"
    }
    } else {
        Write-Output "Log file $logFilePath does not yet exist - waiting 60 seconds"
    }
    if ((Get-Date) -ge $endTime) {
       throw "Timeout reached. Deployment end not found."
    }
    Start-Sleep -Seconds 60
} while ((Get-Date) -lt $endTime)


$ctx = New-AzStorageContext -StorageAccountName $StorageAccount.StorageAccountName -UseConnectedAccount

New-AzStorageContainer -Name testresults -Context $ctx -Permission Off


Write-Output "Running Pester tests"

$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"
$Env:ArcBoxTestsDir = "$Env:ArcBoxDir\Tests"

Import-Module -Name Pester -Force

$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\common.tests.xml"
$config.Output.CIFormat = "AzureDevops"
$config.Run.Path  = "$Env:ArcBoxTestsDir\common.tests.ps1"
Invoke-Pester -Configuration $config

switch ($env:flavor) {
    'DevOps' {
        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\devops.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\devops.tests.ps1"
        Invoke-Pester -Configuration $config
}
    'DataOps' {
        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\dataops.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\dataops.tests.ps1"
        Invoke-Pester -Configuration $config
    }
    'ITPro' {
        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\itpro.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\itpro.tests.ps1"
        Invoke-Pester -Configuration $config
}
    'Full' {
        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\devops.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\devops.tests.ps1"
        Invoke-Pester -Configuration $config

        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\dataops.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\dataops.tests.ps1"
        Invoke-Pester -Configuration $config

        $config = [PesterConfiguration]::Default
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = "$Env:ArcBoxLogsDir\itpro.tests.xml"
        $config.Output.CIFormat = "AzureDevops"
        $config.Run.Path  = "$Env:ArcBoxTestsDir\itpro.tests.ps1"
        Invoke-Pester -Configuration $config
    }
}

Write-Output "Uploading file to Azure Storage"

Get-ChildItem $Env:ArcBoxLogsDir -Filter *.xml | ForEach-Object {
    $blobname = "$($_.Name)"
    Write-Output "Uploading file $($_.Name) to blob $blobname"
    Set-AzStorageBlobContent -File $_.FullName -Container testresults -Blob $blobname -Context $ctx
}

Write-Output "Get-PesterResult.ps1 finished at $(Get-Date)"

Stop-Transcript