$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

Start-Transcript -Path $Env:ArcBoxLogsDir\GHActionDeploy.log
Write-Output "GHActionDeploy log in"

if ($Env:flavor -eq "Full" -Or $Env:flavor -eq "ITPro") {
    Write-Output "Deploying ArcServersLogonScript."
    Write-Output "`n"
    Invoke-Expression $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Write-Output "Deployed ArcServersLogonScript."
    Write-Output "`n"
}

Invoke-Expression $Env:ArcBoxDir\OpenSSHDeploy.ps1

Write-Output "Deployed OpenSSH"

Write-Output "Deployed OpenSSH" > $Env:ArcBoxLogsDir\OpenSSHDeployed.txt
exit 0