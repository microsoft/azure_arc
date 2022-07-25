
write-host -ForegroundColor Green -Object "Register the Cluster to Azure Subscription"
#Variables
$adcred=Get-Credential -UserName "contoso\administrator" -Message "Provide AD Account Password"

#Azure Account Info
  #install modules
       Write-Host "Installing Required Modules" -ForegroundColor Green -BackgroundColor Black
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-WindowsFeature -name RSAT-Clustering-Powershell
        $ModuleNames="Az.Resources","Az.Accounts", "Az.stackhci"
        foreach ($ModuleName in $ModuleNames){
            if (!(Get-InstalledModule -Name $ModuleName -ErrorAction Ignore)){
                Install-Module -Name $ModuleName -Force
            }
        }




#login to Azure
        $azcred=Get-AzContext

        if (-not (Get-AzContext)){
            $azcred=Login-AzAccount -UseDeviceAuthentication
        }

    #select context
        $context=Get-AzContext -ListAvailable
        if (($context).count -gt 1){
            $context=$context | Out-GridView -OutputMode Single
            $context | Set-AzContext
        }

    #location (all locations where HostPool can be created)
        $region=(Get-AzLocation | Where-Object Providers -Contains "Microsoft.DesktopVirtualization" | Out-GridView -OutputMode Single -Title "Please select Location for AVD Host Pool metadata").Location

#Register the Cluster
Write-Host "Registering the Cluster" -ForegroundColor Green -BackgroundColor Black
$armtoken = Get-AzAccessToken
$graphtoken = Get-AzAccessToken -ResourceTypeName AadGraph
$clustername=Get-Cluster
Register-AzStackHCI -SubscriptionId $context.Subscription.Id -ComputerName azshost1 -AccountId $context.Account.Id -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token -EnableAzureArcServer -Credential $adcred -Region $region -ResourceName $clustername.Name
    