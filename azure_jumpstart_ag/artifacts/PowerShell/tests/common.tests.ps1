BeforeDiscovery {

    # Login to Azure PowerShell with Managed Identity
    if($scenario -ne "contoso_supermarket"){
        Connect-AzAccount -Identity -Subscription $env:subscriptionId
    }else {
        $secret = $Env:spnClientSecret
        $clientId = $Env:spnClientId
        $tenantId = $Env:spnTenantId
        $subscriptionId = $Env:subscriptionId

        $azurePassword = ConvertTo-SecureString $secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($clientId, $azurePassword)
        Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal -Subscription $subscriptionId
    }

}
Describe "ArcBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    if($scenario -ne "contoso_supermarket"){
        It "should have 79 resources or more" {
            (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 79
        }
    }else{
        It "should have 24 resources or more" {
            (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 24
        }
    }
}

