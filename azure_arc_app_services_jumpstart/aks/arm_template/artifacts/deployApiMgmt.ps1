Start-Transcript -Path C:\Temp\deployApiMgmt.log

# Login using SP
$userPassword = ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($env:spnClientId, $userPassword)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $env:spntenantId

#Create an API Management Service
function New-RandomName {
    ( -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_}))
}

$Prefix = 'jumpstart'
$APIRandomName = New-RandomName
$APIName = ( $Prefix + '-' + $APIRandomName).ToLower()


Write-Host "Creating Azure API Management instance. Hold tight, this might take an hour..."
New-AzApiManagement -Name $APIName -ResourceGroupName $env:resourceGroup -Location $env:azureLocation -Organization $APIName -AdminEmail $env:adminEmail

  Do {
    Write-Host "Checking if API Management is active."
    Start-Sleep -Seconds 10
    $apiMgmtStatus = $(if(Get-AzApiManagement -Name $APIName -ResourceGroupName $env:resourceGroup | Select-Object "ProvisioningState" | Select-String "Succeeded" -Quiet){"Ready!"}Else{"Nope"})
    } while ($apiMgmtStatus -eq "Nope")
    
# Create a Gateway instance
$apimContext = New-AzApiManagementContext -ResourceGroupName $env:resourceGroup -ServiceName $APIName
$location = New-AzApiManagementResourceLocationObject -Name "n1" -City "c1" -District "d1" -CountryOrRegion "r1"
New-AzApiManagementGateway -Context $apimContext -GatewayId $APIName -Description "ArcAPIMgmt" -LocationData $location

#Enable Management REST API 

Set-AzApiManagementTenantAccess -Context $apimContext -Enabled $True
Get-AzApiManagementTenantAccess -Context $apimContext

# Connecting to the API
$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'='Bearer ' + $token.AccessToken
}
$Temp = (Get-date).AddDays(30)

$Body = @{
    expiry = Get-Date $Temp -Format 'yyyy-MM-ddTHH:mm:ssZ'
    keyType = "primary"
}

$json = $Body | ConvertTo-Json
# Invoke the REST API and retrieve token
$restUri = "https://management.azure.com/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.ApiManagement/service/$APIName/gateways/$APIName/generateToken?api-version=2021-01-01-preview"
$tokenAPI =  Invoke-RestMethod -Uri $restUri -Body $json -Method Post -Headers $authHeader
$token =  "GatewayKey " + $tokenAPI.value
$endpoint="https://$APIName.management.azure-api.net/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.ApiManagement/service/$APIName?api-version=2021-01-01-preview"

# Deploy API Management gateway extension

az k8s-extension create --cluster-type connectedClusters --cluster-name $env:clusterName `
  --resource-group $env:resourceGroup --name apimgmt --extension-type Microsoft.ApiManagement.Gateway `
  --scope namespace --target-namespace apimgmt `
  --configuration-settings gateway.endpoint=$endpoint `
  --configuration-protected-settings gateway.authKey=$token `
  --configuration-settings service.type='LoadBalancer' --release-train preview

  # Importing an API
Write-Host "Importing an API in the Kubernetes environment"
Write-Host "`n"
Import-AzApiManagementApi -Context $apimContext -SpecificationFormat OpenApi -SpecificationUrl https://raw.githubusercontent.com/OAI/OpenAPI-Specification/master/examples/v3.0/petstore.yaml -Path "petstore30"
