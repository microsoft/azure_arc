BeforeDiscovery {

    $clusters = @("Ag-K3s-Chicago","Ag-K3s-Seattle")

    # Login to Azure PowerShell with service principal provided by user
    $spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
    $spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)
    Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spnTenantId -Subscription $env:subscriptionId

}

Describe "<cluster>" -ForEach $clusters {
    BeforeAll {
        $cluster = $_
        $connectedCluster = Get-AzConnectedKubernetes -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId | Where-Object Name -like $cluster*
    }
    It "Cluster exists" {
        $connectedCluster  | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected cluster is connected" {
        $connectedCluster.ConnectivityStatus | Should -Be "Connected"
    }
}