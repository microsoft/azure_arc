# <--- Change the following environment variables according to your Azure Service Principle name --->

$env:subscriptionId = 'e73c1dbe-2574-4f38-9e8f-c813757b1786'
$env:appId = '051b9a58-4a83-48de-b610-0e7ae1bca3fb'
$env:password = '53ed1458-a77d-4201-9c21-4fe24a0981fa'
$env:tenantId = '72f988bf-86f1-41af-91ab-2d7cd011db47'
$env:resourceGroup = 'Arc-Data-Demo'
$env:location = 'eastus'
$env:arcClusterName = 'Arc-AKS-Demo'
$chocolateyAppList = "kubernetes-cli"

New-Item -Path "C:\" -Name "tmp" -ItemType "directory"
Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-may-2020/msi/Azure%20Data%20CLI.msi" -OutFile "C:\tmp\AZDataCLI.msi"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insider.zip"
Expand-Archive C:\tmp\azuredatastudio_insider.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insider'
Invoke-Item 'C:\Program Files\Azure Data Studio - Insider\azuredatastudio-insiders.exe'
# Stop-Process -Name "azuredatastudio-insiders" -Force

#Install-Package msi -provider PowerShellGet -Force
#Install-MSIProduct C:\tmp\AZDataCLI.msi
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

$TargetFile   = "C:\Program Files\Azure Data Studio - Insider\azuredatastudio-insiders.exe"
$ShortcutFile = "C:\Users\$env:UserName\Desktop\Azure Data Studio - Insider.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut     = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false -or [string]::IsNullOrWhiteSpace($dismAppList) -eq $false)
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

Invoke-WebRequest "https://github.com/microsoft/azuredatastudio/archive/master.zip" -OutFile "C:\tmp\azuredatastudio_repo.zip"
Expand-Archive C:\tmp\azuredatastudio_repo.zip -DestinationPath 'C:\tmp\azuredatastudio_repo' | Out-Null
$ExtensionsDestination = "C:\Users\$env:UserName\.azuredatastudio-insiders\extensions"
Copy-Item -Path "C:\tmp\azuredatastudio_repo\azuredatastudio-master\extensions\arc" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

# Creating new Azure Arc Resource Group
az login --service-principal --username $env:appId --password $env:password --tenant $env:tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing




## ADD CLEANUP




# Restart-Computer
