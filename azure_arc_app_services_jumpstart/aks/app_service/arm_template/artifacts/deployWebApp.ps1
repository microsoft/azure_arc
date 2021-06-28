# Deploying Azure Arc SQL Managed Instance
Write-Host "Deploying Azure Arc-enabled app services with a Web App environment"
Write-Host "`n"

$namespace="appservices"
$extensionName = "arc-app-services"
$kubeEnvironmentName=$env:clusterName
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $env:workspaceName --query primarySharedKey -o tsv)
$workspaceIdEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceId))
$workspaceKeyEnc = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceKey))

$extensionId = az k8s-extension create -g $env:resourceGroup --name $extensionName --query id -o tsv `
    --cluster-type connectedClusters -c $env:clusterName `
    --extension-type 'Microsoft.Web.Appservice' --release-train stable --auto-upgrade-minor-version true `
    --scope cluster --release-namespace "$namespace" `
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default"  `
    --configuration-settings "appsNamespace=$namespace"  `
    --configuration-settings "clusterName=$kubeEnvironmentName"  `
    --configuration-settings "loadBalancerIp=$staticIp"  `
    --configuration-settings "keda.enabled=true"  `
    --configuration-settings "buildService.storageClassName=default"  `
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce"  `
    --configuration-settings "customConfigMap=$namespace/kube-environment-config" `
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=$aksResourceGroupMC" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${workspaceIdEnc}" --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${workspaceKeyEnc}"

az resource wait --ids $extensionId --api-version 2020-07-01-preview --custom "properties.installState!='Pending'"

Start-Transcript -Path C:\Temp\deployWebApp.log

Do {
   Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $logProcessorStatus = $(if(kubectl describe daemonset "arc-app-services-k8se-log-processor" -n appservices | Select-String "Pods Status:  3 Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($logProcessorStatus -eq "Nope")

Do {
   Write-Host "Waiting for build service to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $buildService = $(if(kubectl get pods -n appservices | Select-String "k8se-build-service" | Select-String "Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($buildService -eq "Nope")

Do {
   Write-Host "Waiting for log-processor to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 45
   $logProcessorStatus = $(if(kubectl describe daemonset "arc-app-services-k8se-log-processor" -n appservices | Select-String "Pods Status:  3 Running" -Quiet){"Ready!"}Else{"Nope"})
   } while ($logProcessorStatus -eq "Nope")

Write-Host "`n"
Write-Host "Deploying App Service Kubernetes Environment"
Write-Host "`n"
$connectedClusterId = az connectedk8s show --name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name $extensionName --cluster-type connectedClusters --cluster-name $env:clusterName --resource-group $env:resourceGroup --query id -o tsv
$customLocationId = $(az customlocation create --name 'jumpstart-cl' --resource-group $env:resourceGroup --namespace appservices --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId  --query id -o tsv)
az appservice kube create --resource-group $env:resourceGroup --name $kubeEnvironmentName --custom-location $customLocationId --static-ip "$staticIp" --location $env:azureLocation --output none 

Do {
   Write-Host "Waiting for kube environment to become available. Hold tight, this might take a few minutes..."
   Start-Sleep -Seconds 1
   $kubeEnvironmentNameStatus = $(if(az appservice kube show --resource-group $env:resourceGroup --name $kubeEnvironmentName | Select-String '"provisioningState": "Succeeded"' -Quiet){"Ready!"}Else{"Nope"})
   } while ($kubeEnvironmentNameStatus -eq "Nope")

Write-Host "Creating App Service plan. Hold tight, this might take a few minutes..."
Write-Host "`n"
$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
az appservice plan create -g $env:resourceGroup -n Jumpstart --custom-location $customLocationId --per-site-scaling --is-linux --sku K1

Write-Host "Deploy Azure sample Web App plan"
Write-Host "`n"
az webapp create --plan Jumpstart --resource-group $env:resourceGroup --name jumpstart-app --custom-location $customLocationId --deployment-container-image-name mcr.microsoft.com/appsvc/node:12-lts
