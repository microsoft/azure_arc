Start-Transcript -Path C:\Temp\globalConfig.log

# Declaring the deployment environment (Production/Dev)
$deploymentEnvironment = ($Env:templateBaseUrl | Select-String "microsoft/azure_arc/main")

# Declaring if this is a Jumpstart scenario or ArcBox deployment
if ($null -eq $Env:flavor -eq $true){
    $jumpstartDeployment = "Jumpstart scenario"
} else {
    $jumpstartDeployment = "Jumpstart ArcBox"
}

# Setting up the environment variable for the Jumpstart App Configuration connection string deployment (Production/Dev)
$jumpstartAppConfigProduction = "Endpoint=https://jumpstart-prod.azconfig.io;Id=xcEf-l6-s0:Fn+IoFEzNKvm/Bo0+W1I;Secret=dkuO3eUhqccYw6YWkFYNcPMZ/XYQ4r9B/4OhrWTLtL0="
$jumpstartAppConfigDev = "Endpoint=https://jumpstart-dev.azconfig.io;Id=5xh8-l6-s0:q89J0MWp2twZnTsqoiLQ;Secret=y5UFAWzPNdJsPcRlKC538DimC4/nb1k3bKuzaLC90f8="

if ($null -eq $deploymentEnvironment -eq $false){
    $Env:AZURE_APPCONFIG_CONNECTION_STRING = $jumpstartAppConfigProduction
    $deploymentEnvironment = "Production"
    Write-Host "`n"
    Write-Host "This is a $jumpstartDeployment $deploymentEnvironment deployment!"
} else {
    $Env:AZURE_APPCONFIG_CONNECTION_STRING = $jumpstartAppConfigDev
    $deploymentEnvironment = "Dev"
    Write-Host "`n"
    Write-Host "This is a $jumpstartDeployment $deploymentEnvironment deployment!"
}

# Declaring required Azure Arc resource providers
$providersArcKubernetes = (az appconfig kv list --key "providersArcKubernetes" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")
$providersArcDataSvc = (az appconfig kv list --key "providersArcDataSvc" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")
$providersArcAppSvc = (az appconfig kv list --key "providersArcAppSvc" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")
$allArcProviders = $providersArcKubernetes + $providersArcDataSvc + $providersArcAppSvc

# Declaring required Azure Arc Azure CLI extensions
$kubernetesExtensions = (az appconfig kv list --key "kubernetesExtensions" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")
$dataSvcExtensions = (az appconfig kv list --key "dataSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")
$appSvcExtensions = (az appconfig kv list --key "appSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv).split(" ")

# Global Jumpstart PowerShell functions - Azure resource providers
function Register-ArcKubernetesProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled Kubernetes resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled Kubernetes resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcKubernetes environment variables
    #>
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

function Register-ArcDataSvcProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled data services resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled data services resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcDataSvc environment variables
    #>
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

function Register-ArcAppSvcProviders {
    <#
        .SYNOPSIS
        PowerShell function for registering Azure Arc-enabled app services resource providers
        
        .DESCRIPTION
        PowerShell function for registering Azure Arc-enabled app services resource providers required in Jumpstart Kubernetes-based automation.
        Depended on the $providersArcDataSvc environment variables
    #>
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

# Global Jumpstart PowerShell functions - Azure CLI extensions

function Install-ArcK8sCLIExtensions {
	<#
        .SYNOPSIS
        PowerShell function for installing Azure Arc-enabled Kubernetes Azure CLI extensions
        
        .DESCRIPTION
        PowerShell function for installing Azure Arc-enabled Kubernetes Azure CLI extensions required in Jumpstart Kubernetes-based automation.
        Depended on the $kubernetesExtensions environment variables
    #>
    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    Write-Host "`n"
    # Installing Azure CLI extensions
    foreach ($extension in $kubernetesExtensions) {
        $version = (az appconfig kv list --key $extension --label $deploymentEnvironment --query "[].value" -o tsv)
        az extension add --name $extension --version $version -y
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
    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    Write-Host "`n"
    # Installing Azure CLI extensions
    foreach ($extension in $dataSvcExtensions) {
        $version = (az appconfig kv list --key $extension --label $deploymentEnvironment --query "[].value" -o tsv)
        az extension add --name $extension --version $version -y
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
    Write-Host "`n"
    Write-Host "Installing Azure CLI extensions for $service"
    Write-Host "`n"
    # Installing Azure CLI extensions
    foreach ($extension in $appSvcExtensions) {
        $version = (az appconfig kv list --key $extension --label $deploymentEnvironment --query "[].value" -o tsv)
        az extension add --name $extension --version $version -y
    }
}

# Making extension installation dynamic
az config set extension.use_dynamic_install=yes_without_prompt

# Determining which Kubernetes distributions is being used
if ($jumpstartDeployment -eq "Jumpstart scenario"){
    $clusterTypeAKS = (az resource list --resource-group $Env:resourceGroup --resource-type "Microsoft.ContainerService/managedClusters" --query "[].type" -o tsv)
    $clusterTypeARO = (az resource list --resource-group $Env:resourceGroup --resource-type "Microsoft.RedHatOpenShift/openShiftClusters" --query "[].type" -o tsv)
}

# Required for Jumpstart scenarios which are based on ##EITHER OF## the following Kubernetes distributions:
#   - Azure Kubernetes Service (AKS)
#   - Azure RedHat OpenShift (ARO)
if ($jumpstartDeployment -eq "Jumpstart scenario" -and $null -eq $Env:clusterName -eq $false -and $null -eq $clusterTypeAKS -eq $false -or $null -eq $clusterTypeARO -eq $false){
    # Installing needed providers and CLI extensions for all Azure Arc-enabled Kubernetes-based automations
    $service = "Azure Arc-enabled Kubernetes"
    Register-ArcKubernetesProviders
    Install-ArcK8sCLIExtensions
}

# Required for Jumpstart scenarios which are based on Kubernetes distribution ##that is NOT## one the following Kubernetes distributions:
#   - Azure Kubernetes Service (AKS)
#   - Azure RedHat OpenShift (ARO)
if ($jumpstartDeployment -eq "Jumpstart scenario" -and $null -eq $Env:clusterName -eq $false -and $null -eq $clusterTypeAKS -eq $true -or $null -eq $clusterTypeARO -eq $true){
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
    Install-ArcAppSvcCLIExtensions
}

# Showing the output of registered resource providers and Azure CLI installed extensions
foreach ($provider in $allArcProviders){
    az provider show --namespace $provider --query "{Namespace:namespace, RegistrationState:registrationState}" -o table
    Write-Host "`n"
}

Write-Host "`n"
az -v
