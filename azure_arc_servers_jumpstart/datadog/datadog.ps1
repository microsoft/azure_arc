###########################################
##             Variables                 ##
###########################################

$resourceGroup = "Arc-Datadog-Demo"
$machineName = "Arc-Linux-Demo"
$location = "westeurope"
$osType = "Linux" # change to Linux if appropriate
$datadog_site = "datadoghq.eu"
$datadog_api_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$app_Id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$app_secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$tenantId = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$subscription_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"


###########################################
##             Script                    ##
###########################################

$userPassword = ConvertTo-SecureString -String $app_secret -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($app_Id, $userPassword)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

Set-AzContext -Subscription $subscription_id

$settings = @{
    # change to your preferred Datadog site
    site = $datadog_site
}
$protectedSettings = @{
    # change to your Datadog API key
    api_key = $datadog_api_key
}


New-AzConnectedMachineExtension -ResourceGroupName $resourceGroup -Location $location -MachineName $machineName -Name "Datadog$($osType)Agent" -Publisher "Datadog.Agent" -ExtensionType "Datadog$($osType)Agent" -Setting $settings -ProtectedSetting $protectedSettings