
BeforeDiscovery {
    $VMs = @("ArcBox-SQL", "ArcBox-Ubuntu-01", "ArcBox-Ubuntu-02","ArcBox-Win2K19","ArcBox-Win2K22")
    $null = Connect-AzAccount -Identity -Tenant $env:spntenantId -Subscription $env:subscriptionId
}

# Assert that the Hyper-V virtual machines in $VMs exists, are running and connected as Azure Arc-enabled servers

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
