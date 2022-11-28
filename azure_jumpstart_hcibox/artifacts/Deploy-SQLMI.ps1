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
}
# Initializing variables
$subId = $env:subscriptionId
$rg = $env:resourceGroup
$spnClientId = $env:spnClientId
$spnSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$adminUsername = $env:adminUsername
$adminPassword = $env:adminPassword
$workspaceName = $env:workspaceName
$customLocationObjectId = $env:customLocationObjectId

# Downloading artifacts for Azure Arc Data Controller
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.json") -OutFile $Env:HCIBoxKVDir\dataController.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile $Env:HCIBoxKVDir\dataController.parameters.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmi.json") -OutFile $Env:HCIBoxKVDir\sqlmi.json
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmi.parameters.json") -OutFile $Env:HCIBoxKVDir\sqlmi.parameters.json
Invoke-WebRequest ("https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable") -OutFile $Env:HCIBoxKVDir\azuredatastudio.zip

Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.json" -DestinationPath "C:\VHD\dataController.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\dataController.parameters.json" -DestinationPath "C:\VHD\dataController.parameters.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\sqlmi.json" -DestinationPath "C:\VHD\sqlmi.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\sqlmi.parameters.json" -DestinationPath "C:\VHD\sqlmi.parameters.json" -FileSource Host
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\azuredatastudio.zip" -DestinationPath "C:\VHD\azuredatastudio.zip" -FileSource Host

# Install Azure Data Studio
Invoke-Command -ComputerName admincenter -Credential $adcred -ScriptBlock {
    Write-Host "Installing Azure Data Studio"
    Expand-Archive "C:\VHD\azuredatastudio.zip" -DestinationPath 'C:\Program Files\Azure Data Studio'
    Start-Process msiexec.exe -Wait -ArgumentList "/I C:\VHD\AZDataCLI.msi /quiet"
    Write-Host "Installing Azure Data Studio extensions"
    $Env:argument1 = "--install-extension"
    $Env:argument2 = "microsoft.azcli"
    $Env:argument3 = "Microsoft.arc"

    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument2
    & "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $Env:argument1 $Env:argument3

    # Create Azure Data Studio desktop shortcut
    Write-Host "Creating Azure Data Studio Desktop Shortcut"
    $TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
    $ShortcutFile = "C:\Users\$using:adminUsername\Desktop\Azure Data Studio.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
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

# Installing the Azure Arc-enabled data services cluster extension
Write-Host "Installing the Azure Arc-enabled data services cluster extension"
foreach ($VM in $SDNConfig.HostList) {
    Invoke-Command -VMName $VM -Credential $adcred -ScriptBlock {
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path + ";C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin", [System.EnvironmentVariableTarget]::Machine)
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $ErrorActionPreference = "Continue"
        az config set extension.use_dynamic_install=yes_without_prompt
        az login --service-principal --username $using:spnClientID --password $using:spnSecret --tenant $using:spnTenantId
        az extension add --name arcdata --system
    }
}

