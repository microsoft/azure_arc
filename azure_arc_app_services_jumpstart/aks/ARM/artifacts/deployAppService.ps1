Start-Transcript -Path C:\Temp\deployAppService.log

Write-Host "Creating App Service plan. Hold tight, this might take a few minutes..."
Write-Host "`n"
$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $Env:resourceGroup --query id -o tsv)
az appservice plan create --resource-group $Env:resourceGroup --name Jumpstart --custom-location $customLocationId --per-site-scaling --is-linux --sku K1

Write-Host "Deploy a sample Azure Arc Jumpstart web application"
Write-Host "`n"
az webapp create --plan Jumpstart --resource-group $Env:resourceGroup --name jumpstart-app --custom-location $customLocationId --deployment-container-image-name azurearcjumpstart.azurecr.io/hello-arc:latest
az webapp config appsettings set --resource-group $Env:resourceGroup --name jumpstart-app --settings WEBSITES_PORT=8080
