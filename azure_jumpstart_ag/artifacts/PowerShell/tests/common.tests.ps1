BeforeDiscovery {

    $null = Connect-AzAccount -Identity -Tenant $env:spnTenantId  -Subscription $env:subscriptionId

}
Describe "ArcBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 30 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 27
    }
}