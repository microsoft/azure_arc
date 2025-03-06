BeforeDiscovery {

    $null = Connect-AzAccount -Identity -Tenant $env:spnTenantId -Subscription $env:subscriptionId

}

Describe "ArcBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 25 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 25
    }
}
