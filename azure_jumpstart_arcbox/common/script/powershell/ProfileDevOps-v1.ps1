Write-Output "DevOps profile script"

Write-Output "Fetching Workbook Template Artifact for DevOps"
Get-File-Renaming ($templateBaseUrl + "artifacts/mgmtMonitorWorkbookDevOps.json") $Env:ArcBoxDir\mgmtMonitorWorkbook.json

Write-Output "Fetching Artifacts for DevOps Flavor"
Get-File ($templateBaseUrl + "artifacts")  @("DevOpsLogonScript.ps1", "BookStoreLaunch.ps1") $Env:ArcBoxDir
Get-File ($templateBaseUrl + "artifacts/devops_ingress")  @("bookbuyer.yaml", "bookstore.yaml", "hello-arc.yaml")  $Env:ArcBoxKVDir
Get-File ($templateBaseUrl + "artifacts/gitops_scripts")  @("K3sGitOps.ps1", "K3sRBAC.ps1", "ResetBookstore.ps1")  $Env:ArcBoxGitOpsDir
Get-File ($templateBaseUrl + "artifacts/icons")  @("arc.ico", "bookstore.ico")  $Env:ArcBoxIconDir

Write-Output "Creating scheduled task for DevOpsLogonScript.ps1"
Add-Logon-Script $adminUsername "DevOpsLogonScript" ("$Env:ArcBoxDir\DevOpsLogonScript.ps1")