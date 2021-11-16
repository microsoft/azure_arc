Start-Transcript -Path C:\Temp\deployFunction.log

# Creting Azure Storage Account for Azure Function application queue usage
Write-Host "`n"
Write-Host "Creting Azure Storage Account for Azure Function application queue usage"
Write-Host "`n"
$storageAccountName = "jumpstartappservices" + -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
az storage account create --name $storageAccountName --location $env:azureLocation --resource-group $env:resourceGroup --sku Standard_LRS

# Creating local Azure Function application project
Write-Host "`n"
Write-Host "Creating local Azure Function application project"
Write-Host "`n"
Push-Location C:\Temp
func init JumpstartFunctionProj --dotnet --version 5.0
Push-Location C:\Temp\JumpstartFunctionProj
func new --name HttpJumpstart --template "HTTP trigger" --authlevel "anonymous"

# Creating the new function application in the Kubernetes environment 
$extensionName = "arc-app-services"
Write-Host "Creating the new Azure Function application in the Kubernetes environment"
Write-Host "`n"
$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
$functionAppName = "JumpstartFunction-" + -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
az functionapp create --resource-group $env:resourceGroup --name $functionAppName --custom-location $customLocationId --storage-account $storageAccountName --functions-version 3 --runtime dotnet

Do {
    Write-Host "Waiting for Azure Function application to become available. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 15
    $buildService = $(if(kubectl get pods -n appservices | Select-String $functionAppName | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($buildService -eq "Nope")
    
Do {
    Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $logProcessorStatus = $(if(kubectl describe daemonset ($extensionName + "-k8se-log-processor") -n appservices | Select-String "Pods Status:  4 Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($logProcessorStatus -eq "Nope")
   

# Retrieving the Azure Storage connection string & Registering binding extensions
Write-Host "`n"
Write-Host "Retrieving the Azure Storage connection string & Registering binding extensions"
Write-Host "`n"
func azure functionapp fetch-app-settings $functionAppName
# dotnet add package Microsoft.Azure.WebJobs.Extensions.Storage --version 3.0.4
dotnet add package Microsoft.Azure.WebJobs.Extensions.Storage

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
$string = Get-Content C:\Temp\JumpstartFunctionProj\local.settings.json | Select-Object -Index 3
$string.Split(' ')[-1] | Out-File C:\Temp\funcStorage.txt
$string = Get-Content C:\Temp\funcStorage.txt
$string = $string.TrimEnd(",") | Out-File C:\Temp\funcStorage.txt
$string = Get-Content C:\Temp\funcStorage.txt
$env:AZURE_STORAGE_CONNECTION_STRING = $string

# Publishing the Azure Function application to Azure
Write-Host "`n"
Write-Host "Publishing the Azure Function application to Azure"
Write-Host "`n"
func azure functionapp publish $functionAppName | Out-File C:\Temp\funcPublish.txt
Start-Sleep -Seconds 60
$funcUrl = Get-Content C:\Temp\funcPublish.txt | Select-String "https://" | Out-File C:\Temp\funcUrl.txt
$funcUrl = Get-Content C:\Temp\funcPublish.txt | Select-Object -Last 2 | Out-File C:\Temp\funcUrl.txt
$funcUrl = Get-Content C:\Temp\funcUrl.txt
$funcUrl.TrimStart("     ") | Out-File C:\Temp\funcUrl.txt
$funcUrl = Get-Content C:\Temp\funcUrl.txt
$funcUrl.TrimStart("Invoke url: ") | Out-File C:\Temp\funcUrl.txt
$funcUrl = Get-Content C:\Temp\funcUrl.txt
(Get-Content C:\Temp\funcUrl.txt) | Where-Object {$_.trim() -ne "" } | Set-Content C:\Temp\funcUrl.txt
$funcUrl = Get-Content C:\Temp\funcUrl.txt


# Creating a While loop to generate 10 Azure Function application messages to storage queue
Write-Host "`n"
Write-Host "Creating a While loop to generate 10 Azure Function application messages to storage queue"
Write-Host "`n"
$i=1
Do {
    $messageString = "?name=Jumpstart"+$i
    $invokeUri = $funcUrl + $messageString
    Invoke-WebRequest -URI $invokeUri -UseBasicParsing
    $i++
    }
While ($i -le 10)
