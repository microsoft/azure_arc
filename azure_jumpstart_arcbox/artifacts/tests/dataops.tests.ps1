
BeforeDiscovery {

    $capiArcDataClusterName = $env:capiArcDataClusterName
    $aksArcClusterName = $env:aksArcClusterName
    $aksdrArcClusterName = $env:aksdrArcClusterName

    $clusters = @($capiArcDataClusterName, $aksArcClusterName, $aksdrArcClusterName)
    $dataControllers = @("${capiArcDataClusterName}-dc", "${aksArcClusterName}-dc", "${aksdrArcClusterName}-dc")
    $sqlInstances = @("capi-sql", "aks-sql", "aks-dr-sql")

    $spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
    $spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)

    $null = Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spntenantId -Subscription $env:subscriptionId
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