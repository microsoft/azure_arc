$deploymentFolder = "C:\Deployment" # Deployment folder is already available in the VHD image
Start-Transcript -Path "$deploymentFolder\StartupScan.log"

$scripts = Get-ChildItem -Path $deploymentFolder -Filter "AKSEEBootstrap.ps1"
foreach ($script in $scripts) {
    & $script.FullName
}
