# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-DataSvcs.log

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
Write-Header 'Creating credentials and connecting to Azure'
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential

$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred
$context = Get-AzContext # Azure credential

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes -Confirm:$false
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration -Confirm:$false

# Install latest versions of Nuget and PowershellGet
Write-Header "Install latest versions of Nuget and PowershellGet"
Invoke-Command -VMName $SDNConfig.HostList -Credential $adcred -ScriptBlock {
    Enable-PSRemoting -Force
    Install-PackageProvider -Name NuGet -Force 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module -Name PowershellGet -Force
}

# Install necessary AZ modules and initialize akshci on each node
Write-Header "Install necessary AZ modules, AZ CLI extensions, plus AksHCI module and initialize akshci on each node"

Invoke-Command -VMName $SDNConfig.HostList  -Credential $adcred -ScriptBlock {
    Write-Host "Installing Required Modules"
    Install-Module -Name AksHci -Force -AcceptLicense
    Import-Module Az.Accounts
    Import-Module Az.Resources
    Import-Module AzureAD
    Import-Module AksHci
    Initialize-AksHciNode
    Write-Host "Installing Azure CLI"
    $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
    az config set extension.use_dynamic_install=yes_without_prompt
    az extension add --name arcdata --system
}

# Generate unique name for workload cluster
$rand = New-Object System.Random
$prefixLen = 5
[string]$namingPrefix = ''
for ($i = 0; $i -lt $prefixLen; $i++) {
    $namingPrefix += [char]$rand.Next(97, 122)
}
$clusterName = $SDNConfig.AKSDataSvcsworkloadClusterName + "-" + $namingPrefix
[System.Environment]::SetEnvironmentVariable('AKS-DataSvcs-ClusterName', $clusterName, [System.EnvironmentVariableTarget]::Machine)

# Create new AKS target cluster and connect it to Azure
Write-Header "Creating AKS target cluster"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    New-AksHciCluster -name $using:clusterName -nodePoolName sqlminodepool -nodecount 3 -osType linux -nodeVmSize Standard_D4s_v3
    Enable-AksHciArcConnection -name $using:clusterName
}

Write-Header "Checking AKS-HCI nodes and running pods"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl get nodes
    kubectl get pods -A
}

# Deploy data services
<#Write-Header "Installing Azure Data Studio extensions"
Invoke-Command -VMName $SDNConfig.HostList  -Credential $adcred -ScriptBlock {
    # Installing Azure Data Studio extensions
    $Env:argument1 = "--install-extension"
    $Env:argument2 = "microsoft.azcli"
    $Env:argument3 = "Microsoft.arc"

    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument2
    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument3

    # Create Azure Data Studio desktop shortcut
    Write-Header "Creating Azure Data Studio Desktop Shortcut"
    $TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
    $ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Azure Data Studio.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()

    # Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut
    Write-Host "`n"
    Write-Host "Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut"
    Write-Host "`n"
    $TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\ssms.exe"
    $ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio 18.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
}
#>

# Installing the Azure Arc-enabled data services cluster extension
Write-Host "Installing the Azure Arc-enabled data services cluster extension"
Invoke-Command -VMName $SDNConfig.HostList[0]  -Credential $adcred -ScriptBlock {
    $kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } }
    az k8s-extension create --name arc-data-services `
        --extension-type microsoft.arcdataservices `
        --cluster-type connectedClusters `
        --cluster-name $clusterName `
        --resource-group $Env:resourceGroup `
        --auto-upgrade false `
        --scope cluster `
        --release-namespace arc `
        --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

    Write-Host "`n"

    Do {
        Write-Host "Waiting for bootstrapper pod, hold tight..."
        Start-Sleep -Seconds 20
        $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($podStatus -eq "Nope")
    Write-Host "Bootstrapper pod is ready!"
    Write-Host "`n"
}

# Downloading ARM templates for Azure Arc Data Controller
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:HCIBoxKVDir\dataController.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:HCIBoxKVDir\dataController.parameters.json
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.json" -DestinationPath "C:\VHD\dataController.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.parameters.json" -DestinationPath "C:\VHD\dataController.parameters.json" -FileSource Host


# Configuring Azure Arc Custom Location on the cluster
Write-Header "Configuring Azure Arc Custom Location"
Invoke-Command -VMName $SDNConfig.HostList[0]  -Credential $adcred -ScriptBlock {

    $connectedClusterId = az connectedk8s show --name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
    $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $clusterName --resource-group $Env:resourceGroup --query id -o tsv
    Start-Sleep -Seconds 20
    az customlocation create --name "jumpstart-cl" --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId
    Write-Header "Deploying Azure Arc Data Controller"

    $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $Env:resourceGroup --query id -o tsv)

    $workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)

    $dataControllerParams = "C:\VHD\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', "arcbox-dc" | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $Env:AZDATA_USERNAME | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $Env:AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $Env:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $Env:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $Env:spnClientSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

    az deployment group create --resource-group $Env:resourceGroup --template-file "C:\VHD\dataController.json" --parameters "C:\VHD\dataController.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc data controller is ready!"
    Write-Host "`n"
}

# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deploySQLMI', 'true', [System.EnvironmentVariableTarget]::Machine)

Stop-Transcript