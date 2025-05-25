BeforeDiscovery {

    $null = Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId

}

Describe "LocalBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 25 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 25
    }
}
