function SetupMfgRepo {
    param (
        $AgConfig
    )
    Set-Location $AgConfig.AgDirectories["AgAppsRepo"]
    $appsRepo = "jumpstart-agora-apps"
    $branch = "manufacturing"
    Write-Host "INFO: Cloning the GitHub repository locally" -ForegroundColor Gray
    git clone -b $branch "https://github.com/microsoft/$appsRepo.git" "$appsRepo"
}

function Deploy-MfgTemp {
    param (
        $AgConfig,
        $Credentials
    )
    $appsRepo = "jumpstart-agora-apps"
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        kubectx $cluster.Name.ToLower()
        Set-Location "$($AgConfig.AgDirectories["AgAppsRepo"])\$appsRepo"
        
        # Apply the InfluxDB deployment configuration from the influxdb.yaml file. This will set up InfluxDB in your Kubernetes cluster.
        kubectl apply -f contoso_manufacturing\deployment\yamls\influxdb.yaml
        
        # Apply the ConfigMap for InfluxDB from the influxdb-configmap.yaml file. ConfigMaps are used to store non-confidential data in key-value pairs. This particular ConfigMap contain configuration settings for InfluxDB and the dashboard.
        kubectl apply -f contoso_manufacturing\deployment\yamls\influxdb-configmap.yaml

        # Apply the deployment configuration for an MQTT simulator from the mqtt_simulator.yaml file. This simulator can be used for generating MQTT messages to test MQTT integrations or listeners in your environment.
        kubectl apply -f contoso_manufacturing\deployment\yamls\mqtt_simulator.yaml

        # Apply the deployment configuration for an MQTT listener from the mqtt-listener.yaml file. This listener acts as a subscriber to MQTT topics to process or store the incoming messages, potentially integrating with other services like InfluxDB.
        kubectl apply -f contoso_manufacturing\deployment\yamls\mqtt-listener.yaml

        # Apply the deployment configuration for an RTSP simulator from the rtsp-simulator.yaml file. This simulator can be used to mimic an RTSP feed, useful for testing video processing or streaming applications without the need for actual video sources.
        #kubectl apply -f contoso_manufacturing\deployment\yamls\rtsp-simulator.yaml

        #kubectl port-forward svc/virtual-rtsp 8554:8554

        # Apply the deployment configuration for the 'decode' application from the decode.yaml file. This application is responsible for connecting to an RTSP feed, capturing frames, and potentially processing or forwarding those frames for further analysis or storage.
        kubectl apply -f contoso_manufacturing\deployment\yamls\decode.yaml
    }
}

