param (
    [string[]] $extraAzExtensions = @(),
    [switch] $notInstallK8extensions

)
Write-Output "Common DataServicesLogonScript"

# Function repository1
function SetDefaultSubscription {
    param (
        [string]$subscriptionId
    )
    # Set default subscription to run commands against
    # "subscriptionId" value comes from clientVM.json ARM template, based on which
    # subscription user deployed ARM template to. This is needed in case Service
    # Principal has access to multiple subscriptions, which can break the automation logic
    az account set --subscription $subscriptionId
}
function InstallingAzureDataStudioExtensions([string[]]$azureDataStudioExtensions) {
    Write-Output "`n"
    Write-Output "Installing Azure Data Studio Extensions"
    Write-Output "`n"
    $Env:argument1 = "--install-extension"
    foreach ($extension in $azureDataStudioExtensions) {
        Write-Output "Installing Arc Data Studio extention: $extension"
        & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $extension
    }
}
function RegisteringAzureArcProviders([string[]]$arcProviderList) {
    Write-Output "Registering Azure Arc providers, hold tight..."
    Write-Output "`n"
    foreach ($app in $arcProviderList) {
        Write-Output "Installing $app"
        az provider register --namespace "Microsoft.$app" --wait
    }
    foreach ($app in $arcProviderList) {
        Write-Output "`n"
        az provider show --namespace "Microsoft.$app" -o table
    }
}
function InstallingAzureArcEnabledDataServicesExtension {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [string]$connectedClusterName,
        [string]$resourceGroup
    )
    az k8s-extension create --name arc-data-services `
        --extension-type microsoft.arcdataservices `
        --cluster-type connectedClusters `
        --cluster-name $connectedClusterName `
        --resource-group $resourceGroup `
        --auto-upgrade false `
        --scope cluster `
        --release-namespace arc `
        --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper `

    Write-Host "`n"
    Do {
        Write-Host  "Waiting for bootstrapper pod, hold tight...(20s sleeping loop)"
        Start-Sleep -Seconds 20
        $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
        Write-Host "Pod status $podStatus"
    } while ($podStatus -eq "Nope")

    $connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $resourceGroup --query id -o tsv
    $extensionId = az k8s-extension show --name arc-data-services `
        --cluster-type connectedClusters `
        --cluster-name $connectedClusterName `
        --resource-group $resourceGroup `
        --query id -o tsv
    Start-Sleep -Seconds 20
    return  $connectedClusterId, $extensionId
}
function CreateCustomLocation {
    param (
        [string]$resourceGroup,
        [string]$connectedClusterId,
        [string]$extensionId,
        [string]$KUBECONFIG
    )
    # Create Custom Location
    az customlocation create --name 'jumpstart-cl' `
        --resource-group $resourceGroup `
        --namespace arc `
        --host-resource-id $connectedClusterId `
        --cluster-extension-ids $extensionId `
        --kubeconfig $KUBECONFIG
}

# Main script
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt

Write-Output "Az cli version"
az -v

Write-Output "Installing Azure CLI extensions"
if ($notInstallK8extensions) {
    $k8extensions = @()
}
else {
    $k8extensions = @("connectedk8s", "k8s-extension")
}
$az_extensions = $extraAzExtensions + $k8extensions + @("arcdata")
foreach ($az_extension in $az_extensions) {
    Write-Output "Instaling $az_extension"
    az extension add --name $az_extension
}