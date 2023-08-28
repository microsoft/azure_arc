Write-Host "[$(Get-Date -Format t)] INFO: Configuring AKSEE as Single Machine Cluster (Step 4/17)" -ForegroundColor DarkGreen
$msiurl = "https://aka.ms/aks-edge/k3s-msi"
#Invoke-WebRequest -Uri $msiurl -OutFile aksee-k3s-msi.msi
$msiFilePath = "aksee-k3s-msi.msi"
$msiInstallLog = "aksedgelog.txt"
Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log aksee-log.txt" -Wait
Import-Module AksEdge.psm1 -Force
Install-AksEdgeHostFeatures -Force

$jsonObj = New-AksEdgeConfig -DeploymentType SingleMachineCluster
$jsonObj.User.AcceptEula = $true
$jsonObj.User.AcceptOptionalTelemetry = $true
$jsonObj.Init.ServiceIpRangeSize = 10
$machine = $jsonObj.Machines[0]
$machine.LinuxNode.CpuCount = 4
$machine.LinuxNode.MemoryInMB = 4096
$machine.LinuxNode.DataSizeInGB = 80

New-AksEdgeDeployment -JsonConfigString ($jsonObj | ConvertTo-Json -Depth 4)