# Deploying the Arc Data Controller
Write-Host "Deploying the Arc Data Controller"
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock {
    #$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n arc; Start-Sleep -Seconds 5; Clear-Host } }
    az k8s-extension create --name arc-data-services `
        --extension-type microsoft.arcdataservices `
        --cluster-type connectedClusters `
        --cluster-name $using:clusterName `
        --resource-group $using:rg `
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

# Configuring Azure Arc Custom Location on the cluster
Write-Header "Configuring Azure Arc Custom Location"
Invoke-Command -VMName $SDNConfig.HostList[0]  -Credential $adcred -ScriptBlock {

    $connectedClusterId = az connectedk8s show --name $using:clusterName --resource-group $using:rg --query id -o tsv
    az connectedk8s enable-features -n $using:clusterName -g $using:rg --custom-locations-oid $using:customLocationObjectId --features cluster-connect custom-locations
    $extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $using:clusterName --resource-group $using:rg --query id -o tsv
    Start-Sleep -Seconds 20
    az customlocation create --name "jumpstart-cl" --resource-group $using:rg --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId
    Write-Header "Deploying Azure Arc Data Controller"

    $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $using:rg --query id -o tsv)

    $workspaceId = $(az resource show --resource-group $using:rg --name $using:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
    $workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $using:rg --workspace-name $using:workspaceName --query primarySharedKey -o tsv)

    $dataControllerParams = "C:\VHD\dataController.parameters.json"

(Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', "arcbox-dc" | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $using:rg | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $using:adminUsername | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $using:adminPassword | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $using:subId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientId-stage', $using:spnClientId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnTenantId-stage', $using:spnTenantId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'spnClientSecret-stage', $using:spnSecret | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
(Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams

    az deployment group create --resource-group $using:rg --template-file "C:\VHD\dataController.json" --parameters "C:\VHD\dataController.parameters.json"
    Write-Host "`n"

    Do {
        Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc data controller is ready!"
    Write-Host "`n"
}

# Deploying the Azure Arc-enabled SQL Managed Instance
Write-Host "Deploying the Azure Arc-enabled SQL Managed Instance"
Invoke-Command -VMName $SDNConfig.HostList[0]  -Credential $adcred -ScriptBlock {
    $controllerName = "arcbox-dc" # This value needs to match the value of the data controller name as set by the ARM template deployment.
    $sqlInstanceName = "jumpstart-sql"
    
    # Deploying Azure Arc SQL Managed Instance
    Write-Host "`n"
    Write-Host "Deploying Azure Arc SQL Managed Instance"
    Write-Host "`n"
    
    $dataControllerId = $(az resource show --resource-group $using:rg --name $controllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
    $customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $using:rg --query id -o tsv)
    
    ################################################
    # Localize ARM template
    ################################################
    $ServiceType = "LoadBalancer"
    $readableSecondaries = $ServiceType
    
    # Resource Requests
    $vCoresRequest = "2"
    $memoryRequest = "4Gi"
    $vCoresLimit = "4"
    $memoryLimit = "8Gi"
    
    # Storage
    $StorageClassName = "default"
    $dataStorageSize = "5Gi"
    $logsStorageSize = "5Gi"
    $dataLogsStorageSize = "5Gi"
    
    # High Availability
    $replicas = 3 # Deploy SQL MI "Business Critical" tier
    #######################################################
    
    $SQLParams = "C:\VHD\SQLMI.parameters.json"
    
    (Get-Content -Path $SQLParams) -replace 'resourceGroup-stage', $using:rg | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataControllerId-stage', $dataControllerId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'customLocation-stage', $customLocationId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'subscriptionId-stage', $using:subId | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'azdataUsername-stage', $using:adminUsername | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'azdataPassword-stage', $using:adminPassword | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'serviceType-stage', $ServiceType | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'readableSecondaries-stage', $readableSecondaries | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'vCoresRequest-stage', $vCoresRequest | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'memoryRequest-stage', $memoryRequest | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'vCoresLimit-stage', $vCoresLimit | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'memoryLimit-stage', $memoryLimit | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'logsStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataLogStorageClassName-stage', $StorageClassName | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataSize-stage', $dataStorageSize | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'logsSize-stage', $logsStorageSize | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'dataLogSize-stage', $dataLogsStorageSize | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'replicasStage' , $replicas | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'sqlInstanceName-stage' , $sqlInstanceName | Set-Content -Path $SQLParams
    (Get-Content -Path $SQLParams) -replace 'port-stage' , 11433 | Set-Content -Path $SQLParams
    
    az deployment group create --resource-group $using:rg --template-file "C:\VHD\SQLMI.json" --parameters "C:\VHD\SQLMI.parameters.json"
    Write-Host "`n"
    
    Do {
        Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $dcStatus = $(if (kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
    } while ($dcStatus -eq "Nope")
    Write-Host "Azure Arc SQL Managed Instance is ready!"
    Write-Host "`n"
    
    # Downloading demo database and restoring onto SQL MI
    $podname = "jumpstart-sql-0"
    Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
    Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
    kubectl exec $podname -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $using:adminUsername -P $using:adminPassword -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
    
    
}

# Set env variable deployAKSHCI to true (in case the script was run manually)
[System.Environment]::SetEnvironmentVariable('deploySQLMI', 'true', [System.EnvironmentVariableTarget]::Machine)

Stop-Transcript