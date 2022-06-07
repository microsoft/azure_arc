Start-Transcript "C:\Temp\Bootstrap.log"

. ./AddPSProfile-v1.ps1
. ./CommonBootstrapArcData.ps1 -profileRootBaseUrl $env:profileRootBaseUrl -templateBaseUrl $env:templateBaseUrl -adminUsername $env:adminUsername

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content "$Env:tempDir\Bootstrap.log" -Force | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content "$Env:tempDir\Bootstrap.log" -Force
