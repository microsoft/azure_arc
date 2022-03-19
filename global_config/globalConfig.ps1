Start-Transcript -Path C:\Temp\globalConfig.log

# Declaring required Azure Arc resource providers
$providersArcKubernetes = "Microsoft.Kubernetes", "Microsoft.KubernetesConfiguration", "Microsoft.ExtendedLocation"
$providersArcDataSvc = "Microsoft.AzureArcData"
$providersArcAppSvc = "Microsoft.Web"

# Declaring required Azure Arc Azure CLI extensions
$kubernetesExtensions = "connectedk8s", "k8s-configuration", "k8s-extension", "customlocation"
$dataSvcExtensions = "arcdata"
$appSvcExtensions = "appservice-kube"

# Global Jumpstart PowerShell functions

function Register-ArcKubernetesProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled Kubernetes resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled Kubernetes resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcKubernetes environment variables
    #>
	[CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$providersArcKubernetes

    Write-Host "`n"
    Write-Host "Checking $service Azure resource provider registration state"
    Write-Host "`n"
    foreach ($provider in $providersArcKubernetes){
        $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
        if ($registrationState -eq "Registered"){
            Write-Host "$provider Azure resource provider is already registered"
        } else {
            Write-Host "`n"
            Write-Host "$provider Azure resource provider is not registered. Registering, hold tight..." 
            az provider register --namespace $provider
            
            while ($registrationState -ne "Registered"){
                Start-Sleep -Seconds 5
                Write-Host "$provider Azure resource provider is still regitering, hold tight..."
                $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
            }
            Write-Host "$provider Azure resource provider is now registered"
            Write-Host "`n"
            }
    }
}

function Install-ArcK8sCLIExtensions {
	<#
        .SYNOPSIS
        PowerShell function for installing Azure Arc-enabled Kubernetes Azure CLI extensions
        
        .DESCRIPTION
        PowerShell function for installing Azure Arc-enabled Kubernetes Azure CLI extensions required in Jumpstart Kubernetes-based automation.
        Depended on the $kubernetesExtensions environment variables
    #>
    [CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$kubernetesExtensions

    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    # Installing Azure CLI extensions
    foreach ($extension in $kubernetesExtensions) {
        az extension add --name $extension -y
    }
}

function Register-ArcDataSvcProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled data services resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled data services resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcDataSvc environment variables
    #>
    [CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$providersArcDataSvc

    Write-Host "`n"
    Write-Host "Checking $service Azure resource provider registration state"
    Write-Host "`n"
    foreach ($provider in $providersArcDataSvc){
        $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
        if ($registrationState -eq "Registered"){
            Write-Host "$provider Azure resource provider is already registered"
        } else {
            Write-Host "`n"
            Write-Host "$provider Azure resource provider is not registered. Registering, hold tight..." 
            az provider register --namespace $provider
            
            while ($registrationState -ne "Registered"){
                Start-Sleep -Seconds 5
                Write-Host "$provider Azure resource provider is still regitering, hold tight..."
                $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
            }
            Write-Host "$provider Azure resource provider is now registered"
            Write-Host "`n"
            }
    }
}

function Install-ArcDataSvcCLIExtensions {
    <#
        .SYNOPSIS
        PowerShell function for installing Azure Arc-enabled data services Azure CLI extensions
        
        .DESCRIPTION
        PowerShell function for installing Azure Arc-enabled data services Azure CLI extensions required in Jumpstart Kubernetes-based automation.
        Depended on the $dataSvcExtensions environment variables
    #>
    [CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$dataSvcExtensions

    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    # Installing Azure CLI extensions
    foreach ($extension in $dataSvcExtensions) {
        az extension add --name $extension -y
    }
}

function Register-ArcAppSvcProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled app services resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled app services resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcDataSvc environment variables
    #>
    [CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$providersArcAppSvc

    Write-Host "`n"
    Write-Host "Checking $service Azure resource provider registration state"
    Write-Host "`n"
    foreach ($provider in $providersArcAppSvc){
        $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
        if ($registrationState -eq "Registered"){
            Write-Host "$provider Azure resource provider is already registered"
        } else {
            Write-Host "`n"
            Write-Host "$provider Azure resource provider is not registered. Registering, hold tight..." 
            az provider register --namespace $provider
            
            while ($registrationState -ne "Registered"){
                Start-Sleep -Seconds 5
                Write-Host "$provider Azure resource provider is still regitering, hold tight..."
                $registrationState = (az provider show --namespace $provider --query registrationState -o tsv)
            }
            Write-Host "$provider Azure resource provider is now registered"
            Write-Host "`n"
            }
    }
}

function Install-ArcAppSvcCLIExtensions {
    <#
        .SYNOPSIS
        PowerShell function for installing Azure Arc-enabled app services Azure CLI extensions
        
        .DESCRIPTION
        PowerShell function for installing Azure Arc-enabled app services Azure CLI extensions required in Jumpstart Kubernetes-based automation.
        Depended on the $appSvcExtensions environment variables
    #>	
    [CmdletBinding()]
    [Parameter(Mandatory)]
    [string]$appSvcExtensions

    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    # Installing Azure CLI extensions
    foreach ($extension in $appSvcExtensions) {
        az extension add --name $extension -y
    }
}

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt

# Determining which Kubernetes distributions is being used
if ($Env:flavor -eq $null -eq $true) {
    $clusterTypeAKS = (az resource list --resource-group $Env:resourceGroup --resource-type "Microsoft.ContainerService/managedClusters" --query "[].type" -o tsv)
    $clusterTypeARO = (az resource list --resource-group $Env:resourceGroup --resource-type "Microsoft.RedHatOpenShift/openShiftClusters" --query "[].type" -o tsv)
}

# Required for Jumpstart scenarios which are based on EITHER OF the following Kubernetes distributions:
#   - Azure Kubernetes Service (AKS)
#   - Azure RedHat OpenShift (ARO)
if ($Env:flavor -eq $null -eq $true -and $Env:clusterName -eq $null -eq $false -and $clusterTypeAKS -eq $null -eq $false -or $clusterTypeARO -eq $null -eq $false){
    # Installing needed providers and CLI extensions for all Azure Arc-enabled Kubernetes-based automations
    $service = "Azure Arc-enabled Kubernetes"
    Register-ArcKubernetesProviders
    Install-ArcK8sCLIExtensions
}

# Required for Jumpstart scenarios which are based on Kubernetes distribution that is NOT one the following Kubernetes distributions:
#   - Azure Kubernetes Service (AKS)
#   - Azure RedHat OpenShift (ARO)
if ($Env:flavor -eq $null -eq $true -and $Env:clusterName -eq $null -eq $false -and $clusterTypeAKS -eq $null -eq $true -or $clusterTypeARO -eq $null -eq $true){
    # Installing Azure CLI extensions
    Install-ArcK8sCLIExtensions
}

# Installing needed resource providers and CLI extensions for Azure Arc-enabled data services
if (Test-Path -Path 'C:\Temp\DataServicesLogonScript.ps1'){
    $service = "Azure Arc-enabled data services"
    Register-ArcDataSvcProviders
    Install-ArcDataSvcCLIExtensions
}

# Installing needed resource providers and CLI extensions for Azure Arc-enabled app services
if (Test-Path -Path 'C:\Temp\AppServicesLogonScript.ps1'){
    $service = "Azure Arc-enabled app services"
    Register-ArcAppSvcProviders
    Install-ArcDataSvcCLIExtensions
}

Write-Host "`n"
az -v
