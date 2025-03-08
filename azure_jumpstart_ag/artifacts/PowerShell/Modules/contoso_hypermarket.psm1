function Get-K3sConfigFile {
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Host "Downloading k3s Kubeconfigs"
    $Env:AZCOPY_AUTO_LOGIN_TYPE = "PSCRED"
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
        $containerName = $arcClusterName.toLower()
        $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/config"
        azcopy copy $sourceFile "C:\Users\$adminUsername\.kube\ag-k3s-$clusterName" --check-length=false
        $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/*"
        azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile "$AgLogsDir\" --include-pattern "*.log"
    }
}

function Merge-K3sConfigFiles {

    $mergedKubeconfigPath = "C:\Users\$adminUsername\.kube\config"

    $kubeconfig1Path = "C:\Users\$adminUsername\.kube\ag-k3s-seattle"
    $kubeconfig2Path = "C:\Users\$adminUsername\.kube\ag-k3s-chicago"

    # Extract base file names (without extensions) to use as new names
    $suffix1 = [System.IO.Path]::GetFileNameWithoutExtension($kubeconfig1Path)
    $suffix2 = [System.IO.Path]::GetFileNameWithoutExtension($kubeconfig2Path)

    # Load the kubeconfig files, ensuring no empty lines or structures
    $kubeconfig1 = get-content $kubeconfig1Path | ConvertFrom-Yaml
    $kubeconfig2 = get-content $kubeconfig2Path | ConvertFrom-Yaml

    # Function to replace cluster, user, and context names with the file name, while keeping original server addresses
    function Set-NamesWithFileName {
        param (
            [hashtable]$kubeconfigData,
            [string]$newName
        )

        # Replace cluster names but keep the server addresses
        foreach ($cluster in $kubeconfigData.clusters) {
            if ($cluster.name -and $cluster.cluster.server) {
                $cluster.name = "$newName"
            }
        }

        # Replace user names
        foreach ($user in $kubeconfigData.users) {
            if ($user.name) {
                $user.name = "$newName"
            }
        }

        # Replace context names, but retain the correct mapping to cluster and user
        foreach ($context in $kubeconfigData.contexts) {
            if ($context.name -and $context.context.cluster -and $context.context.user) {
                $context.name = "$newName"
                $context.context.cluster = "$newName"
                $context.context.user = "$newName"
            }
        }

        return $kubeconfigData
    }

    # Apply renaming using file names
    $kubeconfig1 = Set-NamesWithFileName -kubeconfigData $kubeconfig1 -newName $suffix1
    $kubeconfig2 = Set-NamesWithFileName -kubeconfigData $kubeconfig2 -newName $suffix2

    # Merge the clusters, users, and contexts from both kubeconfigs
    $mergedClusters = $kubeconfig1.clusters + $kubeconfig2.clusters
    $mergedUsers = $kubeconfig1.users + $kubeconfig2.users
    $mergedContexts = $kubeconfig1.contexts + $kubeconfig2.contexts

    # Prepare the merged kubeconfig ensuring no empty or null fields
    $mergedKubeconfig = @{
        apiVersion        = $kubeconfig1.apiVersion
        kind              = $kubeconfig1.kind
        clusters          = $mergedClusters | Where-Object { $_.name -and $_.cluster.server }
        users             = $mergedUsers | Where-Object { $_.name }
        contexts          = $mergedContexts | Where-Object { $_.name -and $_.context.cluster -and $_.context.user }
        "current-context" = $kubeconfig1."current-context"  # Retain the current context of the first file
    }

    # Convert the merged data back to YAML and save to a new file
    $mergedKubeconfig | ConvertTo-Yaml | Set-Content -Path $mergedKubeconfigPath

    Write-Host "Kubeconfig files successfully merged into $mergedKubeconfigPath"
    kubectx seattle="ag-k3s-seattle"
    kubectx chicago="ag-k3s-chicago"

}

function Set-K3sClusters {
    Write-Host "Configuring kube-vip on K3s clusters"
    #az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId
    az login --identity
    az account set -s $subscriptionId
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        if ($cluster.Value.Type -eq "k3s") {
            $clusterName = $cluster.Value.FriendlyName.ToLower()
            $vmName = $cluster.Value.ArcClusterName + "-$namingGuid"
            kubectx $clusterName
            $k3sVIP = $(az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``true``].privateIPAddress" -otsv)
            Write-Host "Assigning kube-vip-role on k3s cluster"
            $kubeVipRbac = "$($Agconfig.AgDirectories.AgToolsDir)\kubeVipRbac.yml"
            kubectl apply -f $kubeVipRbac

            $kubeVipDaemonset = "$($Agconfig.AgDirectories.AgToolsDir)\kubeVipDaemon.yml"
            (Get-Content -Path $kubeVipDaemonset) -replace 'k3sVIPPlaceholder', "$k3sVIP" | Set-Content -Path $kubeVipDaemonset
            kubectl apply -f $kubeVipDaemonset

            Write-Host "Deploying Kube vip cloud controller on k3s cluster"
            kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

            $serviceIpRange = $(az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``false``].privateIPAddress" -otsv)
            $sortedIps = $serviceIpRange | Sort-Object { [System.Version]$_ }
            $lowestServiceIp = $sortedIps[0]
            $highestServiceIp = $sortedIps[-1]

            kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
            Start-Sleep -Seconds 30

            # Write-Host "Creating longhorn storage on K3scluster"
            # kubectl apply -f "$($Agconfig.AgDirectories.AgToolsDir)\longhorn.yaml"
            # Start-Sleep -Seconds 30
            # Write-Host "`n"
        }
    }
}

function Deploy-AIO-M3 {
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying AIO to the Arc-enabled clusters" -ForegroundColor Gray
    Write-Host "`n"

    # Get Event Hub details from the resource group to assign role permissions to IoT Operations extension managed
    $eventHubInfo = (az resource list --resource-group $resourceGroup --resource-type "Microsoft.EventHub/namespaces" | ConvertFrom-Json)
    if ($eventHubInfo.Count -ne 1) {
        Write-Host "ERROR: Resource group contains no Eventhub namespaces or more than one. Make sure to have only one EventHub namesapce in the resource group." -ForegroundColor DarkRed
        return
    }

    $eventHubNamespace =$eventHubInfo[0].name
    $eventHubNamespaceId = $eventHubInfo[0].id
    $evenHubNamespaceHost = "$($eventHubNamespace).servicebus.windows.net:9093"

    Write-Host "INFO: Found EventHub Namespace with Resource ID: $eventHubNamespaceId" -ForegroundColor DarkGray

    # Get Event Hub from the Event Hub namespace
    $eventHubs = az eventhubs eventhub list --namespace-name $eventHubInfo[0].name --resource-group $resourceGroup | ConvertFrom-Json
    $eventHubName = $eventHubs[0].name
    if (-not $eventHubName) {
        Write-Host "[$(Get-Date -Format t)] ERROR: Event Hub not found in the EventHub namespace $($eventHubInfo[0].name)" -ForegroundColor DarkRed
        return
    }

    # Download the bicep template
    $dataflowBicepTemplatePath = "$($AgConfig.AgDirectories.AgTempDir)\dataflows.bicep"
    Invoke-WebRequest ($templateBaseUrl + "contoso_hypermarket/bicep/data/dataflows.bicep") -OutFile $dataflowBicepTemplatePath
    if (-not (Test-Path -Path $dataflowBicepTemplatePath)) {
        Write-Host "[$(Get-Date -Format t)] ERROR: $dataflowBicepTemplatePath file not found." -ForegroundColor DarkRed
        return
    }

    $kvIndex = 0
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying AIO to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        # Create user-assigned identity for AIO secrets management
        Write-Host "Create user-assigned identity for AIO secrets management" -ForegroundColor DarkGray
        Write-Host "`n"
        $userAssignedManagedIdentityKvName = "aio-${clusterName}-${namingGuid}-kv-identity"
        $userAssignedMIKvResourceId = $(az identity create -g $resourceGroup -n $userAssignedManagedIdentityKvName -o tsv --query id)

        # Create user-assigned identity for AIO secrets management
        Write-Host "Create user-assigned identity for cloud connections" -ForegroundColor DarkGray
        Write-Host "`n"
        $userAssignedManagedIdentityCloudName = "aio-${clusterName}-${namingGuid}-cloud-identity"
        $userAssignedMICloudResourceId = $(az identity create -g $resourceGroup -n $userAssignedManagedIdentityCloudName -o tsv --query id)

        kubectx $clusterName
        $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
        $keyVaultId = (az keyvault list -g $resourceGroup --resource-type vault --query "[$kvIndex].id" -o tsv)
        $retryCount = 0
        $maxRetries = 5
        $aioStatus = "notDeployed"

        # Enable custom locations on the Arc-enabled cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Enabling custom locations on the Arc-enabled cluster" -ForegroundColor DarkGray
        Write-Host "`n"
        az config set extension.use_dynamic_install=yes_without_prompt
        az connectedk8s enable-features --name $arcClusterName `
            --resource-group $resourceGroup `
            --features cluster-connect custom-locations `
            --custom-locations-oid $customLocationRPOID `
            --only-show-errors

        # Create the Schema registry for the cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Creating the schema registry on the Arc-enabled cluster" -ForegroundColor DarkGray
        Write-Host "`n"
        $schemaName = "${clusterName}-$($Env:namingGuid)-schema"
        $schemaId = $(az iot ops schema registry create --name $schemaName `
                --resource-group $Env:resourceGroup `
                --registry-namespace "$clusterName-$($Env:namingGuid)-namespace" `
                --sa-resource-id $(az storage account show --name $Env:aioStorageAccountName --resource-group $Env:resourceGroup -o tsv --query id) `
                --query id -o tsv)

        Write-Host "[$(Get-Date -Format t)] INFO: The aio storage account name is: $aioStorageAccountName" -ForegroundColor DarkGray
        Write-Host "[$(Get-Date -Format t)] INFO: the schemaId is '$schemaId' - verify this" -ForegroundColor DarkGray

        $customLocationName = $arcClusterName.toLower() + "-cl"

        # Initialize the Azure IoT Operations instance on the Arc-enabled cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Initialize the Azure IoT Operations instance on the Arc-enabled cluster" -ForegroundColor DarkGray
        Write-Host "`n"
        do {
            az iot ops init --cluster $arcClusterName.toLower() `
                --resource-group $resourceGroup `
                --subscription $subscriptionId `
                --only-show-errors
            if ($? -eq $false) {
                $aioStatus = "notDeployed"
                Write-Host "`n"
                Write-Host "[$(Get-Date -Format t)] Error: An error occured while deploying AIO on the cluster...Retrying" -ForegroundColor DarkRed
                Write-Host "`n"
                az iot ops init --cluster $arcClusterName.toLower() `
                    --resource-group $Env:resourceGroup `
                    --subscription $Env:subscriptionId `
                    --only-show-errors
                $retryCount++
            }
            else {
                $aioStatus = "deployed"
            }
        } until ($aioStatus -eq "deployed" -or $retryCount -eq $maxRetries)

        $retryCount = 0
        $maxRetries = 5
        # Create the Azure IoT Operations instance on the Arc-enabled cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Create the Azure IoT Operations instance on the Arc-enabled cluster" -ForegroundColor DarkGray
        Write-Host "`n"
        do {
            az iot ops create --name $arcClusterName.toLower() `
                --cluster $arcClusterName.toLower() `
                --resource-group $Env:resourceGroup `
                --subscription $Env:subscriptionId `
                --custom-location $customLocationName `
                --sr-resource-id $schemaId `
                --enable-rsync true `
                --add-insecure-listener true `
                --only-show-errors

            if ($? -eq $false) {
                $aioStatus = "notDeployed"
                Write-Host "`n"
                Write-Host "[$(Get-Date -Format t)] Error: An error occured while deploying AIO on the cluster...Retrying" -ForegroundColor DarkRed
                Write-Host "`n"
                az iot ops create --name $arcClusterName.toLower() `
                    --cluster $arcClusterName.toLower() `
                    --resource-group $resourceGroup `
                    --subscription $subscriptionId `
                    --custom-location $customLocationName `
                    --sr-resource-id $schemaId `
                    --enable-rsync true `
                    --add-insecure-listener true `
                    --only-show-errors

                $retryCount++
            }
            else {
                $aioStatus = "deployed"
            }
        } until ($aioStatus -eq "deployed" -or $retryCount -eq $maxRetries)

        # Configure the Azure IoT Operations instance for secret synchronization
        Write-Host "[$(Get-Date -Format t)] INFO: Configuring the Azure IoT Operations instance for secret synchronization" -ForegroundColor DarkGray
        Write-Host "`n"

        # Enable OIDC issuer and workload identity on the Arc-enabled cluster
        az connectedk8s update -n $arcClusterName `
            --resource-group $resourceGroup `
            --enable-oidc-issuer `
            --enable-workload-identity

        Write-Host "[$(Get-Date -Format t)] INFO: Assigning the user-assigned managed identity to the Azure IoT Operations instance" -ForegroundColor DarkGray
        Write-Host "`n"
        az iot ops identity assign --name $arcClusterName.toLower() `
            --resource-group $resourceGroup `
            --mi-user-assigned $userAssignedMIKvResourceId

        Start-Sleep -Seconds 60

        Write-Host "[$(Get-Date -Format t)] INFO: Configure the Azure IoT Operations instance for secret synchronization" -ForegroundColor DarkGray
        Write-Host "`n"

        az iot ops secretsync enable --instance $arcClusterName.toLower() `
            --kv-resource-id $keyVaultId `
            --resource-group $resourceGroup `
            --mi-user-assigned $userAssignedMICloudResourceId `
            --only-show-errors

        $kvIndex++

        # Get IoT Operations extension pricipalId
        Write-Host "[$(Get-Date -Format t)] INFO: Retrieving IoT Operations extension principalId" -ForegroundColor DarkGray
        $iotExtensionPrincipalId = (az k8s-extension list --resource-group $resourceGroup --cluster-name $arcClusterName --cluster-type connectedClusters --query "[?extensionType=='microsoft.iotoperations'].identity.principalId" -o tsv)
        Write-Host "[$(Get-Date -Format t)] INFO: IoT Operations extension principalId is $iotExtensionPrincipalId" -ForegroundColor DarkGray

        # Assign "Azure Event Hubs Data Sender" role to IoT managed identity
        Write-Host "[$(Get-Date -Format t)] INFO: Assigning 'Azure Event Hubs Data Sender role' to '$iotExtensionPrincipalId' to EventHub namespace" -ForegroundColor DarkGray
        az role assignment create --assignee-object-id $iotExtensionPrincipalId --role "Azure Event Hubs Data Sender" --scope $eventHubNamespaceId --assignee-principal-type ServicePrincipal --only-show-errors

        # Deploy IoT DataFlows using bicep template
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying IoT DataFlows using bicep template" -ForegroundColor DarkGray
        $deploymentName = "$arcClusterName" + "-iot-dataflow"
        $iotInstanceName = $arcClusterName.toLower()

        Write-Host "[$(Get-Date -Format t)] INFO:  az deployment group create --name $deploymentName  --resource-group $resourceGroup --template-file $dataflowBicepTemplatePath --parameters aioInstanceName=$iotInstanceName evenHubNamespaceHost=$evenHubNamespaceHost eventHubName=$eventHubName customLocationName=$customLocationName"
        az deployment group create --name $deploymentName  --resource-group $resourceGroup --template-file $dataflowBicepTemplatePath `
            --parameters aioInstanceName=$iotInstanceName evenHubNamespaceHost=$evenHubNamespaceHost eventHubName=$eventHubName `
            customLocationName=$customLocationName

        # Verify the deployment status
        $deploymentStatus = az deployment group show --name $deploymentName --resource-group $resourceGroup --query properties.provisioningState -o tsv
        if ($deploymentStatus -eq "Succeeded") {
            Write-Host "[$(Get-Date -Format t)] INFO: Deployment succeeded for $deploymentName" -ForegroundColor Green
        }
        else {
            Write-Host "[$(Get-Date -Format t)] ERROR: Deployment failed for $deploymentName" -ForegroundColor Red
        }
    }
}

function Set-MicrosoftFabric {

    # Load Agconfig
    $fabricWorkspacePrefix = $AgConfig.FabricConfig["WorkspacePrefix"]
    $fabricWorkspaceName = "$fabricWorkspacePrefix-$namingGuid"
    $fabricFolder = $AgConfig.AgDirectories["AgFabric"]
    $runFabricSetupAs = $AgConfig.FabricConfig["RunFabricSetupAs"]
    $fabricConfigFile = "$fabricFolder\fabric-config.json"
    $eventHubKeyName = $AgConfig.FabricConfig["EventHubSharedAccessKeyName"]

    Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Fabric workspace configuration file $fabricConfigFile" -ForegroundColor DarkGray

    # Get Fabric capacity name from the resource group
    $fabricCapacityName = (az fabric capacity list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $fabricCapacityName) {
        Write-Host "[$(Get-Date -Format t)] WARNING: Fabric capacity not found in the resource group $Env:resourceGroup. Make sure either you have Fabric Capacity or other Fabric license to create Farbric worspace." -ForegroundColor Yellow
    }
    else {
        Write-Host "[$(Get-Date -Format t)] INFO: Found fabric capacity '$fabricCapacityName' in the resource group $Env:resourceGroup." -ForegroundColor DarkGray
    }

    # Get EventHub namespace created in the resource group
    $eventHubNamespace = (az eventhubs namespace list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $eventHubNamespace) {
        Write-Error "$(Get-Date -Format t)] INFO: EventHub namespaces not found in the resource group $Env:resourceGroup" -ForegroundColor DarkRed
        return
    }

    # Get Event Hub from the Event Hub namespace
    $eventHubs = az eventhubs eventhub list --namespace-name $eventHubNamespace --resource-group $resourceGroup | ConvertFrom-Json
    $eventHubName = $eventHubs[0].name
    if (-not $eventHubName) {
        Write-Host "[$(Get-Date -Format t)] ERROR: Event Hub not found in the EventHub namespace $eventHubNamespace" -ForegroundColor DarkRed
        return
    }

    # Get Event Hub credentials
    Write-Host "INFO: Retrieving Event Hub key for '$eventHubKeyName' Shared Acess Policy."
    $eventHubKeyName = $AgConfig.FabricConfig["EventHubSharedAccessKeyName"]
    $eventHubKey = az eventhubs namespace authorization-rule keys list --resource-group $resourceGroup --namespace-name $eventHubNamespace --name $eventHubKeyName --query primaryKey --output tsv
    if ($eventHubKey -eq '') {
        Write-Host "$(Get-Date -Format t)] ERROR: Failed to retrieve Event Hub key." -ForegroundColor DarkRed
        return
    }

    Write-Host "$(Get-Date -Format t)] INFO: Received Event Hub key." -ForegroundColor DarkGray

    # Store EventHub key in the environment variable to use in Farbic setup script
    [System.Environment]::SetEnvironmentVariable('eventHubPrimaryKey', $eventHubKey, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('eventHubNamespace', $eventHubNamespace, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('eventHubName', $eventHubName, [System.EnvironmentVariableTarget]::Machine)

    $configJson = @"
    {
        "tenantID": "$Env:tenantId",
        "subscriptionID": "$Env:subscriptionId",
        "runAs": "$runFabricSetupAs",
        "azureLocation": "$Env:azureLocation",
        "resourceGroup": "$Env:resourceGroup",
        "fabricCapacityName": "$fabricCapacityName",
        "templateBaseUrl": "$Env:templateBaseUrl",
        "fabricWorkspaceName": "$fabricWorkspaceName",
        "eventHubNamespace": "$eventHubNamespace",
        "eventHubName": "$eventHubName",
        "eventHubKeyName": "$eventHubKeyName",
        "eventHubPrimaryKey": "$eventHubKey"
    }
"@

    $configJson | Set-Content -Path $fabricConfigFile
    Write-Host "$(Get-Date -Format t)] INFO: Fabric config file $fabricConfigFile created"

    # Download Fabric workspace setup script from GitHuB
    $fabricSetupScriptFile = "SetupFabricWorkspace.ps1"
    $sriptFileUrl = $templateBaseUrl + "artifacts/PowerShell/$fabricSetupScriptFile"
    Write-Host "$(Get-Date -Format t)] INFO: Downloading script file from $sriptFileUrl"

    $scriptFilePath = "$fabricFolder\$fabricSetupScriptFile"
    Invoke-WebRequest ($sriptFileUrl) -OutFile $scriptFilePath
    if (-not (Test-Path -Path $scriptFilePath)) {
        Write-Host "[$(Get-Date -Format t)] ERROR: Unable to download script file from $sriptFileUrl" -ForegroundColor DarkRed
    }
    Write-Host "$(Get-Date -Format t)] INFO: Downloaded script file $scriptFilePath"
}

function Deploy-HypermarketConfigs {
    # Loop through the clusters and deploy the configs in AppConfig hashtable in AgConfig-contoso-hypermarket.psd
    Write-Host "INFO: Cloning the GitHub repository locally to get helm chart" -ForegroundColor Gray
    git clone "https://github.com/Azure/jumpstart-apps.git"

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        kubectx $clusterName
        helm dependency build ".\jumpstart-apps\agora\contoso_hypermarket\charts\contoso-hypermarket" --namespace contoso-hypermarket
        helm install contoso-hypermarket ".\jumpstart-apps\agora\contoso_hypermarket\charts\contoso-hypermarket" --create-namespace --namespace contoso-hypermarket
    }
}

# function Deploy-HypermarketConfigs {

#     # Loop through the clusters and deploy the configs in AppConfig hashtable in AgConfig-contoso-hypermarket.psd
#     foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
#         Start-Job -Name gitops -ScriptBlock {
#             $AgConfig = $using:AgConfig
#             $cluster = $using:cluster
#             $namingGuid = $using:namingGuid
#             $resourceGroup = $using:resourceGroup
#             $appClonedRepo = $using:appUpstreamRepo
#             $appsRepo = $using:appsRepo

#             $AgConfig.AppConfig.GetEnumerator() | sort-object -Property @{Expression = { $_.value.Order }; Ascending = $true } | ForEach-Object {
#                 $app = $_
#                 $clusterName = $cluster.value.ArcClusterName + "-$namingGuid"
#                 $branch = $cluster.value.Branch.ToLower()
#                 $configName = $app.value.GitOpsConfigName.ToLower()
#                 $namespace = $app.value.Namespace
#                 $appName = $app.Value.KustomizationName
#                 $appPath = $app.Value.KustomizationPath
#                 $retryCount = 0
#                 $maxRetries = 2

#                 Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $($cluster.Value.ArcClusterName+"-$namingGuid")" -ForegroundColor Gray
#                 $type = "connectedClusters"

#                 az k8s-configuration flux create `
#                     --cluster-name $clusterName `
#                     --resource-group $resourceGroup `
#                     --name $configName `
#                     --cluster-type $type `
#                     --scope cluster `
#                     --url $appClonedRepo `
#                     --branch $branch `
#                     --sync-interval 3s `
#                     --kustomization name=$appName path=$appPath prune=true retry_interval=1m `
#                     --timeout 10m `
#                     --namespace $namespace `
#                     --only-show-errors `
#                     2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

#                 do {
#                     $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json 2>$null) | convertFrom-JSON
#                     if ($configStatus.ComplianceState -eq "Compliant") {
#                         Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration $configName is ready on $clusterName" -ForegroundColor DarkGreen | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
#                     }
#                     else {
#                         if ($configStatus.ComplianceState -ne "Non-compliant") {
#                             Start-Sleep -Seconds 20
#                         }
#                         elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
#                             Start-Sleep -Seconds 20
#                             $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json 2>$null) | convertFrom-JSON
#                             if ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
#                                 $retryCount++
#                                 Write-Host "[$(Get-Date -Format t)] INFO: Attempting to re-install $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
#                                 Write-Host "[$(Get-Date -Format t)] INFO: Deleting $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
#                                 az k8s-configuration flux delete `
#                                     --resource-group $resourceGroup `
#                                     --cluster-name $clusterName `
#                                     --cluster-type $type `
#                                     --name $configName `
#                                     --force `
#                                     --yes `
#                                     --only-show-errors `
#                                     2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

#                                 Start-Sleep -Seconds 10
#                                 Write-Host "[$(Get-Date -Format t)] INFO: Re-creating $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

#                                 az k8s-configuration flux create `
#                                     --cluster-name $clusterName `
#                                     --resource-group $resourceGroup `
#                                     --name $configName `
#                                     --cluster-type $type `
#                                     --scope cluster `
#                                     --url $appClonedRepo `
#                                     --branch $branch `
#                                     --sync-interval 3s `
#                                     --kustomization name=$appName path=$appPath prune=true `
#                                     --timeout 30m `
#                                     --namespace $namespace `
#                                     --only-show-errors `
#                                     2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
#                             }
#                         }
#                         elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -eq $maxRetries) {
#                             Write-Host "[$(Get-Date -Format t)] ERROR: GitOps configuration $configName has failed on $clusterName. Exiting..." -ForegroundColor White -BackgroundColor Red | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
#                             break
#                         }
#                     }
#                 } until ($configStatus.ComplianceState -eq "Compliant")
#             }
#         }
#     }
#     while ($(Get-Job -Name gitops).State -eq 'Running') {
#         Write-Host "[$(Get-Date -Format t)] INFO: Waiting for GitOps configuration to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
#         Receive-Job -Name gitops -WarningAction SilentlyContinue
#         Start-Sleep -Seconds 60
#     }

#     Get-Job -name gitops | Remove-Job
#     Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
#     Write-Host
# }

function Set-AIServiceSecrets {
    $location = $global:azureLocation
    $azureOpenAIModelName = ($Env:azureOpenAIModel | ConvertFrom-Json).name
    $azureOpenAIApiVersion = ($Env:azureOpenAIModel | ConvertFrom-Json).apiVersion
    $AIServiceAccountName = $(az cognitiveservices account list -g $resourceGroup --query [].name -o tsv)
    $AIServicesEndpoints = $(az cognitiveservices account show --name $AIServiceAccountName --resource-group $resourceGroup --query properties.endpoints) | ConvertFrom-Json -AsHashtable
    $speechToTextEndpoint = $AIServicesEndpoints['Speech Services Speech to Text (Standard)']
    $openAIEndpoint = $AIServicesEndpoints['OpenAI Language Model Instance API']
    $AIServicesKey = $(az cognitiveservices account keys list --name $AIServiceAccountName  --resource-group $resourceGroup --query key1 -o tsv)

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying AI services Secret to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        kubectx $clusterName
        kubectl create secret generic azure-openai-secret `
            --namespace=contoso-hypermarket `
            --from-literal=azure-openai-endpoint=$openAIEndpoint `
            --from-literal=azure-openai-key=$AIServicesKey `
            --from-literal=azure-speech-to-text-endpoint=$speechToTextEndpoint `
            --from-literal=region=$location `
            --from-literal=azure-openai-model-name=$azureOpenAIModelName `
            --from-literal=azure-openai-deployment-name=$openAIDeploymentName `
            --from-literal=azure-openai-api-version=$azureOpenAIApiVersion
    }
}

function Set-EventHubSecrets {
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying EventHub Secret to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        $eventHubNamespace = $(az eventhubs namespace list -g $resourceGroup --query [].name -o tsv)
        $eventHubName = $(az eventhubs eventhub list -g $resourceGroup --namespace-name $eventHubNamespace --query [].name -o tsv)
        $eventHubConnectionString = $(az eventhubs eventhub authorization-rule keys list --resource-group $resourceGroup --namespace-name $eventHubNamespace --eventhub-name $eventHubName --name RootManageSharedAccessKey --query primaryConnectionString -o tsv)
        kubectx $clusterName
        kubectl create secret generic azure-eventhub-secret `
            --namespace=contoso-hypermarket `
            --from-literal=azure-eventhub-connection-string=$eventHubConnectionString
    }
}

function Set-SQLSecret {
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying SQL Secret to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        $decodeAdminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
        kubectx $clusterName
        kubectl create secret generic azure-sqlpassword-secret `
            --namespace=contoso-hypermarket `
            --from-literal=azure-sqlpassword-secret=$decodeAdminPassword
    }
}

function Set-LoadBalancerBackendPools {
    $vnetResourceId = $(az network vnet list -g $resourceGroup --query [].id -o tsv)
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        $loadBalancerName = "Ag-LoadBalancer-${clusterName}"
        $loadBalancerPublicIp = "Ag-LB-Frontend-${clusterName}"
        kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")
        $services = kubectl get services -n contoso-hypermarket -o json | ConvertFrom-Json
        $services.items | ForEach-Object {
            $service = $_
            $serviceName = $service.metadata.name
            $servicePorts = $service.spec.ports.port
            $serviceIp = $service.status.loadBalancer.ingress.ip

            if($serviceName -eq "influxdb"){
                $servicePort = $servicePorts[1]
            }else{
                $servicePort = $servicePorts[0]
            }

            if ($null -ne $serviceIp) {
                Write-Host "[$(Get-Date -Format t)] Creating backend pool for service: $serviceName" -ForegroundColor Gray
                Write-Host "`n"

                az network lb address-pool create -g $resourceGroup `
                    --lb-name $loadBalancerName `
                    --name "$serviceName-pool" `
                    --vnet $vnetResourceId `
                    --backend-addresses "[{name:${serviceName},ip-address:${serviceIp}}]" `
                    --only-show-errors | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\loadBalancer.log")

                Write-Host "[$(Get-Date -Format t)] Creating inbound NAT rule for service: $serviceName" -ForegroundColor Gray
                Write-Host "`n"
                az network lb inbound-nat-rule create -g $resourceGroup `
                    --lb-name $loadBalancerName `
                    --name "$serviceName-NATRule" `
                    --protocol Tcp `
                    --frontend-port-range-start $servicePort `
                    --frontend-port-range-end $servicePort `
                    --frontend-ip $loadBalancerPublicIp `
                    --backend-address-pool "$serviceName-pool" `
                    --backend-port $servicePort `
                    --only-show-errors | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\loadBalancer.log")
            }
        }

        # Grafana backend pool creation
        $clientVMName = "Ag-VM-Client"
        $serviceName = "Grafana"
        $servicePort = "3000"
        $clientVMIpAddress = $(az vm list-ip-addresses --name $clientVMName `
        --resource-group $resourceGroup `
        --query "[].virtualMachine.network.privateIpAddresses[0]" `
        --output tsv `
        --only-show-errors)

        Write-Host "[$(Get-Date -Format t)] Creating inbound NAT rule for service: $serviceName" -ForegroundColor Gray
        Write-Host "`n"

        az network lb address-pool create -g $resourceGroup `
            --lb-name $loadBalancerName `
            --name "$serviceName-pool" `
            --vnet $vnetResourceId `
            --backend-addresses "[{name:Grafana,ip-address:${clientVMIpAddress}}]" `
            --only-show-errors | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\loadBalancer.log")

        Write-Host "[$(Get-Date -Format t)] Creating inbound NAT rule for service: $serviceName" -ForegroundColor Gray
        Write-Host "`n"

        az network lb inbound-nat-rule create -g $resourceGroup `
            --lb-name $loadBalancerName `
            --name "$serviceName-NATRule" `
            --protocol Tcp `
            --frontend-port-range-start $servicePort `
            --frontend-port-range-end $servicePort `
            --frontend-ip $loadBalancerPublicIp `
            --backend-address-pool "$serviceName-pool" `
            --backend-port $servicePort `
            --only-show-errors | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\loadBalancer.log")

        Write-Host "[$(Get-Date -Format t)] Creating outbound rule for service: $serviceName" -ForegroundColor Gray
        Write-Host "`n"

        az network lb outbound-rule create --address-pool "$serviceName-pool"`
            --lb-name $loadBalancerName `
            --name "Grafana-outbound" `
            --outbound-ports 10000 `
            --protocol All `
            --frontend-ip-configs $loadBalancerPublicIp `
            --resource-group $resourceGroup `
            --only-show-errors | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\loadBalancer.log")
    }

}

function Set-ACSA {
    # Begin ACSA Installation.
    # Documentation: https://aepreviews.ms/docs/edge-storage-accelerator/how-to-install-edge-storage-accelerator/

    # Ensure necessary variables are available
    $storageAccountName = $global:aioStorageAccountName     # Using $global:aioStorageAccountName
    $storageContainer = "shopper-videos"                     # Container name set to "shoppervideos"
    $resourceGroup = $global:resourceGroup
    $arcClusterName = $global:k3sArcClusterName
    $subscriptionId = $global:subscriptionId

    # Create a storage account
    Write-Host "Storage Account Name: $storageAccountName"
    Write-Host "Container Name: $storageContainer"

    # Create a container within the storage account
    Write-Host "Creating container within the storage account..."
    az storage container create `
        --name "$storageContainer" `
        --account-name "$storageAccountName" `
        --auth-mode login

    # Assign necessary role to the extension principal
    $principalID = $(az k8s-extension list `
        --cluster-name $arcClusterName `
        --resource-group $resourceGroup `
        --cluster-type connectedClusters `
        --query "[?extensionType=='microsoft.arc.containerstorage'].identity.principalId | [0]" -o tsv)

    az role assignment create `
        --assignee-object-id $principalID `
        --assignee-principal-type ServicePrincipal `
        --role "Storage Blob Data Owner" `
        --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

    # Deploy the ACSA application #NEED TO BE CHANGED
    $acsadeployYamlUrl = "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_edge_iot_ops_jumpstart/acsa_fault_detection/yaml/acsa-edge-sub-volume.yaml"
    $acsadeployYamlPath = "acsa-edge-sub-volume.yaml"
    Invoke-WebRequest -Uri $acsadeployYamlUrl -OutFile $acsadeployYamlPath

    # Replace {STORAGEACCOUNT} with the actual storage account name
    (Get-Content $acsadeployYamlPath) -replace '{STORAGEACCOUNT}', $storageAccountName | Set-Content $acsadeployYamlPath

    # Apply the acsa-deploy.yaml file using kubectl
    Write-Host "Applying acsa-deploy.yaml configuration..."
    kubectl apply -f $acsadeployYamlPath
    Write-Host "acsa-deploy.yaml configuration applied successfully."
}

function Deploy-HypermarketBookmarks {
    $bookmarksFileName = "$AgToolsDir\Bookmarks"
    $edgeBookmarksPath = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

        $publicIPAddress = $(az network public-ip show --resource-group $resourceGroup --name "Ag-LB-Public-IP-$clusterName" --query "ipAddress" --output tsv)
        $services = kubectl get services -n contoso-hypermarket -o json | ConvertFrom-Json

        # Matching url: backend-api
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'backend-api' -and
            $_.spec.ports.port -contains 5002
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:5002/docs"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("backend-api-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: cerebral-api-service
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'cerebral-api-service' -and
            $_.spec.ports.port -contains 5003
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:5003"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("cerebral-api-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: cerebral-simulator-service
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'cerebral-simulator-service' -and
            $_.spec.ports.port -contains 8001
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:8001/apidocs"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("cerebral-simulator-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: footfall-ai-api
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'footfall-ai-api' -and
            $_.spec.ports.port -contains 5000
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:5000"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("footfall-ai-api-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: main-ui
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'main-ui' -and
            $_.spec.ports.port -contains 8080
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:8080/"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("main-ui-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: InfluxDB
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'InfluxDB' -and
            $_.spec.ports.port -contains 8086
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:8086"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("InfluxDB-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: Shopper Insights API
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'shopper-insights-api' -and
            $_.spec.ports.port -contains 5001
        }
        $backendApiIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($backendApiIp in $backendApiIps) {
            $output = "http://${publicIPAddress}:5001"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Shopper-Insights-API-" + $clusterName + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName
            Start-Sleep -Seconds 2
        }

        # Matching url: Grafana
        # Replace matching value in the Bookmarks file
        $output = "http://${publicIPAddress}:3000"
        $content = Get-Content -Path $bookmarksFileName
        $newContent = $content -replace ("Grafana-URL"), $output
        $newContent | Set-Content -Path $bookmarksFileName
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 2

    Copy-Item -Path $bookmarksFileName -Destination $edgeBookmarksPath -Force

    ##############################################################
    # Pinning important directories to Quick access
    ##############################################################
    Write-Host "[$(Get-Date -Format t)] INFO: Pinning important directories to Quick access (Step 16/17)" -ForegroundColor DarkGreen
    $quickAccess = new-object -com shell.application
    $quickAccess.Namespace($AgConfig.AgDirectories.AgDir).Self.InvokeVerb("pintohome")
    $quickAccess.Namespace($AgConfig.AgDirectories.AgLogsDir).Self.InvokeVerb("pintohome")
}

function Set-GPU-Operator {
    Write-Host "Starting GPU Operator installation..." -ForegroundColor Gray

    # Add the NVIDIA Helm repository
    Write-Host "Adding NVIDIA Helm repository..." -ForegroundColor Gray
    helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
    helm repo update

    # Loop through each cluster and install the GPU operator
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "Switching context to cluster: $clusterName" -ForegroundColor Gray
        kubectx $clusterName

        # Create the namespace for the GPU operator
        Write-Host "Creating GPU operator namespace in $clusterName..." -ForegroundColor Gray
        kubectl create namespace gpu-operator -o yaml --dry-run=client | kubectl apply -f -

        # Apply the time-slicing configuration YAML
        Write-Host "Applying time-slicing configuration to $clusterName..." -ForegroundColor Gray
        kubectl apply -f "jumpstart-apps/agora/contoso_hypermarket/charts/gpu-operator/time-slicing-config.yaml" -n gpu-operator

        # Install the GPU operator using Helm
        Write-Host "Installing GPU operator in $clusterName..." -ForegroundColor Gray
        helm install --wait --generate-name `
            -n gpu-operator `
            nvidia/gpu-operator `
            --create-namespace `
            --values jumpstart-apps\agora\contoso_hypermarket\charts\gpu-operator\values.yaml

        Write-Host "GPU operator installation completed on $clusterName." -ForegroundColor Green
    }

    Write-Host "GPU operator installation completed successfully on all clusters." -ForegroundColor Green
}

# Function to set the Azure Data Studio connections
function Set-AzureDataStudioConnections {
    param (
        [PSCustomObject[]]$dbConnections
    )

    # Creating endpoints file
    Write-Host "`n"
    Write-Header "Creating SQL Server connections in Azure Data Studio "
    Write-Host "`n"

    $settingsContent = @"
{
    "workbench.enablePreviewFeatures": true,
    "datasource.connectionGroups": [
        {
            "name": "ROOT",
            "id": "C777F06B-202E-4480-B475-FA416154D458"
        }
    ],
    "datasource.connections": [
    {{DB_CONNECTION_LIST}}
    ],
    "window.zoomLevel": 2
}
"@ 
    
    $dbConnectionsJson = ""
    $index = 0
    foreach($connection in $dbConnections) {
        $dagConnection = @"
{
    "options": {
        "connectionName": "$($connection.sitename)",
        "server": "$($connection.server)",
        "database": "",
        "authenticationType": "SqlLogin",
        "user": "$($connection.username)",
        "password": "$($connection.password)",
        "applicationName": "azdata",
        "groupId": "C777F06B-202E-4480-B475-FA416154D458",
        "databaseDisplayName": "",
        "trustServerCertificate": true
      },
      "groupId": "C777F06B-202E-4480-B475-FA416154D458",
      "providerName": "MSSQL",
      "savePassword": true,
      "id": "ac333479-a04b-436b-88ab-3b314a201295"
}
"@
        $dbConnectionsJson += $dagConnection

        if ($index -lt $dbConnections.Count - 1) {
            $dbConnectionsJson += ",`n"
        }
        else {
            $dbConnectionsJson += "`n"
        }
        $index += 1
    }

    $settingsContent = $settingsContent -replace '{{DB_CONNECTION_LIST}}', $dbConnectionsJson

    $settingsFilePath = "$Env:APPDATA\azuredatastudio\User\settings.json"

    # Verify file path and create new one if not found
    if (-not (Test-Path -Path $settingsFilePath)){
        New-Item -ItemType File -Path $settingsFilePath -Force
    }

    $settingsContent | Set-Content -Path $settingsFilePath
}

# Function to set the SQL Server connections file and Azure Data Studio connections shortcuts
function Set-DatabaseConnectionsShortcuts {
    # Creating endpoints file
    Write-Host "`n"
    Write-Header "Creating Database Endpoints file Desktop shortcut"
    Write-Host "`n"

    $filename = "DatabaseConnectionEndpoints.txt"
    $file = New-Item -Path $AgConfig.AgDirectories.AgDir -Name $filename -ItemType "file" -Force
    $Endpoints = $file.FullName
    Add-Content $Endpoints "======================================================================"
    Add-Content $Endpoints ""

    $dbConnections = @()

    # Get SQL server service IP and the port
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        kubectx $clusterName

        # Get Loadbalancer IP and target port
        $sqlService = kubectl get service mssql-service -n contoso-hypermarket -o json | ConvertFrom-Json
        $endPoint = "$($sqlService.spec.loadBalancerIP),$($sqlService.spec.ports.targetPort)"
        Add-Content $Endpoints "SQL Server external endpoint for $clusterName cluster:"
        $endPoint | Add-Content $Endpoints

        # Get SQL server username and password
        $secret = kubectl get secret azure-sqlpassword-secret -n contoso-hypermarket -o json | ConvertFrom-Json
        $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret.data.'azure-sqlpassword-secret'))
        Add-Content $Endpoints "Username: SA, Password: $password"
        Add-Content $Endpoints ""
        Add-Content $Endpoints ""

        $siteName = [cultureinfo]::GetCultureInfo("en-US").TextInfo.ToTitleCase($clusterName)
        $dbConnectionInfo = @{
            sitename = "$siteName"
            server = "$endPoint"
            username="SA"
            password = "$password"
        }

        # Add to the connection list
        $dbConnections += $dbConnectionInfo
    }

    Add-Content $Endpoints "======================================================================"
    Add-Content $Endpoints ""

    $TargetFile = $Endpoints
    $ShortcutFile = "C:\Users\$env:adminUsername\Desktop\SQL Server Endpoints.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()

    # Create Azure Data Studio connection
    Set-AzureDataStudioConnections -dbConnections $dbConnections
}
