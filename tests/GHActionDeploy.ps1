$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

Start-Transcript -Path $Env:ArcBoxLogsDir\GHActionDeploy.log
Write-Output "GHActionDeploy log in"

# Deploy ArcServersLogonScript if needed, this script doesn´t work running on openSSH. Refedence on the readme file.
if ($Env:flavor -eq "Full" -Or $Env:flavor -eq "ITPro") {
    Write-Output "Deploying ArcServersLogonScript."
    Write-Output "`n"
    Invoke-Expression $Env:ArcBoxDir\ArcServersLogonScript.ps1
    Write-Output "Deployed ArcServersLogonScript."
    Write-Output "`n"
}

# Install OpenSSH on port 2204 inside the VM to execute the logOn scripts, download log, query directories for executing validation commands. 
Invoke-Expression $Env:ArcBoxDir\OpenSSHDeploy.ps1

Write-Output "Deployed OpenSSH"

Write-Output "Deployed OpenSSH" > $Env:ArcBoxLogsDir\OpenSSHDeployed.txt
exit 0