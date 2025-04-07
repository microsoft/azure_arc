
BeforeDiscovery {

    # Import Configuration data file
    $LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile

    $VMs = $LocalBoxConfig.NodeHostConfig.Hostname
    $clusters = @($LocalBoxConfig.ClusterName)

    # Login to Azure PowerShell with service principal provided by user
    $spnpassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
    $spncredential = New-Object System.Management.Automation.PSCredential ($env:spnClientId, $spnpassword)
    Connect-AzAccount -ServicePrincipal -Credential $spncredential -Tenant $env:spntenantId -Subscription $env:subscriptionId

}

if ("True" -eq $env:autoDeployClusterResource) {
    Describe "<cluster>" -ForEach $clusters {
        BeforeAll {
            $cluster = $_
            $clusterObject = Get-AzStackHciCluster -ResourceGroupName $env:resourceGroup -Name $cluster
        }
        It "Cluster exists" {
            $clusterObject | Should -Not -BeNullOrEmpty
        }
        It "Azure Arc Connected cluster is successfully provisioned" {
            $clusterObject.ProvisioningState | Should -Be "Succeeded"
        }
        It "Azure Arc Connected cluster is connected" {
            $clusterObject.ConnectivityStatus | Should -Be "Connected"
        }
    }

}

Describe "<vm>" -ForEach $VMs {
    BeforeAll {
        $vm = $_
    }
    It "VM exists" {
        $vmobject = Get-VM -Name $vm
        $vmobject | Should -Not -BeNullOrEmpty
    }
    It "VM is running" {
        $vmobject = Get-VM -Name $vm
        $vmobject.State | Should -Be "Running"
    }
    It "Azure Arc Connected Machine exists" {
        $connectedMachine = Get-AzConnectedMachine -Name $vm -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedMachine | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected Machine is connected" {
        $connectedMachine = Get-AzConnectedMachine -Name $vm -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedMachine.Status | Should -Be "Connected"
    }
}