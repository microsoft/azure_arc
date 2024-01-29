
BeforeDiscovery {

    $capiArcDataClusterName = $env:capiArcDataClusterName
    $aksArcClusterName = $env:aksArcClusterName
    $aksdrArcClusterName = $env:aksdrArcClusterName

    $clusters = @($capiArcDataClusterName, $aksArcClusterName, $aksdrArcClusterName)
    $customLocations = @("${capiArcDataClusterName}-cl", "${aksArcClusterName}-cl", "${aksdrArcClusterName}-cl")
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

Describe "<customLocation>" -ForEach $customLocations {
    BeforeAll {
        $customLocation = $_
    }
    It "Custom Location exists" {
        $customLocationObject = Get-AzCustomLocation -Name $customLocation -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $customLocationObject | Should -Not -BeNullOrEmpty
    }
    It "Custom Location is connected" {
        $customLocationObject = Get-AzCustomLocation -Name $customLocation -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $customLocationObject.ProvisioningState | Should -Be "Succeeded"
    }
}

<#
Describe "<dataController>" -ForEach $dataController {
    BeforeAll {
        $dataController = $_
    }
    It "Data Controller exists" {
        az arcdata dc list --resource-group sb-arcbox --query "[].{name:name,state:properties.k8SRaw.status.state}"
        $dataControllerObject = Get-AzDataController -Name $dataController -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $dataControllerObject | Should -Not -BeNullOrEmpty
    }
    It "Data Controller is connected" {
        $dataControllerObject = Get-AzDataController -Name $dataController -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $dataControllerObject.ProvisioningState | Should -Be "Succeeded"
    }
}
#>