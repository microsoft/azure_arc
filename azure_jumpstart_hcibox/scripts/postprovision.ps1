$resourceGroup  = $env:AZURE_RESOURCE_GROUP
Select-AzSubscription -SubscriptionId $env:AZURE_SUBSCRIPTION_ID | out-null
$rdpPort = $env:JS_RDP_PORT

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