$Env:AgDir = "C:\Ag"
$Env:AgLogsDir = "C:\Ag\Logs"
$Env:AgVMDir = "$Env:AgDir\Virtual Machines"
$Env:AgIconDir = "C:\Ag\Icons"

Start-Transcript -Path $Env:AgLogsDir\AgLogonScript.log
$ConfigurationDataFile = "$Env:AgDir\HCIBox-Config.psd1"
$AgConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Install Windows Terminal
Write-Header "Installing Windows Terminal"
If ($PSVersionTable.PSVersion.Major -ge 7){ Write-Error "This script needs be run by version of PowerShell prior to 7.0" }

# Define environment variables
$downloadDir = "C:\WinTerminal"
$gitRepo = "microsoft/terminal"
$filenamePattern = "*.msixbundle"
$framworkPkgUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$framworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$msiPath = "$downloadDir\Microsoft.WindowsTerminal.msixbundle"
$releasesUri = "https://api.github.com/repos/$gitRepo/releases/latest"
$downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -SkipLast 1

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release msixbundle
Invoke-WebRequest -Uri $framworkPkgUrl -OutFile ( New-Item -Path $framworkPkgPath -Force )
Invoke-WebRequest -Uri $downloadUri -OutFile ( New-Item -Path $msiPath -Force )

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Add-AppxPackage -Path $framworkPkgPath
Add-AppxPackage -Path $msiPath

# Cleanup
Remove-Item $downloadDir -Recurse -Force

$cliDir = New-Item -Path "$Env:AgDir\.cli\" -Name ".Ag" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for azcopy
Write-Header "Az PowerShell Login"
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Register Azure providers
Write-Header "Registering Providers"
foreach ($provider in $AgConfig.AzureProviders) {
    Register-AzResourceProvider -ProviderNamespace $provider
}

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
az extension add --name arcdata --system
az -v

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksProdClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksDevClusterName --admin

kubectx aksProd="$Env:aksProdClusterName-admin"
kubectx aksDev="$Env:aksDevClusterName-admin"

# Attach ACRs to AKS clusters
Write-Header "Attaching ACRs to AKS clusters"
az aks update -n $Env:aksProdClusterName -g $Env:resourceGroup --attach-acr $Env:acrNameProd
az aks update -n $Env:aksDevClusterName -g $Env:resourceGroup --attach-acr $Env:acrNameDev

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "AgLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

# Executing the deployment logs bundle PowerShell script in a new window
Write-Header "Uploading Log Bundle"
Invoke-Expression 'cmd /c start Powershell -Command { 
    $RandomString = -join ((48..57) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    Write-Host "Sleeping for 5 seconds before creating deployment logs bundle..."
    Start-Sleep -Seconds 5
    Write-Host "`n"
    Write-Host "Creating deployment logs bundle"
    7z a $Env:AgLogsDir\LogsBundle-"$RandomString".zip $Env:HCIBoxLogsDir\*.log
}'

Write-Header "Changing Wallpaper"
$imgPath="$Env:AgDir\wallpaper.png"
Add-Type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

Stop-Transcript