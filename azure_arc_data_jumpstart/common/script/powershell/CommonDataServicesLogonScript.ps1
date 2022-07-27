param (
    [string[]] $extraAzExtensions = @(),
    [switch] $notInstallK8extensions

)
Write-Output "Common DataServicesLogonScript"

# Function repository
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
function DeployingAzureArcDataController {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUsernameAndPasswordParams", "")]
    param (
        [string]$resourceGroup,
        [string]$directory,
        [string]$workspaceName,
        [string]$AZDATA_USERNAME,
        [string]$AZDATA_PASSWORD,
        [string]$spnClientId,
        [string]$spnTenantId,
        [string]$spnClientSecret,
        [string]$subscriptionId
    )
    $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $resourceGroup --query id -o tsv)
    $workspaceId = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName --query primarySharedKey -o tsv)

    $dataControllerParams = "$directory\dataController.parameters.json"

    (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $resourceGroup | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $AZDATA_USERNAME | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $subscriptionId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $spnClientId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $spnTenantId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $spnClientSecret | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
    (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

    az deployment group create --resource-group $resourceGroup `
        --template-file "$directory\dataController.json" `
        --parameters "$directory\dataController.parameters.json"

    Write-Output "`n"
    Do {
        Write-Output "Waiting for data controller. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")

    Write-Output "`n"
    Write-Output "Azure Arc data controller is ready!"
    Write-Output "`n"
}
function EnablingDataControllerAutoMetrics {
    param (
        [string]$resourceGroup,
        [string]$workspaceName
    )
    Write-Output "`n"
    Write-Output "Enabling data controller auto metrics & logs upload to log analytics"
    Write-Output "`n"
    $Env:WORKSPACE_ID = $(az resource show --resource-group $resourceGroup --name $workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $Env:WORKSPACE_SHARED_KEY = $(az monitor log-analytics workspace get-shared-keys --resource-group $resourceGroup --workspace-name $workspaceName  --query primarySharedKey -o tsv)
    az arcdata dc update --name jumpstart-dc --resource-group $resourceGroup --auto-upload-logs true
    az arcdata dc update --name jumpstart-dc --resource-group $resourceGroup --auto-upload-metrics true
}
function CopyingAzureDataStudioSettingsRemplateFile {
    param (
        [string]$adminUsername,
        [string]$directory
    )
    Write-Output "`n"
    Write-Output "Copying Azure Data Studio settings template file"
    New-Item -Path "C:\Users\$adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
    Copy-Item -Path "$directory\settingsTemplate.json" -Destination "C:\Users\$adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
}
function Add-URL-Shortcut-Desktop {
    param (
        [string]$url,
        [string]$name,
        [string]$USERPROFILE
    )
    $Shell = New-Object -ComObject ("WScript.Shell")
    $Favorite = $Shell.CreateShortcut($USERPROFILE + "\Desktop\$name.url")
    $Favorite.TargetPath = $url;
    $Favorite.Save()
}
function ChangingToClientVMWallpaper {
    param (
        [string]$directory
    )

    $imgPath = "$directory\wallpaper.png"
    $code = @'
using System.Runtime.InteropServices;
namespace Win32{

     public class Wallpaper{
        [DllImport("user32.dll", CharSet=CharSet.Auto)]
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ;

         public static void SetWallpaper(string thePath){
            SystemParametersInfo(20,0,thePath,3);
         }
    }
 }
'@

    add-type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)
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