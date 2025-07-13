BeforeDiscovery {

    $null = Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId

}

if ("True" -eq $env:autoDeployClusterResource) {
Describe "LocalBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 25 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 25
    }
}
} else {
Describe "LocalBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 18 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 18
    }
}
}
