$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile

Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Register-AzSHCI.log"

$user = $env:adminUsername
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

Write-Host "Installing Required Modules" -ForegroundColor Green -BackgroundColor Black
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-WindowsFeature -name RSAT-Clustering-Powershell
$ModuleNames =  "Az.Accounts", "Az.stackhci"
foreach ($ModuleName in $ModuleNames) {
    Install-Module -Name $ModuleName -Force
}

# Required for CLI commands
Write-Host "Az Login"
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred

#Register the Cluster
Write-Host "Registering the Cluster" -ForegroundColor Green -BackgroundColor Black
$armtoken = Get-AzAccessToken
$clustername = 'HCIBox-Cluster'
$azureLocation = 'eastus'
Register-AzStackHCI -SubscriptionId $env:subscriptionId -ComputerName $HCIBoxConfig.NodeHostConfig[0].Hostname -AccountId $env:spnClientID -ArmAccessToken $armtoken.Token -Credential $adcred -Region $azureLocation -ResourceName $clustername -ResourceGroupName $env:resourceGroup
Move-Item -Path RegisterHCI_* -Destination "$($HCIBoxConfig.Paths.LogsDir)\RegisterHCI_PS_Output.log"

Write-Host "$clustername successfully registered as Az Stack HCI cluster resource in Azure"

# Set up cluster cloud witness
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$storageKey = Get-AzStorageAccountKey -Name $env:stagingStorageAccountName -ResourceGroup $env:resourceGroup
$saName = $env:stagingStorageAccountName
Invoke-Command -VMName $HCIBoxConfig.NodeHostConfig[0].Hostname -Credential $adcred -ScriptBlock {
    Set-ClusterQuorum -Cluster "hciboxcluster" -CloudWitness -AccountName $using:saName -AccessKey $using:storageKey[0].value
}

# Install Az CLI and extensions on each node
foreach ($AzSHOST in $HCIBoxConfig.NodeHostConfig) {
    Invoke-Command -VMName $AzSHOST.Hostname -Credential $adcred -ScriptBlock {
        Write-Verbose "Installing Az CLI on $($AzSHOST.Hostname)"
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi;
        Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet';
        Start-Sleep -Seconds 30
        $ProgressPreference = "Continue"
    }
}
Stop-Transcript