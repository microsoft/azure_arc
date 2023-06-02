if ($null -ne $env:AZURE_RESOURCE_GROUP){
    $resourceGroup  = $env:AZURE_RESOURCE_GROUP
    $adxClusterName = $env:ADX_CLUSTER_NAME
    Select-AzSubscription -SubscriptionId $env:AZURE_SUBSCRIPTION_ID | out-null
    $rdpPort = $env:JS_RDP_PORT
} else {
    # This section is for testing only
    $resourceGroup  = "charris-js-ag-43-rg"
    $adxClusterName = "agadx2827a"
    Get-AzSubscription -SubscriptionName "Azure Arc Jumpstart Subscription" | Select-AzSubscription
}

########################################################################
# ADX Dashboards
########################################################################

Write-Host "Importing Azure Data Explorer dashboards..."

# Get the ADX/Kusto cluster info
$kustoCluster = Get-AzKustoCluster -ResourceGroupName $resourceGroup -Name $adxClusterName
$adxEndPoint = $kustoCluster.Uri

# Update the dashboards files with the new ADX cluster name and URI
$templateBaseUrl = "https://raw.githubusercontent.com/charris-msft/azure_arc/jumpstart_ag/azure_jumpstart_ag/"
$ordersDashboardBody     = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx_dashboards/adx-dashboard-orders-payload.json").Content -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName
$iotSensorsDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx_dashboards/adx-dashboard-iotsensor-payload.json") -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName

# Get access token to make REST API call to Azure Data Explorer Dashabord API. Replace double quotes surrounding access token
$token = (az account get-access-token --scope "https://rtd-metadata.azurewebsites.net/user_impersonation openid profile offline_access" --query "accessToken") -replace "`"", ""

# Prepare authorization header with access token
$httpHeaders = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

# Make REST API call to the dashboard endpoint.
$dashboardApi = "https://dashboards.kusto.windows.net/dashboards"

# Import orders dashboard report
$httpResponse = Invoke-WebRequest -Method Post -Uri $dashboardApi -Body $ordersDashboardBody -Headers $httpHeaders
if ($httpResponse.StatusCode -ne 200){
    Write-Host "ERROR: Failed import orders dashboard report into Azure Data Explorer" -ForegroundColor Red
}

# Import IoT Sensor dashboard report
$httpResponse = Invoke-WebRequest -Method Post -Uri $dashboardApi -Body $iotSensorsDashboardBody -Headers $httpHeaders
if ($httpResponse.StatusCode -ne 200){
    Write-Host "ERROR: Failed import IoT Sensor dashboard report into Azure Data Explorer" -ForegroundColor Red
}


########################################################################
# RDP Port
########################################################################

# Configure NSG Rule for RDP (if needed)
If ($rdpPort -ne "3389") {

    Write-Host "Configuring NSG Rule for RDP..."
    $nsg =  Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name Ag-NSG-Prod

    Add-AzNetworkSecurityRuleConfig `
        -NetworkSecurityGroup $nsg `
        -Name "RDP-$rdpPort" `
        -Description "Allow RDP" `
        -Access Allow `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 100 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange $rdpPort `
        | Out-Null

    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
    # az network nsg rule create -g $resourceGroup --nsg-name Ag-NSG-Prod --name "RDC-$rdpPort" --priority 100 --source-address-prefixes * --destination-port-ranges $rdpPort --access Allow --protocol Tcp
}


# Client VM IP address
$ip = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup -Name "Ag-VM-Client-PIP").IpAddress

Write-Host "You can now connect to the client VM using the following command: " -NoNewline
WRite-Host "mstsc /v:$($ip):$($rdpPort)" -ForegroundColor Green -BackgroundColor Black
Write-Host "Remember to use the Windows admin user name [$env:JS_WINDOWS_ADMIN_USERNAME] and the password you specified."
