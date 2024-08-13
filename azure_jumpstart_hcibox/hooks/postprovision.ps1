$resourceGroup  = $env:AZURE_RESOURCE_GROUP
Select-AzSubscription -SubscriptionId $env:AZURE_SUBSCRIPTION_ID | out-null
$rdpPort = $env:JS_RDP_PORT

########################################################################
# RDP Port
########################################################################

# Configure NSG Rule for RDP (if needed)
If ($rdpPort -ne "3389") {

    Write-Host "Configuring NSG Rule for RDP..."
    $nsg =  Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name HCIBox-NSG

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
}


# Client VM IP address
$ip = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup -Name "HCIBox-Client-PIP" -ErrorAction SilentlyContinue).IpAddress | Out-Null
if ($null -ne $ip) {
    Write-Host "You can now connect to the client VM using the following command: " -NoNewline
    Write-Host "mstsc /v:$($ip):$($rdpPort)" -ForegroundColor Green -BackgroundColor Black
    Write-Host "Remember to use the Windows admin user name [$env:JS_WINDOWS_ADMIN_USERNAME] and the password you specified."
}