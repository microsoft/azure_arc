$Env:AgoraDir = "C:\Agora"
$Env:AgoraLogsDir = "C:\Agora\Logs"
$Env:AgoraVMDir = "$Env:AgoraDir\Virtual Machines"
$Env:AgoraIconDir = "C:\Agora\Icons"

Start-Transcript -Path $Env:AgoraLogsDir\AgoraLogonScript.log

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

$cliDir = New-Item -Path "$Env:AgoraDir\.cli\" -Name ".agora" -ItemType Directory

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

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt
# Installing Azure CLI extensions
az extension add --name arcdata --system
az -v

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksProdClusterName --admin
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksDevClusterName --admin

kubectx aksProd = "$Env:aksProdClusterName-admin"
kubectx aksDev = "$Env:aksDevClusterName-admin"

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Write-Header "Removing Logon Task"
Unregister-ScheduledTask -TaskName "AgoraLogonScript" -Confirm:$false
Start-Sleep -Seconds 5


