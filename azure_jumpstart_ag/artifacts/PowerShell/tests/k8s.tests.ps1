BeforeDiscovery {

    # Login to Azure PowerShell with Managed Identity
    if($scenario -ne "contoso_supermarket"){
        Connect-AzAccount -Identity -Subscription $env:subscriptionId
    }else {
        $secret = $Env:spnClientSecret
        $clientId = $Env:spnClientId
        $tenantId = $Env:spnTenantId
        $subscriptionId = $Env:subscriptionId

        $azurePassword = ConvertTo-SecureString $secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($clientId, $azurePassword)
        Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal -Subscription $subscriptionId
    }

    # Import the configuration data
    $AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath

    # Initialize an array to hold the ArcClusterName values
    $ArcClusterNames = @()

    # Loop through each SiteConfig and extract the ArcClusterName
    foreach ($site in $AgConfig.SiteConfig.Values) {
        if($site.Type -ne 'AKS'){
            $ArcClusterNames += $site.ArcClusterName
        }
    }

}

Describe "<cluster>" -ForEach $ArcClusterNames {
    BeforeAll {
        $cluster = $_ + "-$($Env:namingGuid)"
        $cluster
        $connectedCluster = Get-AzConnectedKubernetes -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId -Name $cluster
        $aioStatus = az iot ops check --as-object 2>$null | ConvertFrom-Json
        $aioPodStatus = kubectl get pods -n azure-iot-operations -o json | ConvertFrom-Json | Where-Object {$PSItem.items.metadata.name -notlike "*fluent-bit*"}
        $aioPodStatusItems = $aioPodStatus.items | Where-Object {
            $_.spec.containers.name -notmatch "fluent-bit"
        }
        # Run kubectl to get service details in the azure-iot-operations namespace
        $aioServices = kubectl get svc -n azure-iot-operations -o json | ConvertFrom-Json
    }
    It "Cluster exists" {
        $connectedCluster | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected cluster is connected" {
        $connectedCluster.ConnectivityStatus | Should -Be "Connected"
    }
    # It "All pods should be in Running, Completed, or have no containers in CrashLoopBackOff" {
    #     foreach ($pod in $aioPodStatusItems) {
    #         # Check the overall pod phase first
    #         if ($pod.status.phase -in @("Running", "Succeeded")) {
    #             # Now check container statuses within each pod
    #             $containersInCrashLoop = $pod.status.containerStatuses | Where-Object {
    #                 $_.state.waiting.reason -eq "CrashLoopBackOff"
    #             }

    #             # Ensure there are no containers in CrashLoopBackOff for this pod
    #             $containersInCrashLoop | Should -BeNullOrEmpty -Because "Pod $($pod.metadata.name) should not have containers in CrashLoopBackOff"
    #         }
    #         else {
    #             # If the pod phase is not Running or Succeeded, fail the test
    #             $pod.status.phase | Should -BeIn @("Running", "Succeeded") -Because "Pod $($pod.metadata.name) should be Running or Completed"
    #         }
    #     }
    # }
    # Get all pods in the namespace
    $allPods = kubectl get pods -n azure-iot-operations -o json | ConvertFrom-Json
    $allPods = $allPods.items

    # Get control-plane node names
    $controlPlaneNodes = kubectl get nodes -l "node-role.kubernetes.io/control-plane" -o json | ConvertFrom-Json
    if (-not $controlPlaneNodes.items) {
        $controlPlaneNodes = kubectl get nodes -l "node-role.kubernetes.io/master" -o json | ConvertFrom-Json
    }
    $controlPlaneNodeNames = $controlPlaneNodes.items | ForEach-Object { $_.metadata.name }

    # Exclude fluent-bit pods only if they're on control-plane nodes
    $podsToCheck = $allPods | Where-Object {
        !($_.metadata.name -match "fluent-bit" -and $controlPlaneNodeNames -contains $_.spec.nodeName)
    }

    It "All pods (excluding fluent-bit on control-plane) should be in Running, Completed, or have no containers in CrashLoopBackOff" {
        foreach ($pod in $podsToCheck) {
            if ($pod.status.phase -in @("Running", "Succeeded")) {
                $containersInCrashLoop = $pod.status.containerStatuses | Where-Object {
                    $_.state.waiting.reason -eq "CrashLoopBackOff"
                }
                $containersInCrashLoop | Should -BeNullOrEmpty -Because "Pod $($pod.metadata.name) should not have containers in CrashLoopBackOff"
            }
            else {
                $pod.status.phase | Should -BeIn @("Running", "Succeeded") -Because "Pod $($pod.metadata.name) should be Running or Completed"
            }
        }
    }
    if($scenario -ne "contoso_supermarket"){
        It "Azure IoT Operations - aio-operator service should be online with a valid ClusterIP" {
            # Find the aio-operator service in the list
            $aioOperatorService = $aioServices.items | Where-Object { $_.metadata.name -eq "aio-operator" }

            # Verify that the aio-operator service exists
            $aioOperatorService | Should -Not -BeNullOrEmpty -Because "The aio-operator service should exist in the azure-iot-operations namespace"

            # Verify that the aio-operator service has a ClusterIP assigned
            $aioOperatorService.spec.clusterIP | Should -Not -BeNullOrEmpty -Because "The aio-operator service should have a valid ClusterIP assigned"
        }
    }
    It "fluent-bit pods should run only on worker nodes, not on the control-plane node" {
        # Get all fluent-bit pods in the namespace
        $fluentBitPods = kubectl get pods -n azure-iot-operations -o json | ConvertFrom-Json
        $fluentBitPods = $fluentBitPods.items | Where-Object { $_.metadata.name -match "fluent-bit" }

        # Get the node name for the control-plane node (assuming label 'node-role.kubernetes.io/control-plane' or 'master')
        $controlPlaneNodes = kubectl get nodes -l "node-role.kubernetes.io/control-plane" -o json | ConvertFrom-Json
        if (-not $controlPlaneNodes.items) {
            # fallback for older k3s: label might be 'node-role.kubernetes.io/master'
            $controlPlaneNodes = kubectl get nodes -l "node-role.kubernetes.io/master" -o json | ConvertFrom-Json
        }
        $controlPlaneNodeNames = $controlPlaneNodes.items | ForEach-Object { $_.metadata.name }

        # Get all node names
        $allNodeNames = kubectl get nodes -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.metadata.name }
        $workerNodeNames = $allNodeNames | Where-Object { $controlPlaneNodeNames -notcontains $_ }

        # Get the node each fluent-bit pod is running on
        $podsOnControlPlane = $fluentBitPods | Where-Object { $controlPlaneNodeNames -contains $_.spec.nodeName }
        $podsOnWorkers = $fluentBitPods | Where-Object { $workerNodeNames -contains $_.spec.nodeName }

        # Assert
        $podsOnControlPlane | Should -BeNullOrEmpty -Because "No fluent-bit pod should run on the control-plane node"
        $podsOnWorkers | Should -Not -BeNullOrEmpty -Because "At least one fluent-bit pod should run on a worker node"
    }
}