function Deploy-ManufacturingConfigs {
    Write-Host "[$(Get-Date -Format t)] INFO: Cleaning up images-cache namespace on all clusters" -ForegroundColor Gray
    # Cleaning up images-cache namespace on all clusters
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        Start-Job -Name images-cache-cleanup -ScriptBlock {
            $cluster = $using:cluster
            $clusterName = $cluster.Name.ToLower()
            Write-Host "[$(Get-Date -Format t)] INFO: Deleting images-cache namespace on cluster $clusterName" -ForegroundColor Gray
            kubectl delete namespace "images-cache" --context $clusterName
        }
    }

    #  TODO - Will we need to wait for builds in agora repo?
    while ($workflowStatus.status -ne "completed") {
        #Write-Host "INFO: Waiting for pos-app-initial-images-build workflow to complete" -ForegroundColor Gray
        #Start-Sleep -Seconds 10
        #$workflowStatus = (gh run list --workflow=pos-app-initial-images-build.yml --json status) | ConvertFrom-Json
    }

    # Loop through the clusters and
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        Start-Job -Name gitops -ScriptBlock {
            $AgConfig = $using:AgConfig
            $cluster = $using:cluster
            $site = $cluster.Value
            $siteName = $site.FriendlyName.ToLower()
            $namingGuid = $using:namingGuid
            $resourceGroup = $using:resourceGroup
            $appClonedRepo = $using:appClonedRepo
            $appsRepo = $using:appsRepo

            $AgConfig.AppConfig.GetEnumerator() | sort-object -Property @{Expression = { $_.value.Order }; Ascending = $true } | ForEach-Object {
                $app = $_
                $store = $cluster.value.Branch.ToLower()
                $clusterName = $cluster.value.ArcClusterName + "-$namingGuid"
                $branch = $cluster.value.Branch.ToLower()
                $configName = $app.value.GitOpsConfigName.ToLower()
                $clusterType = $cluster.value.Type
                $namespace = $app.value.Namespace
                $appName = $app.Value.KustomizationName
                $appPath = $app.Value.KustomizationPath
                $retryCount = 0
                $maxRetries = 2

                Write-Host "[$(Get-Date -Format t)] INFO: Creating GitOps config for $configName on $($cluster.Value.ArcClusterName+"-$namingGuid")" -ForegroundColor Gray
                if ($clusterType -eq "AKS") {
                    $type = "managedClusters"
                    $clusterName = $cluster.value.ArcClusterName
                }
                else {
                    $type = "connectedClusters"
                }
                if ($branch -eq "main") {
                    $store = "dev"
                }

                # Wait for Kubernetes API server to become available
                $apiServer = kubectl config view --context $cluster.Name.ToLower() --minify -o jsonpath='{.clusters[0].cluster.server}'
                $apiServerAddress = $apiServer -replace '.*https://| .*$'
                $apiServerFqdn = ($apiServerAddress -split ":")[0]
                $apiServerPort = ($apiServerAddress -split ":")[1]

                do {
                    $result = Test-NetConnection -ComputerName $apiServerFqdn -Port $apiServerPort -WarningAction SilentlyContinue
                    if ($result.TcpTestSucceeded) {
                        break
                    }
                    else {
                        Start-Sleep -Seconds 5
                    }
                } while ($true)
                If ($app.Value.ConfigMaps) {
                    # download the config files
                    foreach ($configMap in $app.value.ConfigMaps.GetEnumerator()) {
                        $repoPath = $configMap.value.RepoPath
                        $configPath = "$configMapDir\$appPath\config\$($configMap.Name)\$branch"
                        $iotHubName = $Env:iotHubHostName.replace(".azure-devices.net", "")
                        $gitHubUser = $Env:gitHubUser
                        $githubBranch = $Env:githubBranch

                        New-Item -Path $configPath -ItemType Directory -Force | Out-Null

                        $githubApiUrl = "https://api.github.com/repos/$gitHubUser/$appsRepo/$($repoPath)?ref=$branch"
                        Get-GitHubFiles -githubApiUrl $githubApiUrl -folderPath $configPath

                        # replace the IoT Hub name and the SAS Tokens with the deployment specific values
                        # this is a one-off for the broker, but needs to be generalized if/when another app needs it
                        If ($configMap.Name -eq "mqtt-broker-config") {
                            $configFile = "$configPath\mosquitto.conf"
                            $update = (Get-Content $configFile -Raw)
                            $update = $update -replace "Ag-IotHub-\w*", $iotHubName

                            foreach ($device in $site.IoTDevices) {
                                $deviceId = "$device-$($site.FriendlyName)"
                                $deviceSASToken = $(az iot hub generate-sas-token --device-id $deviceId --hub-name $iotHubName --resource-group $resourceGroup --duration (60 * 60 * 24 * 30) --query sas -o tsv --only-show-errors)
                                $update = $update -replace "Chicago", $site.FriendlyName
                                $update = $update -replace "SharedAccessSignature.*$($device).*", $deviceSASToken
                            }

                            $update | Set-Content $configFile
                        }

                        # create the namespace if needed
                        If (-not (kubectl get namespace $namespace --context $siteName)) {
                            kubectl create namespace $namespace --context $siteName
                        }
                        # create the configmap
                        kubectl create configmap $configMap.name --from-file=$configPath --namespace $namespace --context $siteName
                    }
                }

                az k8s-configuration flux create `
                    --cluster-name $clusterName `
                    --resource-group $resourceGroup `
                    --name $configName `
                    --cluster-type $type `
                    --url $appClonedRepo `
                    --branch $branch `
                    --sync-interval 5s `
                    --kustomization name=$appName path=$appPath/$store prune=true retry_interval=1m `
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
                                    --url $appClonedRepo `
                                    --branch $branch `
                                    --sync-interval 5s `
                                    --kustomization name=$appName path=$appPath/$store prune=true `
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
        #Write-Host "[$(Get-Date -Format t)] INFO: Waiting for GitOps configuration to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
        Receive-Job -Name gitops -WarningAction SilentlyContinue
        Start-Sleep -Seconds 60
    }

    Get-Job -name gitops | Remove-Job
    Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
    Write-Host
}
function Deploy-InfluxDb {
    ##############################################################
    # Deploy OT Inspector (InfluxDB)
    ##############################################################
    $aioToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
    $listenerYaml = "$aioToolsDir\mqtt_listener.yml"
    $influxdb_setupYaml = "$aioToolsDir\influxdb_setup.yml"
    $influxdbYaml = "$aioToolsDir\influxdb.yml"
    $influxImportYaml = "$aioToolsDir\influxdb-import-dashboard.yml"

    do {
        $simulatorPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
        $matchingPods = $simulatorPod.items | Where-Object {
            $_.metadata.name -match "mqtt-simulator-deployment" -and
            $_.status.phase -notmatch "running"
        }
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the simulator to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
        Start-Sleep -Seconds 20
    } while (
        $matchingPods.Count -ne 0
    )

    kubectl apply -f $influxdb_setupYaml -n $aioNamespace

    do {
        $influxIp = kubectl get service "influxdb" -n $aioNamespace -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for InfluxDB IP address to be assigned...Waiting for 10 seconds" -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    } while (
        $null -eq $influxIp
    )

    (Get-Content $listenerYaml ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $listenerYaml
    (Get-Content $mqttExplorerSettings ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $mqttExplorerSettings
    (Get-Content $listenerYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $listenerYaml
    (Get-Content $influxdbYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $influxdbYaml
    (Get-Content $influxdbYaml ) -replace 'influxAdminPwdPlaceHolder', $adminPassword | Set-Content $influxdbYaml
    (Get-Content $influxdbYaml ) -replace 'influxAdminPlaceHolder', $adminUsername | Set-Content $influxdbYaml
    (Get-Content $influxImportYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $influxImportYaml

    kubectl apply -f $aioToolsDir\influxdb.yml -n $aioNamespace

    do {
        $influxPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
        $matchingPods = $influxPod.items | Where-Object {
            $_.metadata.name -match "influxdb-0" -and
            $_.status.phase -notmatch "running"
        }
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the influx pods to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
        Start-Sleep -Seconds 20
    } while (
        $matchingPods.Count -ne 0
    )

    kubectl apply -f $aioToolsDir\mqtt_listener.yml -n $aioNamespace
    do {
        $listenerPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
        $matchingPods = $listenerPod.items | Where-Object {
            $_.metadata.name -match "mqtt-listener-deployment" -and
            $_.status.phase -notmatch "running"
        }
        Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the mqtt listener pods to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
        Start-Sleep -Seconds 20
    } while (
        $matchingPods.Count -ne 0
    )

    kubectl apply -f $aioToolsDir\influxdb-import-dashboard.yml -n $aioNamespace
    kubectl apply -f $aioToolsDir\influxdb-configmap.yml -n $aioNamespace

}

function Deploy-AIO {
    # Deploys Azure IoT Operations on all k8s clusters in the config file

    ##############################################################
    # Preparing clusters for aio
    ##############################################################
    $VMnames = $AgConfig.SiteConfig.GetEnumerator().Name.ToLower()

    Invoke-Command -VMName $VMnames -Credential $Credentials -ScriptBlock {
        $ProgressPreference = "SilentlyContinue"
        ###########################################
        # Preparing environment folders structure
        ###########################################
        Write-Host "[$(Get-Date -Format t)] INFO: Preparing AKSEE clusters for AIO" -ForegroundColor DarkGray
        Write-Host "`n"
        try {
            $localPathProvisionerYaml = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml"
            & kubectl apply -f $localPathProvisionerYaml
            $pvcYaml = @"
            apiVersion: v1
            kind: PersistentVolumeClaim
            metadata:
              name: local-path-pvc
              namespace: default
            spec:
              accessModes:
                - ReadWriteOnce
              storageClassName: local-path
              resources:
                requests:
                  storage: 15Gi
"@

            $pvcYaml | kubectl apply -f -

            Write-Host "Successfully deployment the local path provisioner"
        }
        catch {
            Write-Host "Error: local path provisioner deployment failed" -ForegroundColor Red
        }

        Write-Host "Configuring firewall specific to AIO"
        Write-Host "Add firewall rule for AIO MQTT Broker"
        New-NetFirewallRule -DisplayName "AIO MQTT Broker" -Direction Inbound  -Action Allow | Out-Null
        try {
            $deploymentInfo = Get-AksEdgeDeploymentInfo
            # Get the service ip address start to determine the connect address
            $connectAddress = $deploymentInfo.LinuxNodeConfig.ServiceIpRange.split("-")[0]
            $portProxyRulExists = netsh interface portproxy show v4tov4 | findstr /C:"1883" | findstr /C:"$connectAddress"
            if ( $null -eq $portProxyRulExists ) {
                Write-Host "Configure port proxy for AIO"
                netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$connectAddress | Out-Null
                netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=18883 connectaddress=$connectAddress | Out-Null
                netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=8883 connectaddress=$connectAddress | Out-Null
            }
            else {
                Write-Host "Port proxy rule for AIO exists, skip configuring port proxy..."
            }
        }
        catch {
            Write-Host "Error: port proxy update for aio failed" -ForegroundColor Red
        }
        Write-Host "Update the iptables rules"
        try {
            $iptableRulesExist = Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables-save | grep -- '-m tcp --dport 9110 -j ACCEPT'" -ignoreError
            if ( $null -eq $iptableRulesExist ) {
                Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 9110 -j ACCEPT"
                Write-Host "Updated runtime iptable rules for node exporter"
                Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo sed -i '/-A OUTPUT -j ACCEPT/i-A INPUT -p tcp -m tcp --dport 9110 -j ACCEPT' /etc/systemd/scripts/ip4save"
                Write-Host "Persisted iptable rules for node exporter"
                # increase the maximum number of files
                Invoke-AksEdgeNodeCommand -NodeType "Linux" -Command "echo 'fs.inotify.max_user_instances = 1024' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
            }
            else {
                Write-Host "iptable rule exists, skip configuring iptable rules..."
            }
        }
        catch {
            Write-Host "Error: iptable rule update failed" -ForegroundColor Red
        }
    } | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\L1Infra.log")

    #############################################################
    # Deploying AIO on the clusters
    #############################################################

    Write-Host "[$(Get-Date -Format t)] INFO: Deploying AIO to the clusters" -ForegroundColor DarkGray
    Write-Host "`n"
    $kvIndex = 0

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying AIO to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
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

        do {
            az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientId --sp-secret $spnClientSecret --sp-object-id $spnObjectId --mq-service-type loadBalancer --mq-insecure true --simulate-plc false --no-block --only-show-errors
            if ($? -eq $false) {
                $aioStatus = "notDeployed"
                Write-Host "`n"
                Write-Host "[$(Get-Date -Format t)] Error: An error occured while deploying AIO on the cluster...Retrying" -ForegroundColor DarkRed
                Write-Host "`n"
                az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientId --sp-secret $spnClientSecret --sp-object-id $spnObjectId --mq-service-type loadBalancer --mq-insecure true --simulate-plc false --no-block --only-show-errors
                $retryCount++
            }
            else {
                $aioStatus = "deployed"
            }
        } until ($aioStatus -eq "deployed" -or $retryCount -eq $maxRetries)
        $kvIndex++
    }
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        $retryCount = 0
        $maxRetries = 25
        kubectx $clusterName
        do {
            $output = az iot ops check --as-object --only-show-errors
            $output = $output | ConvertFrom-Json
            $mqServiceStatus = ($output.postDeployment | Where-Object { $_.name -eq "evalBrokerListeners" }).status
            if ($mqServiceStatus -ne "Success") {
                Write-Host "Waiting for AIO to be deployed successfully on $clusterName...waiting for 60 seconds" -ForegroundColor DarkGray
                Start-Sleep -Seconds 60
                $retryCount++
            }
        } until ($mqServiceStatus -eq "Success" -or $retryCount -eq $maxRetries)

        if ($retryCount -eq $maxRetries) {
            Write-Host "[$(Get-Date -Format t)] ERROR: AIO deployment failed. Exiting..." -ForegroundColor White -BackgroundColor Red
            exit 1 # Exit the script
        }
        Write-Host "AIO deployed successfully on the $clusterName cluster" -ForegroundColor Green
        Write-Host "`n"
        Write-Host "[$(Get-Date -Format t)] INFO: Started Event Grid role assignment process" -ForegroundColor DarkGray
        $extensionPrincipalId = (az k8s-extension show --cluster-name $arcClusterName --name "mq" --resource-group $resourceGroup --cluster-type "connectedClusters" --output json | ConvertFrom-Json).identity.principalId
        $eventGridTopicId = (az eventgrid topic list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)
        $eventGridNamespaceName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].name" -o tsv --only-show-errors)
        $eventGridNamespaceId = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)

        az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
        #az role assignment create --assignee-object-id $spnObjectId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
        az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid TopicSpaces Subscriber" --scope $eventGridNamespaceId --assignee-principal-type ServicePrincipal --only-show-errors
        az role assignment create --assignee-object-id $extensionPrincipalId --role 'EventGrid TopicSpaces Publisher' --scope $eventGridNamespaceId --assignee-principal-type ServicePrincipal --only-show-errors
        az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid TopicSpaces Subscriber" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors
        az role assignment create --assignee-object-id $extensionPrincipalId --role 'EventGrid TopicSpaces Publisher' --scope $eventGridTopicId --assignee-principal-type ServicePrincipal --only-show-errors

        Start-Sleep -Seconds 60

        Write-Host "[$(Get-Date -Format t)] INFO: Configuring routing to use system-managed identity" -ForegroundColor DarkGray
        $eventGridConfig = "{routing-identity-info:{type:'SystemAssigned'}}"
        az eventgrid namespace update -g $resourceGroup -n $eventGridNamespaceName --topic-spaces-configuration $eventGridConfig --only-show-errors

        Start-Sleep -Seconds 60

        ## Adding MQTT bridge to Event Grid MQTT
        $mqconfigfile = "$AgToolsDir\mq_cloudConnector.yml"
        (Get-Content $mqconfigfile) -replace 'clusterName', $clusterName | Set-Content $mqconfigfile
        Write-Host "[$(Get-Date -Format t)] INFO: Configuring the MQ Event Grid bridge" -ForegroundColor DarkGray
        $eventGridHostName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].topicSpacesConfiguration.hostname" -o tsv --only-show-errors)
        (Get-Content -Path $mqconfigfile) -replace 'eventGridPlaceholder', $eventGridHostName | Set-Content -Path $mqconfigfile
        kubectl apply -f $mqconfigfile -n $aioNamespace
    }
}

