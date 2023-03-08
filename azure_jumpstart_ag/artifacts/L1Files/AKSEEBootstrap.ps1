# L1 - Nested VM

###########################################
# Preparing environment folders structure #
###########################################

$deploymentFolder = "C:\Deployment" # Deployment folder is already available in the VHD image
$logsFolder = "$deploymentFolder\Logs"
$kubeFolder = "$env:USERPROFILE\.kube"

# Set up an array of folders
$folders = @($logsFolder, $kubeFolder)

# Loop through each VM and restart it
foreach ($Folder in $folders) {
    New-Item -ItemType Directory $Folder -Force
}

# Log starts
Start-Transcript -Path $logsFolder\AKSEEBootstrap.log

#########################################
# Deplying AKS Edge Essentials clusters #
#########################################

# Parameterizing the host, L0 username and password Required for the shared drive functionality (New-PSDrive)
$HVHostUsername = "arcdemo"
$HVHostPassword = ConvertTo-SecureString "ArcPassword123!!" -AsPlainText -Force

if ($env:COMPUTERNAME -eq "Seattle") {

    $NetIPAddress = "172.20.1.2"
    $DefaultGateway = "172.20.1.1"
    $PrefixLength = "24"
    $DNSClientServerAddress = "168.63.129.16"

    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $ServiceIPRangeStart = "172.20.1.31"
    $ServiceIPRangeSize = "10"
    $ControlPlaneEndpointIp = "172.20.1.21"
    $LinuxNodeIp4Address = "172.20.1.11"

    $replacementParams = @{
        "ServiceIPRangeStart-null"    = $ServiceIPRangeStart
        "1000"                        = $ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $DefaultGateway
        "2000"                        = $PrefixLength
        "DnsServer-null"              = $DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $LinuxNodeIp4Address
    }

    $msiFileName = (Get-ChildItem -Path $deploymentFolder | Where-Object { $_.Extension -eq ".msi" }).Name
    $msiFilePath = Join-Path $deploymentFolder $msiFileName
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($msiFilePath)
    $msiInstallLog = "$deploymentFolder\$fileNameWithoutExt.log"
    Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log `"$msiInstallLog`"" -Wait

    $content = Get-Content $AKSEEConfigFilePath

    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }

    $AKSEEConfigFilePath = (Join-Path $deploymentFolder $env:COMPUTERNAME) + ".json"
    Set-Content $AKSEEConfigFilePath -Value $content
        
    Set-Location $deploymentFolder
    $AKSEEConfigFilePath = Get-ChildItem $deploymentFolder | Where-Object ({ $_.Name -like "*$env:COMPUTERNAME*" })
    New-AksEdgeDeployment -JsonConfigFilePath $AKSEEConfigFilePath
    Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p ICMP -j ACCEPT"

    # kubeconfig work to change context and copy mew file to the Hyper-V host machine
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config.backup"
    $NewKubeContext = $(hostname).ToLower()
    kubectx $NewKubeContext=default
    Write-Host
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config-$NewKubeContext"
    Write-Host
    kubectl get nodes -o wide
    Write-Host

    $Credentials = New-Object System.Management.Automation.PSCredential($HVHostUsername, $HVHostPassword)
    $sourcePath = "$env:USERPROFILE\.kube\config-$NewKubeContext"
    $destinationPath = "\\$DefaultGateway\kube"
    New-PSDrive -Name "SharedDrive" -PSProvider FileSystem -Root $destinationPath -Credential $Credentials
    Copy-Item -Path $sourcePath -Destination $destinationPath

    Unregister-ScheduledTask -TaskName "Startup Scan" -Confirm:$false
}
elseif ($env:COMPUTERNAME -eq "Chicago") {

    $NetIPAddress = "172.20.1.3"
    $DefaultGateway = "172.20.1.1"
    $PrefixLength = "24"
    $DNSClientServerAddress = "168.63.129.16"

    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $ServiceIPRangeStart = "172.20.1.71"
    $ServiceIPRangeSize = "10"
    $ControlPlaneEndpointIp = "172.20.1.61"
    $LinuxNodeIp4Address = "172.20.1.51"

    $replacementParams = @{
        "ServiceIPRangeStart-null"    = $ServiceIPRangeStart
        "1000"                        = $ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $DefaultGateway
        "2000"                        = $PrefixLength
        "DnsServer-null"              = $DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $LinuxNodeIp4Address
    }

    $msiFileName = (Get-ChildItem -Path $deploymentFolder | Where-Object { $_.Extension -eq ".msi" }).Name
    $msiFilePath = Join-Path $deploymentFolder $msiFileName
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($msiFilePath)
    $msiInstallLog = "$deploymentFolder\$fileNameWithoutExt.log"
    Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log `"$msiInstallLog`"" -Wait

    $content = Get-Content $AKSEEConfigFilePath

    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }

    $AKSEEConfigFilePath = (Join-Path $deploymentFolder $env:COMPUTERNAME) + ".json"
    Set-Content $AKSEEConfigFilePath -Value $content
        
    Set-Location $deploymentFolder
    $AKSEEConfigFilePath = Get-ChildItem $deploymentFolder | Where-Object ({ $_.Name -like "*$env:COMPUTERNAME*" })
    New-AksEdgeDeployment -JsonConfigFilePath $AKSEEConfigFilePath
    Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p ICMP -j ACCEPT"

    # kubeconfig work to change context and copy mew file to the Hyper-V host machine
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config.backup"
    $NewKubeContext = $(hostname).ToLower()
    kubectx $NewKubeContext=default
    Write-Host
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config-$NewKubeContext"
    Write-Host
    kubectl get nodes -o wide
    Write-Host

    $Credentials = New-Object System.Management.Automation.PSCredential($HVHostUsername, $HVHostPassword)
    $sourcePath = "$env:USERPROFILE\.kube\config-$NewKubeContext"
    $destinationPath = "\\$DefaultGateway\kube"
    New-PSDrive -Name "SharedDrive" -PSProvider FileSystem -Root $destinationPath -Credential $Credentials
    Copy-Item -Path $sourcePath -Destination $destinationPath

    Unregister-ScheduledTask -TaskName "Startup Scan" -Confirm:$false
}
elseif ($env:COMPUTERNAME -eq "AKSEEDev-Local") {

    $NetIPAddress = "172.20.1.4"
    $DefaultGateway = "172.20.1.1"
    $PrefixLength = "24"
    $DNSClientServerAddress = "168.63.129.16"

    $AKSEEConfigFilePath = "$deploymentFolder\ScalableCluster.json"
    $ServiceIPRangeStart = "172.20.1.101"
    $ServiceIPRangeSize = "10"
    $ControlPlaneEndpointIp = "172.20.1.91"
    $LinuxNodeIp4Address = "172.20.1.81"

    $replacementParams = @{
        "ServiceIPRangeStart-null"    = $ServiceIPRangeStart
        "1000"                        = $ServiceIPRangeSize
        "ControlPlaneEndpointIp-null" = $ControlPlaneEndpointIp
        "Ip4GatewayAddress-null"      = $DefaultGateway
        "2000"                        = $PrefixLength
        "DnsServer-null"              = $DNSClientServerAddress
        "Ethernet-Null"               = $AdapterName
        "Ip4Address-null"             = $LinuxNodeIp4Address
    }

    $msiFileName = (Get-ChildItem -Path $deploymentFolder | Where-Object { $_.Extension -eq ".msi" }).Name
    $msiFilePath = Join-Path $deploymentFolder $msiFileName
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($msiFilePath)
    $msiInstallLog = "$deploymentFolder\$fileNameWithoutExt.log"
    Start-Process msiexec.exe -ArgumentList "/i `"$msiFilePath`" /passive /qb! /log `"$msiInstallLog`"" -Wait

    $content = Get-Content $AKSEEConfigFilePath

    foreach ($key in $replacementParams.Keys) {
        $content = $content -replace $key, $replacementParams[$key]
    }

    $AKSEEConfigFilePath = (Join-Path $deploymentFolder $env:COMPUTERNAME) + ".json"
    Set-Content $AKSEEConfigFilePath -Value $content
        
    Set-Location $deploymentFolder
    $AKSEEConfigFilePath = Get-ChildItem $deploymentFolder | Where-Object ({ $_.Name -like "*$env:COMPUTERNAME*" })
    New-AksEdgeDeployment -JsonConfigFilePath $AKSEEConfigFilePath
    Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p ICMP -j ACCEPT"

    # kubeconfig work to change context and copy mew file to the Hyper-V host machine
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config.backup"
    $NewKubeContext = $(hostname).ToLower()
    kubectx $NewKubeContext=default
    Write-Host
    Copy-Item -Path "$env:USERPROFILE\.kube\config" -Destination "$env:USERPROFILE\.kube\config-$NewKubeContext"
    Write-Host
    kubectl get nodes -o wide
    Write-Host

    $Credentials = New-Object System.Management.Automation.PSCredential($HVHostUsername, $HVHostPassword)
    $sourcePath = "$env:USERPROFILE\.kube\config-$NewKubeContext"
    $destinationPath = "\\$DefaultGateway\kube"
    New-PSDrive -Name "SharedDrive" -PSProvider FileSystem -Root $destinationPath -Credential $Credentials
    Copy-Item -Path $sourcePath -Destination $destinationPath

    Unregister-ScheduledTask -TaskName "Startup Scan" -Confirm:$false
}
else {
    Write-Error "Something is wrong, check AKSEEBootstrap log file located in $logsFolder"
}
