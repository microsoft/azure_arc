New-Item -Path "C:\" -Name "tmp" -ItemType "directory"
Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insider.zip"
Expand-Archive C:\tmp\azuredatastudio_insider.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insider'
Invoke-Item 'C:\Program Files\Azure Data Studio - Insider\azuredatastudio-insiders.exe'

# $TargetFile   = "C:\Program Files\Azure Data Studio - Insider\azuredatastudio-insiders.exe"
# $ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio - Insider.lnk"
# $WScriptShell = New-Object -ComObject WScript.Shell
# $Shortcut     = $WScriptShell.CreateShortcut($ShortcutFile)
# $Shortcut.TargetPath = $TargetFile
# $Shortcut.Save()

# # Install-Package msi -provider PowerShellGet -Force
# # Install-MSIProduct C:\tmp\AZDataCLI.msi

# Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"
# Expand-Archive C:\tmp\azuredatastudio_repo.zip -DestinationPath 'C:\tmp\azuredatastudio_repo'
# $ExtensionsDestination = "C:\Users\$env:adminUsername\.azuredatastudio-insiders\extensions"
# Copy-Item -Path "C:\tmp\azuredatastudio_repo\azuredatastudio-master\extensions\arc" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

# az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
# az aks get-credentials --name $env:arcClusterName --resource-group $env:resourceGroup --overwrite-existing

 



## ADD CLEANUP




# Restart-Computer
