param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$arcClusterName,
    [string]$resourceGroup,
    [string]$adminUsername
)

$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli"

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false)
{
    try{
        choco config get cacheLocation
    }catch{
        Write-Output "Chocolatey not detected, trying to install now"
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){   
    Write-Host "Chocolatey Apps Specified"  
    
    $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

    foreach ($app in $appsToInstall)
    {
        Write-Host "Installing $app"
        & choco install $app /y | Write-Output
    }
}

[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcClusterName', $arcClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory"
New-Item -Path "C:\Users\$adminUsername\" -Name ".azuredatastudio-insiders\extensions" -ItemType "directory"
# Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
# Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"
# Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"

$azurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($appId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 

Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName -Force
kubectl get nodes

New-Item -Path $env:USERPROFILE -Name ".kube" -ItemType "directory"
Copy-Item -Path "C:\Windows\System32\config\systemprofile\.kube\config" -Destination "$env:USERPROFILE\.kube" -Recurse


