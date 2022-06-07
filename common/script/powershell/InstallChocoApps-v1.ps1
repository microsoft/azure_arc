#requires -version 2

<#
.SYNOPSIS
  Install dependencies with chocolaty, and chocholaty if needed
.EXAMPLE
  Install-ChocolateyApp(@('dep1','dep2@version1'))
#>
function Install-ChocolateyApp {
    param(
        [string[]]$chocolateyAppList
    )
    try {
        choco config get cacheLocation
    }
    catch {
        Write-Output "Chocolatey not detected, trying to install now"
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    foreach ($app in $chocolateyAppList)
    {
        Write-Output "Installing $app"
        & choco install $app /y -Force | Write-Output
    }
}