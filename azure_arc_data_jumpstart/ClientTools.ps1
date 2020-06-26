param (
    [string]$servicePrincipalClientId,
    [string]$servicePrincipalClientSecret,
    [string]$adminUsername,
    [string]$tenantId,
    [string]$arcClusterName,
    [string]$resourceGroup,
    [string]$chocolateyAppList
)

[System.Environment]::SetEnvironmentVariable('servicePrincipalClientId', $servicePrincipalClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('servicePrincipalClientSecret', $servicePrincipalClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
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
                }
        }

ClientTools_01 | ft

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\tmp\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | ft 

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
# $variableNameToAdd = "KUBECONFIG"
# $variableValueToAdd = "C:\Windows\System32\config\systemprofile\.kube\config"
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Machine)
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::Process)
# [System.Environment]::SetEnvironmentVariable($variableNameToAdd, $variableValueToAdd, [System.EnvironmentVariableTarget]::User) ## Check if can be removed

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# $azurePassword = ConvertTo-SecureString $servicePrincipalClientSecret -AsPlainText -Force
# $psCred = New-Object System.Management.Automation.PSCredential($servicePrincipalClientId , $azurePassword)
# Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 
# Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName -Force
# kubectl get nodes

# azdata --version

echo '$azurePassword = ConvertTo-SecureString $env:servicePrincipalClientSecret -AsPlainText -Force' > C:\tmp\StartupScript.ps1
echo '$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalClientId" , $azurePassword)' >> C:\tmp\StartupScript.ps1
echo 'Connect-AzAccount -Credential $psCred -TenantId $env:tenantId -ServicePrincipal' >> C:\tmp\StartupScript.ps1
echo 'Import-AzAksCredential -ResourceGroupName $env:resourceGroup -Name $env:arcClusterName -Force' >> C:\tmp\StartupScript.ps1
echo 'kubectl get nodes' >> C:\tmp\StartupScript.ps1
echo 'azdata --version' >> C:\tmp\StartupScript.ps1

$Trigger=New-ScheduledTaskTrigger -AtLogOn # Specify the trigger settings
# $User= $adminUsername # Specify the account to run the script
$Action=New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\tmp\StartupScript.ps1" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "StartupScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel Highest –Force # Specify the name of the task
