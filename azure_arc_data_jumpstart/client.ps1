#Script based on https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/visual-studio-dev-vm-chocolatey/scripts/SetupChocolatey.ps1
param([Parameter(Mandatory=$true)][string]$chocoPackages)

Write-Host "File packages URL: $linktopackages"

#Changing ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#Change securoty protocol
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Install Choco
$sb = { iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) }
Invoke-Command -ScriptBlock $sb 

$sb = { Set-ItemProperty -path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLua -value 0 }
Invoke-Command -ScriptBlock $sb 

#Install Chocolatey Packages
$chocoPackages.Split(";") | ForEach {
    choco install $_ -y -force
}

Write-Host "Packages from choco.org were installed"

New-Item -Path "C:\" -Name "tmp" -ItemType "directory"
Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"
Expand-Archive C:\tmp\azuredatastudio_insider.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
# Invoke-Item 'C:\Program Files\Azure Data Studio - Insider\azuredatastudio-insiders.exe'
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"

$TargetFile             = "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"
$ShortcutFile           = "C:\Users\$env:USERNAME\Desktop\Azure Data Studio - Insiders.lnk"
$WScriptShell           = New-Object -ComObject WScript.Shell
$Shortcut               = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath    = $TargetFile
$Shortcut.Save()

# Install-Package msi -provider PowerShellGet -Force
# Install-MSIProduct C:\tmp\AZDataCLI.msi

Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"
Expand-Archive C:\tmp\azuredatastudio_repo.zip -DestinationPath 'C:\tmp\azuredatastudio_repo'
$ExtensionsDestination = "C:\Users\$env:USERNAME\.azuredatastudio-insiders\extensions"
Copy-Item -Path "C:\tmp\azuredatastudio_repo\azuredatastudio-master\extensions\arc" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue
