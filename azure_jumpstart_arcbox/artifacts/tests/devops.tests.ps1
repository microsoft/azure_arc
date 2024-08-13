
BeforeDiscovery {

    $k3sArcDataClusterName = $env:k3sArcDataClusterName
    $k3sArcClusterName = $env:k3sArcClusterName

    $clusters = @($k3sArcDataClusterName, $k3sArcClusterName)
    $VMs = @($k3sArcDataClusterName, $k3sArcClusterName)

    $null = Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId
    az config set extension.use_dynamic_install=yes_without_prompt
}

Describe "<cluster>" -ForEach $clusters {
    BeforeAll {
        $cluster = $_
    }
    It "Cluster exists" {
        $clusterObject = Get-AzConnectedKubernetes -ClusterName $cluster -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $clusterObject | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected cluster is connected" {
        $connectedCluster = Get-AzConnectedKubernetes -Name $cluster -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedCluster.ConnectivityStatus | Should -Be "Connected"
    }
}