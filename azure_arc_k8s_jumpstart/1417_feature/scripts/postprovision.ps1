if ($null -ne $env:AZURE_RESOURCE_GROUP){
    $resourceGroup  = $env:AZURE_RESOURCE_GROUP
    Select-AzSubscription -SubscriptionId $env:AZURE_SUBSCRIPTION_ID | out-null
    $rdpPort = $env:JS_RDP_PORT
}

########################################################################
# RDP Port
########################################################################

# Configure NSG Rule for RDP (if needed)
If ($rdpPort -ne "3389") {

    Write-Host "Configuring NSG Rule for RDP..."
    $nsg =  Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name AKS-EE-Demo-NSG

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