function Deploy-ESA {
    param (
        $AgConfig,
        [PSCredential]$Credentials
    )
    ##############################################################
    # Deploy Edge Storage Accelerator (ESA)
    ##############################################################
    Write-Host "[$(Get-Date -Format t)] INFO: Deploying ESA to the clusters" -ForegroundColor DarkGray
    Write-Host "`n"
    $aioToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
    $esapvJson = "$aioToolsDir\config.json"
    $esapvYaml = "$aioToolsDir\esapv.yml"
    $esapvcYaml = "$aioToolsDir\esapvc.yml"
    $esaappYaml = "$aioToolsDir\configPod.yml"

    # Get the storage Account secret
    $esaSecret = az storage account keys list --resource-group $resourceGroup -n $aioStorageAccountName --query "[0].value" -o tsv

    # Define names for ESA Yamls
    $esaPVName = "esapv"
    $esaPVCName = "esapvc"
    $esaAppName = "testingapp"

    # Inject params into the yaml file for PV
    (Get-Content $esapvYaml ) -replace 'esaPVName', $esaPVName | Set-Content $esapvYaml
    (Get-Content $esapvYaml ) -replace 'esanamespace', $aioNamespace | Set-Content $esapvYaml
    (Get-Content $esapvYaml ) -replace 'esaContainerName', $stcontainerName | Set-Content $esapvYaml
    (Get-Content $esapvYaml ) -replace 'esaSecretName', "esasecret" | Set-Content $esapvYaml

    # Inject params into the yaml file for PVC
    (Get-Content $esapvcYaml ) -replace 'esaPVCName', $esaPVCName | Set-Content $esapvcYaml
    (Get-Content $esapvcYaml ) -replace 'esanamespace', $aioNamespace | Set-Content $esapvcYaml
    (Get-Content $esapvcYaml ) -replace 'esaPVName', $esaPVName | Set-Content $esapvcYaml

    # Inject params into the yaml file for ESA App
    (Get-Content $esaappYaml ) -replace 'appname', $esaAppName | Set-Content $esaappYaml
    (Get-Content $esaappYaml ) -replace 'esanamespace', $aioNamespace | Set-Content $esaappYaml
    (Get-Content $esaappYaml ) -replace 'esaPVCName', $esaPVCName | Set-Content $esaappYaml

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying ESA to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        kubectx $clusterName
        $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"

        # Enable Open Service Mesh extension on the Arc-enabled cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Enabling Open Service Mesh on the $clusterName cluster" -ForegroundColor DarkGray
        az k8s-extension create --resource-group $resourceGroup --cluster-name $arcClusterName --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --name osm --only-show-errors

        # Enable ESA extension on the Arc-enabled cluster
        Write-Host "[$(Get-Date -Format t)] INFO: Enabling ESA on the $clusterName cluster" -ForegroundColor DarkGray
        az k8s-extension create --resource-group $resourceGroup --cluster-name $arcClusterName --cluster-type connectedClusters --name hydraext --extension-type microsoft.edgestorageaccelerator --config-file $esapvJson --scope cluster --only-show-errors
        kubectl create secret generic -n $aioNamespace esasecret --from-literal=azurestorageaccountkey=$esaSecret --from-literal=azurestorageaccountname=$aioStorageAccountName

        Write-Host "[$(Get-Date -Format t)] INFO: Deploying PV on the $clusterName cluster" -ForegroundColor DarkGray
        kubectl apply -f $esapvYaml

        Write-Host "[$(Get-Date -Format t)] INFO: Deploying PVC on the $clusterNamecluster" -ForegroundColor DarkGray
        kubectl apply -f $esapvcYaml

        Write-Host "[$(Get-Date -Format t)] INFO: Attaching App on ESA Container" -ForegroundColor DarkGray
        kubectl apply -f $esaappYaml
    }
}

