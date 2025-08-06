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

$null = Connect-AzAccount -Identity -Scope Process

$MetaData = (Invoke-RestMethod -Headers @{Metadata="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01").compute

$vmResourceId = $MetaData.resourceId
$resourceGroup = $MetaData.resourceGroupName

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup

# Get the VM resource
$vm = Get-AzResource -ResourceId $vmResourceId

# Get the identity objectId
$vm.Identity.PrincipalId

Write-Output "Adding Storage Blob Data Contributor role assignment to Managed Identity $($vm.Identity.PrincipalId)) for allowing upload of Pester test results to Azure Storage"

$maxRetries = 5
$retryDelay = 30
$attempt = 0
$roleAssigned = $false

while (-not $roleAssigned -and $attempt -lt $maxRetries) {
    try {
        $attempt++

        if (Get-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $StorageAccount.Id -ErrorAction Stop) {
            Write-Output "Role assignment already exists"
            $roleAssigned = $true
        } else {
            Write-Output "Role assignment does not yet exist"
            $null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $StorageAccount.Id -ErrorAction Stop
            Write-Output "Wait for eventual consistency after RBAC assignment"
            Start-Sleep 120
            $roleAssigned = $true
        }
    } catch {
        Write-Warning "Attempt $attempt : Failed to assign role. Error: $_. Exception.Message"
        if ($attempt -lt $maxRetries) {
            Write-Output "Retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        } else {
            throw "Failed to assign Storage Blob Data Contributor role after $maxRetries attempts."
        }
    }
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

Start-Sleep -Seconds 60

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
