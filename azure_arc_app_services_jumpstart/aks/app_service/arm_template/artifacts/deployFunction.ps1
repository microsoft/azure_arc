# choco install azure-functions-core-tools-3 azurefunctions-vscode dotnetcore-sdk vscode-csharp -y

$storageAccountName = "jumpstartappservices" + -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
az storage account create --name $storageAccountName --location $env:azureLocation --resource-group $env:resourceGroup --sku Standard_LRS

Push-Location C:\Temp
func init JumpstartFunctionProj --dotnet
Push-Location C:\Temp\JumpstartFunctionProj
func new --name HttpJumpstart --template "HTTP trigger" --authlevel "anonymous"


$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
$functionAppName = "JumpstartFunction-" + -join ((48..57) + (97..122) | Get-Random -Count 5 | % {[char]$_})

az functionapp create --resource-group $env:resourceGroup --name $functionAppName --custom-location $customLocationId --storage-account $storageAccountName --functions-version 3 --runtime dotnet
func azure functionapp publish $functionAppName

Pop-Location



func azure functionapp fetch-app-settings $functionAppName


dotnet add package Microsoft.Azure.WebJobs.Extensions.Storage --version 3.0.4


$filePath = "C:\Temp\JumpstartFunctionProj\HttpJumpstart.cs"
$toAdd=@'
            [Queue("outqueue"),StorageAccount("AzureWebJobsStorage")] ICollector<string> msg,
'@

$fileContent = Get-Content -Path $filePath
$fileContent[17] = "{0}`r`n{1}" -f $toAdd, $fileContent[17]

$fileContent | Set-Content $filePath

$msgOutputBinding=@'
            if (!string.IsNullOrEmpty(name))
            {
                // Add a message to the output collection.
                msg.Add(string.Format("Name passed to the function: {0}", name));
            }
'@

$toAdd = $msgOutputBinding
$fileContent = Get-Content -Path $filePath
$fileContent[28] = "{0}`r`n{1}" -f $toAdd, $fileContent[28]
$fileContent | Set-Content $filePath

Push-Location C:\Temp\JumpstartFunctionProj
