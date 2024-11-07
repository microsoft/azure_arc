BeforeDiscovery {

    # Login to Azure PowerShell with Managed Identity
    Connect-AzAccount -Identity -Tenant $env:spnTenantId -Subscription $env:subscriptionId

}
Describe "ArcBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 79 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 79
    }
}

