Write-Output "ITPro-Full profile script"

Write-Output "Fetching Artifacts for ITPro Flavor"
Get-File ($templateBaseUrl + "artifacts")  @("ArcServersLogonScript.ps1", "ArcSQLManualOnboarding.ps1", "installArcAgentSQLUser.ps1") $Env:ArcBoxDir
Get-File ($templateBaseUrl + "artifacts")  @("installArcAgent.ps1", "installArcAgentSQLSP.ps1", "installArcAgentUbuntu.sh", "installArcAgentCentOS.sh") "$Env:ArcBoxDir\agentScript"
Get-File ($templateBaseUrl + "artifacts/icons")  @("arcsql.ico") $Env:ArcBoxDir

Write-Output "Creating scheduled task for ArcServersLogonScript.ps1"
Add-Logon-Script $Env:adminUsername "ArcServersLogonScript" ("$Env:ArcBoxDir\ArcServersLogonScript.ps1")