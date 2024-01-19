Start-Transcript -Path C:\ArcBox\logs\Get-PesterResult.log -Force

Write-Output "Get-PesterResult.ps1 started in $(hostname.exe) as user $(whoami.exe) at $(Get-Date)"

$timeout = New-TimeSpan -Minutes 180
$endTime = (Get-Date).Add($timeout)
$logFilePath = "C:\ArcBox\Logs\ArcServersLogonScript.log"

Write-Output "Waiting for PowerShell transcript end in $logFilePath"

do {

    if (Test-Path $logFilePath) {
    Write-Output "Log file $logFilePath exists"

    $content = Get-Content -Path $logFilePath -Tail 5
    if ($content -like "*PowerShell transcript end*") {
        Write-Output "PowerShell transcript end detected in $logFilePath at $(Get-Date)"
        break
    } else {
        Write-Output "PowerShell transcript end not detected in $logFilePath at $(Get-Date) - waiting 60 seconds"
    }
    } else {
        Write-Output "Log file $logFilePath does not yet exist - waiting 60 seconds"
    }
    if ((Get-Date) -ge $endTime) {
       throw "Timeout reached. PowerShell transcript end not found."
    }
    Start-Sleep -Seconds 60
} while ((Get-Date) -lt $endTime)

$spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)

$null = Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spntenantId -Subscription $env:subscriptionId -Scope Process

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:resourceGroup

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