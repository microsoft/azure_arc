param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$workspaceName,
    [string]$clusterName,
    [string]$templateBaseUrl
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.1#erroractionpreference
# Show errors, but to continue nonetheless
$ErrorActionPreference = 'Continue'

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

# Downloading GitHub artifacts for AzureMLLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/AzureMLLogonScript.ps1") -OutFile "C:\Temp\AzureMLLogonScript.ps1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/simple-train-cli.zip") -OutFile "C:\Temp\simple-train-cli.zip"
Invoke-WebRequest ($templateBaseUrl + "artifacts/simple-inference-cli.zip") -OutFile "C:\Temp\simple-inference-cli.zip"
Invoke-WebRequest ($templateBaseUrl + "artifacts/1.Get_WS.py") -OutFile "C:\Temp\1.Get_WS.py"
Invoke-WebRequest ($templateBaseUrl + "artifacts/2.Attach_Arc.py") -OutFile "C:\Temp\2.Attach_Arc.py"
Invoke-WebRequest ($templateBaseUrl + "artifacts/wallpaper.png") -OutFile "C:\Temp\wallpaper.png"

# Unzip training and inference payloads
Expand-Archive -LiteralPath "C:\Temp\simple-train-cli.zip" -DestinationPath "C:\Temp"
Expand-Archive -LiteralPath "C:\Temp\simple-inference-cli.zip" -DestinationPath "C:\Temp"

# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm,grep'
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

                            ##########################################################################
                            # Python Installation
                            choco install python --version=3.6.7 /y -Force
                            New-Item -path alias:python -value 'C:\Python36\python.exe'
                            New-Item -path alias:pip -value 'C:\Python36\Scripts\pip.exe'

                            # Installing Azure ML Python SDK
                            python -m pip install --upgrade pip
                            pip install azureml-core
                            pip install azureml-opendatasets
                            ##########################################################################
                        }                        
                    }
                }
        }

ClientTools_01 | Format-Table

# Alias for kubectl
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

# Creating scheduled task for AzureMLLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\AzureMLLogonScript.ps1'
Register-ScheduledTask -TaskName "AzureMLLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
