BeforeDiscovery {
    $spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
    $spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)

    $null = Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spntenantId -Subscription $env:subscriptionId
}

Describe "ArcBox resource group" -ForEach $VMs {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 20 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 20
    }
}
