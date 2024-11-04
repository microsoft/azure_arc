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

    $eventHubNamespaceId = $eventHubInfo[0].id
    $evenHubNamespaceHost = "$($eventHubInfo[0].name).servicebus.windows.net:9093"

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
                --resource-group $resourceGroup `
                --registry-namespace "$clusterName-$($Env:namingGuid)-namespace" `
                --sa-resource-id $(az storage account show --name $aioStorageAccountName --resource-group $resourceGroup -o tsv --query id) `
                --query id -o tsv)

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
                    --resource-group $resourceGroup `
                    --subscription $subscriptionId `
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
                --resource-group $resourceGroup `
                --subscription $subscriptionId `
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

        az iot ops secretsync enable --name $arcClusterName.toLower() `
            --kv-resource-id $keyVaultId `
            --resource-group $resourceGroup `
            --mi-user-assigned $userAssignedMICloudResourceId `
            --only-show-errors

        $kvIndex++

        # Get IoT Operations extension pricipalId
        Write-Host "[$(Get-Date -Format t)] INFO: Retrieving IoT Operations extension principalId" -ForegroundColor DarkGray
        $iotExtensionPrincipalId = (az k8s-extension list --resource-group $resourceGroup --cluster-name $arcClusterName --cluster-type connectedClusters --query "[?extensionType=='microsoft.iotoperations'].identity.principalId" -o tsv)

        # Assign "Azure Event Hubs Data Sender" role to IoT managed identity
        Write-Host "[$(Get-Date -Format t)] INFO: Assigning 'Azure Event Hubs Data Sender role' to EventHub namespace" -ForegroundColor DarkGray
        az role assignment create --assignee $iotExtensionPrincipalId --role "Azure Event Hubs Data Sender" --scope $eventHubNamespaceId

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

    # Get Fabric capacity name from the resource group
    $fabricCapacityName = (az fabric capacity list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $fabricCapacityName) {
        Write-Error "Fabric capacity not found in the resource group $Env:resourceGroup"
        return
    }

    # Get EventHub namespace created in the resource group
    $eventHubNS = (az eventhubs namespace list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $eventHubNS) {
        Write-Error "EventHub namespaces not found in the resource group $Env:resourceGroup"
        return
    }

    # Get EventHub name from the eventhub namespace created in the resource group
    $eventHubName = (az eventhubs eventhub list --namespace $eventHubNS --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $eventHubName) {
        Write-Error "No Event Hub created in the EventHub namespace $eventHubNS"
        return
    }

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
        "eventHubKeyName": "$eventHubKeyName"
    }
"@

    $configJson | Set-Content -Path $fabricConfigFile
    Write-Host "Fabric config file created at $fabricConfigFile"

    # Download Fabric workspace setup script from GitHuB
    $scriptFilePath = "$fabricFolder\SetupFabricWorkspace.ps1"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/SetupFabricWorkspace.ps1") -OutFile $scriptFilePath
    if (-not (Test-Path -Path $scriptFilePath)) {
        Write-Error "Unable to download script file: 'SetupFabricWorkspace.ps1' from GitHub"
    }
}

function Deploy-HypermarketConfigs {

    # Loop through the clusters and deploy the configs in AppConfig hashtable in AgConfig-contoso-hypermarket.psd
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        Start-Job -Name gitops -ScriptBlock {
            $AgConfig = $using:AgConfig
            $cluster = $using:cluster
            $namingGuid = $using:namingGuid
            $resourceGroup = $using:resourceGroup
            $appClonedRepo = $using:appUpstreamRepo
            $appsRepo = $using:appsRepo

            $AgConfig.AppConfig.GetEnumerator() | sort-object -Property @{Expression = { $_.value.Order }; Ascending = $true } | ForEach-Object {
                $app = $_
                $clusterName = $cluster.value.ArcClusterName + "-$namingGuid"
                $branch = $cluster.value.Branch.ToLower()
                $configName = $app.value.GitOpsConfigName.ToLower()
                $namespace = $app.value.Namespace
                $appName = $app.Value.KustomizationName
                $appPath = $app.Value.KustomizationPath
                $retryCount = 0
                $maxRetries = 2

                Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $($cluster.Value.ArcClusterName+"-$namingGuid")" -ForegroundColor Gray
                $type = "connectedClusters"

                az k8s-configuration flux create `
                    --cluster-name $clusterName `
                    --resource-group $resourceGroup `
                    --name $configName `
                    --cluster-type $type `
                    --scope cluster `
                    --url $appClonedRepo `
                    --branch $branch `
                    --sync-interval 3s `
                    --kustomization name=$appName path=$appPath prune=true retry_interval=1m `
                    --timeout 10m `
                    --namespace $namespace `
                    --only-show-errors `
                    2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

                do {
                    $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json 2>$null) | convertFrom-JSON
                    if ($configStatus.ComplianceState -eq "Compliant") {
                        Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration $configName is ready on $clusterName" -ForegroundColor DarkGreen | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                    }
                    else {
                        if ($configStatus.ComplianceState -ne "Non-compliant") {
                            Start-Sleep -Seconds 20
                        }
                        elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                            Start-Sleep -Seconds 20
                            $configStatus = $(az k8s-configuration flux show --name $configName --cluster-name $clusterName --cluster-type $type --resource-group $resourceGroup -o json 2>$null) | convertFrom-JSON
                            if ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -lt $maxRetries) {
                                $retryCount++
                                Write-Host "[$(Get-Date -Format t)] INFO: Attempting to re-install $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                                Write-Host "[$(Get-Date -Format t)] INFO: Deleting $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                                az k8s-configuration flux delete `
                                    --resource-group $resourceGroup `
                                    --cluster-name $clusterName `
                                    --cluster-type $type `
                                    --name $configName `
                                    --force `
                                    --yes `
                                    --only-show-errors `
                                    2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

                                Start-Sleep -Seconds 10
                                Write-Host "[$(Get-Date -Format t)] INFO: Re-creating $configName on $clusterName" -ForegroundColor Gray | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")

                                az k8s-configuration flux create `
                                    --cluster-name $clusterName `
                                    --resource-group $resourceGroup `
                                    --name $configName `
                                    --cluster-type $type `
                                    --scope cluster `
                                    --url $appClonedRepo `
                                    --branch $branch `
                                    --sync-interval 3s `
                                    --kustomization name=$appName path=$appPath prune=true `
                                    --timeout 30m `
                                    --namespace $namespace `
                                    --only-show-errors `
                                    2>&1 | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                            }
                        }
                        elseif ($configStatus.ComplianceState -eq "Non-compliant" -and $retryCount -eq $maxRetries) {
                            Write-Host "[$(Get-Date -Format t)] ERROR: GitOps configuration $configName has failed on $clusterName. Exiting..." -ForegroundColor White -BackgroundColor Red | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\GitOps-$clusterName.log")
                            break
                        }
                    }
                } until ($configStatus.ComplianceState -eq "Compliant")
            }
        }
    }
    while ($(Get-Job -Name gitops).State -eq 'Running') {
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for GitOps configuration to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
        Receive-Job -Name gitops -WarningAction SilentlyContinue
        Start-Sleep -Seconds 60
    }

    Get-Job -name gitops | Remove-Job
    Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
    Write-Host
}

function Set-AIServiceSecrets {
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
            --from-literal=azure-speech-to-text-endpoint=$speechToTextEndpoint
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
        kubectx $clusterName
        kubectl create secret generic azure-sqlpassword-secret `
        --namespace=contoso-hypermarket `
        --from-literal=azure-sqlpassword-secret=$Env:adminPassword
    }
}