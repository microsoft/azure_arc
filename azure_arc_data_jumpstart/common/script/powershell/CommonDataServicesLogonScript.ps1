param (
    [string[]] $extraAzExtensions = @(),
    [switch] $notInstallK8extensions

)
Write-Output "Common DataServicesLogonScript"

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Login as service principal
az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

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