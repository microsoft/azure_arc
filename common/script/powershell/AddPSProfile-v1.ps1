#requires -version 2

<#
.SYNOPSIS
  Set a specific script as PowerShell profile, download all the dependencies from global config
.EXAMPLE
  Add-PowerShell-Profile  ($templateBaseUrl+"artifacts\PSProfile.ps1")
#>
function Add-PowerShell-Profile {
  param(
    [string] $originScript,
    [string] $profileRootBaseUrl,
    [string[]] $globalFunctionDependencies,
    [string[]] $localFunctionDependencies = @()
  )
  foreach ($filename in $globalFunctionDependencies) {
    Invoke-WebRequest ($profileRootBaseUrl+"../common/script/powershell/$filename.ps1") -OutFile ($PsHome+"\"+$filename+".ps1")
  }
  foreach ($filename in $localFunctionDependencies) {
    Invoke-WebRequest ($profileRootBaseUrl+"common/script/powershell/$filename.ps1") -OutFile ($PsHome+"\"+$filename+".ps1")
  }
  Invoke-WebRequest ("$originScript") -OutFile $PsHome\Profile.ps1
  . $PsHome\Profile.ps1
}