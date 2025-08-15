$Env:LocalBoxDir = 'C:\LocalBox'
$Env:LocalBoxLogsDir = "$Env:LocalBoxDir\Logs"
$Env:LocalBoxTestsDir = "$Env:LocalBoxDir\Tests"

Start-Transcript -Path "$Env:LocalBoxLogsDir\Get-PesterResult_$($PID).log" -Force

Write-Output "Get-PesterResult.ps1 started in $(hostname.exe) as user $(whoami.exe) at $(Get-Date)"

$timeout = New-TimeSpan -Minutes 180
$endTime = (Get-Date).Add($timeout)


$logFilePath = 'C:\LocalBox\Logs\New-LocalBoxCluster.log'

Write-Output "Adding Storage Blob Data Contributor role assignment to Managed Identity for allowing upload of Pester test results to Azure Storage"

$null = Connect-AzAccount -Identity -Scope Process

Write-Output 'Wait for Azure CLI to become available (installed by WinGet)'

# Starting time
$startTime = Get-Date

# Duration to wait (60 minutes)
$duration = New-TimeSpan -Minutes 60

do {
    # Check if the path exists
    $exists = Test-Path 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

    # Break if the path exists
    if ($exists) {
        Write-Host 'File found.'
        break
    }

    # Wait for a short period before rechecking to avoid constant CPU usage
    Start-Sleep -Seconds 30

} while ((Get-Date) -lt $startTime.Add($duration))

if (-not $exists) {
    Write-Host 'File not found within the 60-minute time frame.'
}

# Get the current path
$currentPath = $env:Path

# Path to be added
$newPath = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin'

# Add the new path to the current session's Path environment variable
$env:Path = $currentPath + ';' + $newPath

Write-Output 'Az CLI Login'
az login --identity
az account set -s $env:subscriptionId

$MetaData = (Invoke-RestMethod -Headers @{Metadata="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01").compute

$vmResourceId = $MetaData.resourceId
$resourceGroup = $MetaData.resourceGroupName

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup  | Where-Object storageaccountname -notlike localboxdiag* | select-object -First 1
if ($null -eq $StorageAccount) {
    Write-Error -Message "No storage account found in resource group $resourceGroup"
    exit 1
}


# Get the VM resource
$vm = Get-AzResource -ResourceId $vmResourceId

# Get the identity objectId
$vm.Identity.PrincipalId

if (Get-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName 'Storage Blob Data Contributor' -Scope $StorageAccount.Id) {

    Write-Output 'Role assignment already exists'

} else {

    Write-Output 'Role assignment does not yet exist'
    $null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName 'Storage Blob Data Contributor' -Scope $StorageAccount.Id

    Write-Output 'Wait for eventual consistency after RBAC assignment'
    Start-Sleep 120

}

Write-Output "Waiting for deployment end in $logFilePath"

do {

    if (Test-Path $logFilePath) {
        Write-Output "Log file $logFilePath exists"

        $content = Get-Content -Path $logFilePath
        if ($content -like '*Running tests to verify infrastructure*') {
            Write-Output "Deployment end detected in $logFilePath at $(Get-Date)"
            break
        } else {
            Write-Output "Deployment end not detected in $logFilePath at $(Get-Date) - waiting 60 seconds"
        }
    } else {
        Write-Output "Log file $logFilePath does not yet exist - waiting 60 seconds"
    }
    if ((Get-Date) -ge $endTime) {
        throw 'Timeout reached. Deployment end not found.'
    }
    Start-Sleep -Seconds 60
} while ((Get-Date) -lt $endTime)


$ctx = New-AzStorageContext -StorageAccountName $StorageAccount.StorageAccountName -UseConnectedAccount

New-AzStorageContainer -Name testresults -Context $ctx -Permission Off

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
                Write-Host "Timeout reached. Cluster '$ClusterName' is still not Connected: $($clusterObject.ConnectivityStatus)"
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
    Wait-AzLocalClusterConnectivity -ResourceGroupName $env:resourceGroup -ClusterName $LocalBoxConfig.ClusterName -TimeoutMinutes 180

}

Write-Output 'Running Pester tests'

$Env:LocalBoxDir = 'C:\LocalBox'
$Env:LocalBoxLogsDir = "$Env:LocalBoxDir\Logs"
$Env:LocalBoxTestsDir = "$Env:LocalBoxDir\Tests"

Import-Module -Name Pester -Force

$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$Env:LocalBoxLogsDir\common.tests.xml"
$config.Output.CIFormat = 'AzureDevops'
$config.Run.Path = "$Env:LocalBoxTestsDir\common.tests.ps1"
Invoke-Pester -Configuration $config


$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$Env:LocalBoxLogsDir\azlocal.tests.xml"
$config.Output.CIFormat = 'AzureDevops'
$config.Run.Path = "$Env:LocalBoxTestsDir\azlocal.tests.ps1"
Invoke-Pester -Configuration $config


Write-Output 'Uploading file to Azure Storage'

Get-ChildItem $Env:LocalBoxLogsDir -Filter *.xml | ForEach-Object {
    $blobname = "$($_.Name)"
    Write-Output "Uploading file $($_.Name) to blob $blobname"
    Set-AzStorageBlobContent -File $_.FullName -Container testresults -Blob $blobname -Context $ctx
}

Write-Output "Get-PesterResult.ps1 finished at $(Get-Date)"

Stop-Transcript