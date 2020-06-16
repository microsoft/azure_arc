param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$arcClusterName,
    [string]$resourceGroup
)

[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcClusterName', $arcClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

workflow ClientTools_01
        {
            #Run commands in parallel.
            Parallel 
            {
                choco install azure-cli -y -Force
                choco install az.powershell -y -Force
                choco install kubernetes-cli -y -Force

                Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"                
                Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
                Install-Package msi -provider PowerShellGet -Force
            }
        }

ClientTools_01 | ft 

workflow ClientTools_02
        {
            #Run commands in parallel.
            {
                Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
            }
        }
        
ClientTools_02 | ft 

$variableNameToAdd = "KUBECONFIG"
$variableValueToAdd = "C:\Windows\System32\config\systemprofile\.kube\config"
[System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::User) ## Check if can be removed

$azurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($appId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 
Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName -Force
kubectl get nodes

# Install-MSIProduct C:\tmp\AZDataCLI.msi
