Start-Transcript -Path C:\Temp\globalArtifacts.log

# Installing needed providers and CLI extensions for Azure Are-enabled app services
if ( $Env:resourceTags -eq "jumpstart_azure_arc_app_services" ){
    Write-Host "`n"
    Write-Host "Registering Azure Arc providers, hold tight..."
    Write-Host "`n"
    az provider register --namespace Microsoft.Kubernetes --wait
    az provider register --namespace Microsoft.KubernetesConfiguration --wait
    az provider register --namespace Microsoft.ExtendedLocation --wait
    az provider register --namespace Microsoft.Web --wait
    
    az provider show --namespace Microsoft.Kubernetes -o table
    Write-Host "`n"
    az provider show --namespace Microsoft.KubernetesConfiguration -o table
    Write-Host "`n"
    az provider show --namespace Microsoft.ExtendedLocation -o table
    Write-Host "`n"
    az provider show --namespace Microsoft.Web -o table
    Write-Host "`n"

    # Making extension install dynamic
    az config set extension.use_dynamic_install=yes_without_prompt
    # Installing Azure CLI extensions
    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions"
    az extension add --name "connectedk8s" -y
    az extension add --name "k8s-configuration" -y
    az extension add --name "k8s-extension" -y
    az extension add --name "customlocation" -y
    az extension add --name "appservice-kube" -y
    Write-Host "`n"
    az -v
}
