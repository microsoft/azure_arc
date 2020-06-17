param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$arcClusterName,
    [string]$resourceGroup,
    [string]$chocolateyAppList
)

[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcClusterName', $arcClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli'
            #Run commands in parallel.
            Parallel 
                {
                    InlineScript {
                        param (
                            [string]$chocolateyAppList
                        )
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false)
                        {
                            try{
                                choco config get cacheLocation
                            }catch{
                                Write-Output "Chocolatey not detected, trying to install now"
                                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"                
                    Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
                    Install-Package msi -provider PowerShellGet -Force                    
                }
        }

ClientTools_01 | ft

workflow ClientTools_03
        {
            $variableNameToAdd = "KUBECONFIG"
            $variableValueToAdd = "C:\Windows\System32\config\systemprofile\.kube\config"
            # $variableValueToAdd = "C:\Users\Administrator\.kube\config"                        
                {
                    InlineScript {
                        param (
                            [string]$variableNameToAdd,
                            [string]$variableValueToAdd
                        )
                        [System.Environment]::SetEnvironmentVariable($using:variableNameToAdd, $using:variableValueToAdd, [System.EnvironmentVariableTarget]::Machine)
                        [System.Environment]::SetEnvironmentVariable($using:variableNameToAdd, $using:variableValueToAdd, [System.EnvironmentVariableTarget]::Process)
                        [System.Environment]::SetEnvironmentVariable($using:variableNameToAdd, $using:variableValueToAdd, [System.EnvironmentVariableTarget]::User) ## Check if can be removed                     
                    }              
                }
        }

ClientTools_03 | ft

$azurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($appId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 
Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName -Force
kubectl get nodes

# Install-MSIProduct C:\tmp\AZDataCLI.msi