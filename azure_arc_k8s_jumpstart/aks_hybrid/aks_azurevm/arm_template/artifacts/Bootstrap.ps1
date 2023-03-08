param (
    [string]$userName,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$location,
    [string]$templateBaseUrl,
    [string]$resourceGroup
)

[System.Environment]::SetEnvironmentVariable('userName', $userName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)

$ProgressPreference = "SilentlyContinue"

mkdir -Path "C:\WAC"

## Download the MSI file
Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/WACDownload' -OutFile "C:\WAC\WindowsAdminCenter.msi"
#Invoke-WebRequest -UseBasicParsing -Uri 'https://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter2103.2.msi' -OutFile "C:\WAC\WindowsAdminCenter.msi"
#Invoke-WebRequest -UseBasicParsing -Uri 'https://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter2009.msi' -OutFile "C:\WAC\WindowsAdminCenter.msi"

## install Windows Admin Center
$msiArgs = @("/i", "C:\WAC\WindowsAdminCenter.msi", "/qn", "/L*v", "log.txt", "SME_PORT=443", "SSL_CERTIFICATE_OPTION=generate")
Start-Process msiexec.exe -Wait -ArgumentList $msiArgs

<# Update WAC Extensions
Import-Module "$env:ProgramFiles\windows admin center\PowerShell\Modules\ExtensionTools" -Verbose

# Specify the WAC gateway
$WAC = "https://$env:COMPUTERNAME"

# List the WAC extensions
$extensions = Get-Extension $WAC | Where-Object { $_.isLatestVersion -like 'False' }

ForEach ($extension in $extensions) {    
    Update-Extension $WAC -ExtensionId $extension.Id -Verbose | out-file -append C:\Users\Public\WACUpdateLog$(get-date -f MM-dd-yyyy_HH_mm).txt
} #>

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

$ErrorActionPreference = 'SilentlyContinue'

# Downloading GitHub artifacts for DataServicesLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogonScript.ps1") -OutFile "C:\Temp\LogonScript.ps1"

Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,kubernetes-cli,kubernetes-helm'
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
                                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                }
        }

ClientTools_01 | Format-Table 


New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

# Creating scheduled task for LogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $userName -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content C:\Temp\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content C:\Temp\Bootstrap.log -Force