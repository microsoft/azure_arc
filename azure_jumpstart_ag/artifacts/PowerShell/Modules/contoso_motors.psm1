function Get-K3sConfigFileContosoMotors {
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Host "Downloading k3s Kubeconfigs"
    $Env:AZCOPY_AUTO_LOGIN_TYPE = "MSI"
    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        $clusterName = $cluster.Name.ToLower()
        $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
        $containerName = $arcClusterName.toLower()
        $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/config"
        azcopy cp $sourceFile "C:\Users\$adminUsername\.kube\ag-k3s-$clusterName" --check-length=false
        $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/*"
        azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile "$AgLogsDir\" --include-pattern "*.log"
    }
}

function Merge-K3sConfigFilesContosoMotors{

    $mergedKubeconfigPath = "C:\Users\$adminUsername\.kube\config"

    $kubeconfig1Path = "C:\Users\$adminUsername\.kube\ag-k3s-detroit"
    $kubeconfig2Path = "C:\Users\$adminUsername\.kube\ag-k3s-monterrey"

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
    kubectx detroit="ag-k3s-detroit"
    kubectx monterrey="ag-k3s-monterrey"

}

function Set-K3sClusters {
    Write-Host "Configuring kube-vip on K3s clusters"
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

            # Initialize serviceIpRange as empty
            $serviceIpRange = @()

            # Loop until serviceIpRange is not empty
            while ($serviceIpRange.Count -eq 0) {
                $serviceIpRange = $(az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``false``].privateIPAddress" -otsv)
                if ($serviceIpRange.Count -eq 0) {
                    Write-Host "serviceIpRange is empty, retrying..."
                    Start-Sleep -Seconds 5
                }
            }

            $sortedIps = $serviceIpRange | Sort-Object { [System.Version]$_ }
            $lowestServiceIp = $sortedIps[0]
            $highestServiceIp = $sortedIps[-1]

            kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
            Start-Sleep -Seconds 30

            # Write-Host "Creating longhorn storage on K3scluster"
            # kubectl apply -f "$($Agconfig.AgDirectories.AgToolsDir)\longhorn.yaml"
            # Start-Sleep -Seconds 30
        }
    }
}

function Deploy-MotorsConfigs {
    Write-Host "[$(Get-Date -Format t)] INFO: Beginning Contoso Motors GitOps Deployment" -ForegroundColor Gray

  

    # Loop through the clusters and deploy the configs in AppConfig hashtable in AgConfig-contoso-motors.psd
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
                                    --sync-interval 5m `
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
        #Write-Host "[$(Get-Date -Format t)] INFO: Waiting for GitOps configuration to complete on all clusters...waiting 60 seconds" -ForegroundColor Gray
        Receive-Job -Name gitops -WarningAction SilentlyContinue
        Start-Sleep -Seconds 60
    }

    Get-Job -name gitops | Remove-Job
    Write-Host "[$(Get-Date -Format t)] INFO: GitOps configuration complete." -ForegroundColor Green
    Write-Host
}

function Deploy-MQTTSimulator {
    param (
        [array]$mqttIpArray
    )

    $mqsimulatorfile = "$AgToolsDir\mqtt_simulator.yml"

    $clusters = $AgConfig.SiteConfig.GetEnumerator()

    foreach ($cluster in $clusters) {
        $clusterName = $cluster.Name.ToLower()
        Copy-Item $mqsimulatorfile "$AgToolsDir\mqtt_simulator_$clusterName.yml" -Force
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

function Deploy-MotorsBookmarks {
    $bookmarksFileName = "$AgToolsDir\Bookmarks"
    $edgeBookmarksPath = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

    foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
        kubectx $cluster.Name.ToLower() | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")
        $services = kubectl get services --all-namespaces -o json | ConvertFrom-Json

        # Matching url: flask app
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'flask-app-service' -and
            $_.spec.ports.port -contains 8888
        }
        $flaskIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($flaskIp in $flaskIps) {
            $output = "http://${flaskIp}:8888"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Flask-" + $cluster.Name + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName

            Start-Sleep -Seconds 2
        }

        # Matching url: Influxdb
        $matchingServices = $services.items | Where-Object {
            $_.metadata.name -eq 'Influxdb' -and
            $_.spec.ports.port -contains 8086
        }
        $influxdbIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($influxdbIp in $influxdbIps) {
            $output = "http://${influxdbIp}:8086"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Influxdb-" + $cluster.Name + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName

            Start-Sleep -Seconds 2
        }

        # Matching url: prometheus
        $matchingServices = $services.items | Where-Object {
            $_.spec.ports.port -contains 9090 -and
            $_.spec.type -eq "LoadBalancer"
        }
        $prometheusIps = $matchingServices.status.loadBalancer.ingress.ip

        foreach ($prometheusIp in $prometheusIps) {
            $output = "http://${prometheusIp}:9090"
            $output | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\Bookmarks.log")

            # Replace matching value in the Bookmarks file
            $content = Get-Content -Path $bookmarksFileName
            $newContent = $content -replace ("Prometheus-" + $cluster.Name + "-URL"), $output
            $newContent | Set-Content -Path $bookmarksFileName

            Start-Sleep -Seconds 2
        }
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
