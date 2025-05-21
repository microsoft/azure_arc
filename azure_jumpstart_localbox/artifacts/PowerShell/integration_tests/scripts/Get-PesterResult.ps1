param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

Write-Host "Getting Pester test-result files from storage account in resource group $ResourceGroupName"

$path = $ENV:SYSTEM_DEFAULTWORKINGDIRECTORY + "/testresults"
$null = New-Item -ItemType Directory -Force -Path $path

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName | Where-Object storageaccountname -notlike localboxdiag* | select-object -First 1
if ($null -eq $StorageAccount) {
    Write-Error -Message "No storage account found in resource group $ResourceGroupName"
    exit 1
}
$ctx = New-AzStorageContext -StorageAccountName $StorageAccount.StorageAccountName -UseConnectedAccount
$blobs = Get-AzStorageBlob -Container "testresults" -Context $ctx

foreach ($blob in $blobs) {

    $destinationblobname = ($blob.Name).Split("/")[-1]
    $destinationpath = "$path/$($destinationblobname)"

    try {
        Get-AzStorageBlobContent -Container "testresults" -Blob $blob.Name -Destination $destinationpath -Context $ctx -ErrorAction Stop
    }
    catch {
        Write-Error -Message "Failed to download blob $blob.Name"
    }

}