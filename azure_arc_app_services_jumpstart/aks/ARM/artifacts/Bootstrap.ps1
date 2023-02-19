param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$workspaceName,
    [string]$clusterName,
    [string]$connectedClusterName,
    [string]$deployContainerApps,
    [string]$deployAppService,
    [string]$deployFunction,
    [string]$deployApiMgmt,
    [string]$deployLogicApp,
    [string]$adminEmail,
    [string]$templateBaseUrl,
    [string]$productsImage,
    [string]$inventoryImage,
    [string]$storeImage
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('connectedClusterName', $connectedClusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployAppService', $deployAppService,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployFunction', $deployFunction,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployApiMgmt', $deployApiMgmt,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployLogicApp', $deployLogicApp,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminEmail', $adminEmail,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('productsImage', $productsImage,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('inventoryImage', $inventoryImage,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('storeImage', $storeImage,[System.EnvironmentVariableTarget]::Machine)


# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Host "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Downloading global Jumpstart artifacts
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/img/jumpstart_wallpaper.png" -OutFile "C:\Temp\wallpaper.png"

# Downloading GitHub artifacts for AppServicesLogonScript.ps1
if ($deployAppService -eq $true -Or $deployFunction -eq $true -Or $deployApiMgmt -eq $true -Or $deployLogicApp -eq $true) {
Invoke-WebRequest ($templateBaseUrl + "artifacts/AppServicesLogonScript.ps1") -OutFile "C:\Temp\AppServicesLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployAppService.ps1") -OutFile "C:\Temp\deployAppService.ps1"  
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployFunction.ps1") -OutFile "C:\Temp\deployFunction.ps1" 
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployApiMgmt.ps1") -OutFile "C:\Temp\deployApiMgmt.ps1" 
Invoke-WebRequest ($templateBaseUrl + "artifacts/deployLogicApp.ps1") -OutFile "C:\Temp\deployLogicApp.ps1" 
}

# Downloading GitHub artifacts for ContainerAppsLogonScript.ps1
if ($deployContainerApps -eq $true) {
Invoke-WebRequest ($templateBaseUrl + "artifacts/ContainerAppsLogonScript.ps1") -OutFile "C:\Temp\ContainerAppsLogonScript.ps1"
}

# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm,azurefunctions-vscode,dotnetcore-sdk,dotnet-sdk,dotnet-runtime,vscode-csharp,microsoftazurestorageexplorer,7zip'
            $kubectlVersion = '1.24.9'
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
                                if ($app -eq "kubernetes-cli"){
                                    Write-Host "Installing $app"
                                    & choco install $app --version $using:kubectlVersion /y -Force| Write-Output
                                } else {
                                    Write-Host "Installing $app"
                                    & choco install $app /y -Force| Write-Output
                                }
                            }
                        }
                    }
                }
        }

ClientTools_01 | Format-Table

Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=2135274" -OutFile "C:\Temp\FuncCLI.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Temp\FuncCLI.msi /quiet'
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HubsSidebarEnabled'
$Value        = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HideFirstRunExperience'
$Value        = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

if ($deployAppService -eq $true -Or $deployFunction -eq $true -Or $deployApiMgmt -eq $true -Or $deployLogicApp -eq $true) {
# Creating scheduled task for AppServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\AppServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "AppServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

if ($deployContainerApps -eq $true) {
# Creating scheduled task for ContainerAppsLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\ContainerAppsLogonScript.ps1'
Register-ScheduledTask -TaskName "ContainerAppsLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content C:\Temp\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content C:\Temp\Bootstrap.log -Force
