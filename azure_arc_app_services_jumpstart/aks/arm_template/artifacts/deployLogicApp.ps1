Start-Transcript -Path C:\Temp\deployLogicApp.log

# Downloading sample Logic App
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/logicAppCode/CreateBlobFromQueueMessage/workflow.json") -OutFile (New-Item -Path "C:\Temp\logicAppCode\CreateBlobFromQueueMessage\workflow.json" -Force)
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/logicAppCode/connections.json") -OutFile (New-Item -Path "C:\Temp\logicAppCode\connections.json" -Force)
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/logicAppCode/host.json") -OutFile (New-Item -Path "C:\Temp\logicAppCode\host.json" -Force)
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/logicAppCode/ARM/connectors-parameters.json") -OutFile (New-Item -Path "C:\Temp\logicAppCode\ARM\connectors-parameters.json" -Force)
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/logicAppCode/ARM/connectors-template.json") -OutFile (New-Item -Path "C:\Temp\logicAppCode\ARM\connectors-template.json" -Force)

# Creating Azure Storage Account for Azure Logic App queue and blob storage
Write-Host "`n"
Write-Host "Creating Azure Storage Account for Azure Logic App example"
Write-Host "`n"
$storageAccountName = "jumpstartappservices" + -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})

# Configuring and deploying sample Logic Apps template Azure dependencies
Write-Host "`n"
Write-Host "Configuring and deploying sample Logic App template Azure dependencies.`n"
Write-Host "Updating connectors-parameters.json with appropriate values.`n"
$connectorsParametersPath = "C:\Temp\logicAppCode\ARM\connectors-parameters.json"
$spnObjectId = az ad sp show --id $env:spnClientID --query objectId -o tsv
(Get-Content -Path $connectorsParametersPath) -replace '<azureLocation>',$env:azureLocation | Set-Content -Path $connectorsParametersPath
(Get-Content -Path $connectorsParametersPath) -replace '<tenantId>',$env:spnTenantId | Set-Content -Path $connectorsParametersPath
(Get-Content -Path $connectorsParametersPath) -replace '<objectId>',$spnObjectId | Set-Content -Path $connectorsParametersPath
(Get-Content -Path $connectorsParametersPath) -replace '<storageAccountName>',$storageAccountName | Set-Content -Path $connectorsParametersPath
az deployment group create --resource-group $env:resourceGroup --template-file "C:\Temp\logicAppCode\ARM\connectors-template.json" --parameters "C:\Temp\logicAppCode\ARM\connectors-parameters.json"
$storageAccountKey = az storage account keys list --account-name $storageAccountName --query [0].value -o tsv
$blobConnectionRuntimeUrl = az resource show --resource-group $env:resourceGroup -n azureblob --resource-type Microsoft.Web/connections --query properties.connectionRuntimeUrl -o tsv
$queueConnectionRuntimeUrl = az resource show --resource-group $env:resourceGroup -n azurequeue --resource-type Microsoft.Web/connections --query properties.connectionRuntimeUrl -o tsv

# Creating the new Logic App in the Kubernetes environment 
Write-Host "Creating the new Azure Logic App application in the Kubernetes environment"
Write-Host "`n"
$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
$logicAppName = "JumpstartLogicApp-" + -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
az logicapp create --resource-group $env:resourceGroup --name $logicAppName --custom-location $customLocationId --storage-account $storageAccountName
Do {
    Write-Host "Waiting for Azure Logic App to become available. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 15
    $buildService = $(if(kubectl get pods -n appservices | Select-String $logicAppName | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($buildService -eq "Nope")

Do {
    Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 15
    $logProcessorStatus = $(if(kubectl describe daemonset "arc-app-services-k8se-log-processor" -n appservices | Select-String "Pods Status:  3 Running" -Quiet){"Ready!"}Else{"Nope"})
    } while ($logProcessorStatus -eq "Nope")

# Deploy Logic App code
Write-Host "Packaging sample Logic App code and deploying to Azure Arc enabled Logic App.`n"
$compress = @{
    Path = "C:\Temp\logicAppCode\CreateBlobFromQueueMessage", "C:\Temp\logicAppCode\connections.json", "C:\Temp\logicAppCode\host.json"
    CompressionLevel = "Fastest"
    DestinationPath = "C:\Temp\logicAppCode.zip"
}
Compress-Archive @compress
# az logicapp deployment source config-zip --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --src c:\Temp\logicAppCode.zip
# Temporary workaround - az logicapp create not currently working with Arc-enabled clusters
# pushd "C:\Temp\logicAppCode"
# func azure functionapp publish $logicAppName --node
# popd
# end temp workaround

# Configuring Logic App settings
Write-Host "Configuring Logic App settings.`n"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "resourceGroup=$env:resourceGroup"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "subscriptionId=$env:subscriptionId"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "location=$env:azureLocation"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "spnClientId=$env:spnClientId"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "spnTenantId=$env:spnTenantId"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "spnClientSecret=$env:spnClientSecret"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "storageAccountName=$storageAccountName"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "queueConnectionRuntimeUrl=$queueConnectionRuntimeUrl"
# az logicapp config appsettings set --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId --settings "blobConnectionRuntimeUrl=$blobConnectionRuntimeUrl"

# Start Logic App
Write-Host "Starting Logic App.`n"
# az logicapp start --name $logicAppName --resource-group $env:resourceGroup --subscription $env:subscriptionId

# Creating a While loop to generate 10 Azure Function application messages to storage queue
Write-Host "`n"
Write-Host "Creating a While loop to generate 10 messages to storage queue"
Write-Host "`n"
$i=1
Do {
    $messageString = "?name=Jumpstart"+$i
    az storage message put --content $messageString --queue-name "jumpstart-queue" --account-name $storageAccountName --account-key $storageAccountKey --auth-mode key
    $i++
    }
While ($i -le 10)

Write-Host "Finished deploying Logic App.`n"
