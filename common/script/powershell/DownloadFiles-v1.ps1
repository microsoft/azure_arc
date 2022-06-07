#requires -version 2
<#
.SYNOPSIS
  Download a set of files from a web location to your to the computer
.EXAMPLE
  Get-File ($templateBaseUrl + "../tests/")  @("GHActionDeploy.ps1", "OpenSSHDeploy.ps1") $Env:ArcBoxDir
#>
function Get-File {
  param(
    [string] $origin ,
    [string[]] $filenames ,
    [string] $target
  )
  foreach ($filename in $filenames) {
    Write-Output "$origin/$filename"
    Invoke-WebRequest ("$origin/$filename") -OutFile "$target\$filename"
  }
}

<#
.SYNOPSIS
  Download a file and save it with another name
.EXAMPLE
  Get-File-Renaming ($templateBaseUrl + "../img/arcbox_wallpaper.png") $Env:ArcBoxDir\wallpaper.png
#>
function Get-File-Renaming {
  param(
    [string] $originFile ,
    [string] $targetFile
  )
  Write-Output $originFile
  Invoke-WebRequest $originFile -OutFile "$targetFile"
}