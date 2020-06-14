param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$arcClusterName,
    [string]$resourceGroup,
    [string]$adminUsername
)

# $chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli"

# if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false)
# {
#     try{
#         choco config get cacheLocation
#     }catch{
#         Write-Output "Chocolatey not detected, trying to install now"
#         iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
#     }
# }

# if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){   
#     Write-Host "Chocolatey Apps Specified"  
    
#     $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

#     foreach ($app in $appsToInstall)
#     {
#         Write-Host "Installing $app"
#         & choco install $app /y | Write-Output
#     }
# }

# [System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable('arcClusterName', $arcClusterName,[System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine) ## Check if can be removed


# $azurePassword = ConvertTo-SecureString $password -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($appId , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 

# Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName -Force
# kubectl get nodes

# $variableNameToAdd = "KUBECONFIG"
# $variableValueToAdd = "C:\Windows\System32\config\systemprofile\.kube\config"
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Process)
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::User) ## Check if can be removed

# {Arc Data Controller HERE}

$variableNameToAdd = "TMP_PROFILE_PATH"
$variableValueToAdd = "C:\Users\$adminUsername"
[System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Process)


New-Item -Path "C:\" -Name "tmp" -ItemType "directory"
# New-Item -Path "$env:TMP_PROFILE_PATH" -Name ".azuredatastudio-insiders\extensions" -ItemType "directory"
# New-Item -Path "$env:TMP_PROFILE_PATH" -Name ".test\extensions" -ItemType "directory"
# Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"
Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"

#Install-Package msi -provider PowerShellGet -Force
#Install-MSIProduct C:\tmp\AZDataCLI.msi

Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
Expand-Archive C:\tmp\azuredatastudio_repo.zip -DestinationPath 'C:\tmp\azuredatastudio_repo'
# $ExtensionsDestination = "C:\Users\$env:USERNAME\.azuredatastudio-insiders\extensions"
# $ExtensionsDestination = "$TMP_PROFILE_PATH\.azuredatastudio-insiders\extensions"
# Copy-Item -Path "C:\tmp\azuredatastudio_repo\azuredatastudio-master\extensions\arc" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue
Copy-Item -Path "C:\tmp\azuredatastudio_repo\azuredatastudio-master\extensions\arc" -Destination "$env:TMP_PROFILE_PATH\.azuredatastudio-insiders\extensions" -Recurse -Force -ErrorAction Continue




# [Environment]::SetEnvironmentVariable("[appId]",$null,"Machine")
# [Environment]::SetEnvironmentVariable("[password]",$null,"Machine")
# [Environment]::SetEnvironmentVariable("[tenantId]",$null,"Machine")
# [Environment]::SetEnvironmentVariable("[arcClusterName]",$null,"Machine")
# [Environment]::SetEnvironmentVariable("[resourceGroup]",$null,"Machine")
# Remove-Item –path "C:\tmp" -Recurse

# Add Cleanup
    # System Vars
    # C:\tmp