function Configure-MQTTIpAddress {
    $mqttIpArray = @()
    $clusters = $AgConfig.SiteConfig.GetEnumerator()
    foreach ($cluster in $clusters) {
        $clusterName = $cluster.Name.ToLower()
        kubectx $clusterName | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\ClusterSecrets.log")
        Write-Host "[$(Get-Date -Format t)] INFO: Getting MQ IP address" -ForegroundColor DarkGray

        do {
            $mqttIp = kubectl get service $mqListenerService -n $aioNamespace -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
            $services = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
            $matchingServices = $services.items | Where-Object {
                $_.metadata.name -match "aio-mq-dmqtt" -and
                $_.status.phase -notmatch "running"
            }
            Write-Host "[$(Get-Date -Format t)] INFO: Waiting for MQTT services to initialize and the service Ip address to be assigned...Waiting for 20 seconds" -ForegroundColor DarkGray
            Start-Sleep -Seconds 20
        } while (
            $null -eq $mqttIp -and $matchingServices.Count -ne 0
        )
        if (-not [string]::IsNullOrEmpty($mqttIp)) {
            $newObject = [PSCustomObject]@{
                cluster = $clusterName
                ip = $mqttIp
            }
            $mqttIpArray += $newObject
        }

        Invoke-Command -VMName $clusterName -Credential $Credentials -ScriptBlock {
            netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$using:mqttIp
        }
    }

    $mqttIpArray = $mqttIpArray | Where-Object { $_ -ne "" }

    return $mqttIpArray
}

function Deploy-MQTTSimulator {
    param (
        [array]$mqttIpArray
    )

    $mqsimulatorfile = "$AgToolsDir\mqtt_simulator.yml"

    $clusters = $AgConfig.SiteConfig.GetEnumerator()

    foreach ($cluster in $clusters) {
        $clusterName = $cluster.Name.ToLower()
        Copy-Item $mqsimulatorfile "$AgToolsDir\mqtt_simulator_$clusterName.yml"
        $simualtorConfig = "$AgToolsDir\mqtt_simulator_$clusterName.yml"
        $mqttIp = $mqttIpArray | Where-Object { $_.cluster -eq $clusterName } | Select-Object -ExpandProperty ip
        Write-Host "[$(Get-Date -Format t)] INFO: Deploying MQTT Simulator to the $clusterName cluster" -ForegroundColor Gray
        Write-Host "`n"
        kubectx $clusterName
        (Get-Content $simualtorConfig ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $simualtorConfig
        netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$mqttIp
        kubectl apply -f $simualtorConfig -n $aioNamespace
    }
}

##############################################################
# Install MQTT Explorer
##############################################################
function Deploy-MQTTExplorer {
    param (
        [array]$mqttIpArray
    )
    Write-Host "`n"
    Write-Host "[$(Get-Date -Format t)] INFO: Installing MQTT Explorer." -ForegroundColor DarkGreen
    Write-Host "`n"
    $aioToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
    $mqttExplorerSettings = "$aioToolsDir\mqtt_explorer_settings.json"
    $latestReleaseTag = (Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].tag_name
    $versionToDownload = $latestReleaseTag.Split("v")[1]
    $mqttExplorerReleaseDownloadUrl = ((Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].assets | Where-object { $_.name -like "MQTT-Explorer-Setup-${versionToDownload}.exe" }).browser_download_url
    $output = Join-Path $aioToolsDir "mqtt-explorer-$latestReleaseTag.exe"
    $clusters = $AgConfig.SiteConfig.GetEnumerator()

    Invoke-WebRequest $mqttExplorerReleaseDownloadUrl -OutFile $output
    Start-Process -FilePath $output -ArgumentList "/S" -Wait

    Write-Host "[$(Get-Date -Format t)] INFO: Configuring MQTT explorer" -ForegroundColor DarkGray
    Start-Process "$env:USERPROFILE\AppData\Local\Programs\MQTT-Explorer\MQTT Explorer.exe"
    Start-Sleep -Seconds 5
    Stop-Process -Name "MQTT Explorer"
    Copy-Item "$aioToolsDir\mqtt_explorer_settings.json" -Destination "$env:USERPROFILE\AppData\Roaming\MQTT-Explorer\settings.json" -Force
    foreach ($cluster in $clusters) {
        $clusterName = $cluster.Name.ToLower()
        $mqttIp = $mqttIpArray | Where-Object { $_.cluster -eq $clusterName } | Select-Object -ExpandProperty ip
        (Get-Content $mqttExplorerSettings ) -replace "${clusterName}IpPlaceholder", $mqttIp | Set-Content $mqttExplorerSettings
    }
}

# Function to deploy Azure Data Explorer dashboard reports
function Deploy-ADXDashboardReports {
    ### BELOW IS AN ALTERNATIVE APPROACH TO IMPORT DASHBOARD USING README INSTRUCTIONS
    $adxDashBoardsDir = $AgConfig.AgDirectories["AgAdxDashboards"]

    # Create directory if do not exist
    if (-not (Test-Path -LiteralPath $adxDashBoardsDir)) {
        New-Item -Path $adxDashBoardsDir -ItemType Directory -ErrorAction Stop | Out-Null #-Force
    }

    #$dataEmulatorDir = $AgConfig.AgDirectories["AgDataEmulator"]
    $kustoCluster = Get-AzKustoCluster -ResourceGroupName $resourceGroup -Name $adxClusterName
    if ($null -ne $kustoCluster) {
        $adxEndPoint = $kustoCluster.Uri
        if ($null -ne $adxEndPoint -and $adxEndPoint -ne "") {
            $ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/adx_dashboards/adx-dashboard-contoso-motors-auto-parts.json").Content -replace '{{ADX_CLUSTER_URI}}', $adxEndPoint -replace '{{ADX_CLUSTER_NAME}}', $adxClusterName -replace '{{GITHUB_BRANCH}}', $env:githubBranch -replace '{{GITHUB_ACCOUNT}}', $env:githubAccount
            Set-Content -Path "$adxDashBoardsDir\adx-dashboard-contoso-motors-auto-parts.json" -Value $ordersDashboardBody -Force -ErrorAction Ignore
        }
        else {
            Write-Host "[$(Get-Date -Format t)] ERROR: Unable to find Azure Data Explorer endpoint from the cluster resource in the resource group."
        }
    }

    # Create EventHub environment variables
    $eventHubNamespace = (az eventhubs namespace list --resource-group $env:resourceGroup --query [0].name --output tsv)
    if ($null -ne $eventHubNamespace) {
        # Find EventHub and create connection string
        $eventHub = (az eventhubs eventhub list --namespace-name $eventHubNamespace --resource-group $env:resourceGroup --query [0].name --output tsv)

        # Create authorization rule
        $authRuleName = "data-emulator"
        az eventhubs eventhub authorization-rule create --authorization-rule-name $authRuleName --eventhub-name $eventHub --namespace-name $eventHubNamespace --resource-group $env:resourceGroup --rights Send Listen

        # Get connection string
        $connectionString = (az eventhubs eventhub authorization-rule keys list --resource-group $env:resourceGroup --namespace-name $eventHubNamespace --eventhub-name $eventHub --name $authRuleName --query primaryConnectionString --output tsv)

        # Set environment variables
        [System.Environment]::SetEnvironmentVariable('EVENTHUB_CONNECTION_STRING', $connectionString, [System.EnvironmentVariableTarget]::Machine)
        [System.Environment]::SetEnvironmentVariable('EVENTHUB_NAME', $eventHub, [System.EnvironmentVariableTarget]::Machine)
    }
    
    # Create desktop icons
    $AgDataEmulatorDir = $AgConfig.AgDirectories["AgDataEmulator"]
    $dataEmulatorFile = "$AgDataEmulatorDir\data-emulator.py"
    Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/data_emulator/data-emulator.py" -OutFile $dataEmulatorFile
    if (!(Test-Path -Path $dataEmulatorFile)) {
        Write-Host "Unabled to download data-emulator.py file. Please download manually from GitHub into the DataEmulator folder."
    }

    $emulationScriptContent = "@echo off `r`ncmd /k `"cd /d $AgDataEmulatorDir & python data-emulator.py`""
    $emulatorLocation = "$AgDataEmulatorDir\dataemulator.cmd"
    Set-Content -Path $emulatorLocation -Value $emulationScriptContent

    # Download icon file
    $AgIconsDir = $AgConfig.AgDirectories["AgIconDir"]

    $iconPath = "$AgIconsDir\emulator.ico"
    Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/icons/emulator.ico" -OutFile $iconPath
    if (!(Test-Path -Path $iconPath)) {
        Write-Host "Unabled to download emulator.ico file. Please download manually from GitHub into the icons folder."
    }

    # Create desktop shortcut
    $shortcutLocation = "$Env:Public\Desktop\Data Emulator.lnk"
    $wScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
    $shortcut.TargetPath = $emulatorLocation
    $shortcut.IconLocation = "$iconPath, 0"
    $shortcut.WindowStyle = 8
    $shortcut.Save()

    # Install azure.eventhub python module to run data emulator
    pip install azure.eventhub
}