$Env:ESUDir = "C:\ESU"
$Env:ESULogsDir = "$Env:ESUDir\Logs"
$Env:ESUVMDir = "$Env:ESUDir\Virtual Machines"
$Env:ESUIconDir = "$Env:ESUDir\Icons"
$agentScript = "$Env:ESUDir\agentScript"

# Set variables to execute remote powershell scripts on guest VMs
$nestedVMESUDir = $Env:ESUDir
$spnClientId = $env:spnClientId
$spnClientSecret = $env:spnClientSecret
$spnTenantId = $env:spnTenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup
$esu = $env:esu


# Archive exising log file and crate new one
$logFilePath = "$Env:ESULogsDir\ArcServersLogonScript.log"
if ([System.IO.File]::Exists($logFilePath)) {
    $archivefile = "$Env:ESULogsDir\ArcServersLogonScript-" + (Get-Date -Format "yyyyMMddHHmmss")
    Rename-Item -Path $logFilePath -NewName $archivefile -Force
}

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

################################################
# Setup Hyper-V server before deploying VMs 
################################################

    # Install and configure DHCP service (used by Hyper-V nested VMs)
    Write-Host "Configuring DHCP Service"
    $dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq "Ethernet" }
    $dhcpScope = Get-DhcpServerv4Scope
    if ($dhcpScope.Name -ne "ESU") {
        Add-DhcpServerv4Scope -Name "ESU" `
            -StartRange 10.10.1.100 `
            -EndRange 10.10.1.200 `
            -SubnetMask 255.255.255.0 `
            -LeaseDuration 1.00:00:00 `
            -State Active
    }

    $dhcpOptions = Get-DhcpServerv4OptionValue
    if ($dhcpOptions.Count -lt 3) {
        Set-DhcpServerv4OptionValue -ComputerName localhost `
            -DnsDomain $dnsClient.ConnectionSpecificSuffix `
            -DnsServer 168.63.129.16, 10.16.2.100 `
            -Router 10.10.1.1 `
            -Force
    }

    # Create the NAT network
    Write-Host "Creating Internal NAT"
    $natName = "InternalNat"
    $netNat = Get-NetNat
    if ($netNat.Name -ne $natName) {
        New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24
    }

    # Create an internal switch with NAT
    Write-Host "Creating Internal vSwitch"
    $switchName = 'InternalNATSwitch'
    
    # Verify if internal switch is already created, if not create a new switch
    $internalSwitch = Get-VMSwitch
    if ($internalSwitch.Name -ne $switchName) {
        New-VMSwitch -Name $switchName -SwitchType Internal
        $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*" + $switchName + "*" }

        # Create an internal network (gateway first)
        Write-Host "Creating Gateway"
        New-NetIPAddress -IPAddress 10.10.1.1 -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

        # Enable Enhanced Session Mode on Host
        Write-Host "Enabling Enhanced Session Mode"
        Set-VMHost -EnableEnhancedSessionMode $true
    }

    Write-Host "Creating VM Credentials"
    # Hard-coded username and password for the nested Windows VMs
    $nestedWindowsUsername = "Administrator"
    $nestedWindowsPassword = "ArcDemo123!!"

    # Hard-coded username and password for the nested SQL VMs
    $nestedSQLUsername = "Administrator"
    $nestedSQLPassword = "JS123!!"
   

    # Create Windows credential object
    $secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
    $winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

    # Create Windows credential object
    $secSQLPassword = ConvertTo-SecureString $nestedSQLPassword -AsPlainText -Force
    $SQLCreds = New-Object System.Management.Automation.PSCredential ($nestedSQLUsername, $secSQLPassword)

    # Creating Hyper-V Manager desktop shortcut
    Write-Host "Creating Hyper-V Shortcut"
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk" -Destination "C:\Users\All Users\Desktop" -Force

    # Configure the ESU Hyper-V host to allow the nested VMs onboard as Azure Arc-enabled servers
    Write-Host "Blocking IMDS"
    Write-Host "Configure the ESU VM to allow the nested VMs onboard as Azure Arc-enabled servers"
    Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
    Stop-Service WindowsAzureGuestAgent -Force -Verbose

    if (!(Get-NetFirewallRule -Name BlockAzureIMDS -ErrorAction SilentlyContinue).Enabled) {
        New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254
    }

    $cliDir = New-Item -Path "$Env:ESUDir\.cli\" -Name ".servers" -ItemType Directory -Force
    if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
        $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
        $folder.Attributes += [System.IO.FileAttributes]::Hidden
    }

    $Env:AZURE_CONFIG_DIR = $cliDir.FullName

    # Install Azure CLI extensions
    Write-Host "Az CLI extensions"
    az extension add --name ssh --yes --only-show-errors
    az extension add --name log-analytics-solution --yes --only-show-errors
    az extension add --name connectedmachine --yes --only-show-errors

    # Required for CLI commands
    Write-Host "Az CLI Login"
    az login --service-principal --username $Env:spnClientId --password $Env:spnClientSecret --tenant $Env:spnTenantId

    # Register Azure providers
    Write-Host "Registering Providers"
    az provider register --namespace Microsoft.HybridCompute --wait --only-show-errors
    az provider register --namespace Microsoft.HybridConnectivity --wait --only-show-errors
    az provider register --namespace Microsoft.GuestConfiguration --wait --only-show-errors

   
    if ( $esu -eq "WS" -or $esu -eq "ws" )
    {
        $imageName = "JSWin2K12Base"
        $vmvhdPath = "$Env:ESUVMDir\${imageName}.vhdx"
        # Moved VHD storage account details here to keep only in place to prevent duplicates.
        $vhdDownload = "https://jsvhds.blob.core.windows.net/scenarios/prod/JSWin2K12Base.vhdx?sp=r&st=2023-09-11T08:05:53Z&se=2025-11-08T17:05:53Z&spr=https&sv=2022-11-02&sr=b&sig=zoVpd9AMzsTRRE0a7eLJYeFURexY4R9VSzOGKfLOx%2FQ%3D"

    Write-Host "Fetching VM"

    # Verify if VHD files already downloaded especially when re-running this script
    if (!([System.IO.File]::Exists($vmvhdPath) )) {
        <# Action when all if and elseif conditions are false #>
        $Env:AZCOPY_BUFFER_GB = 4
        Write-Host "Downloading nested VMs VHDX file for VM. This can take some time, hold tight..."
        azcopy copy $vhdDownload --include-pattern "${imageName}.vhdx" $Env:ESUVMDir --check-length=false --cap-mbps 1200 --log-level=ERROR
    }

    # Create the nested VMs if not already created
    Write-Host "Create Hyper-V VMs"

    $vmName = "JSWin2K12Base"

    # Create the nested VM
    Write-Host "Create VM"
    if ((Get-VM -Name $vmName -ErrorAction SilentlyContinue).State -ne "Running") {
        Remove-VM -Name $vmName -Force -ErrorAction SilentlyContinue
        New-VM -Name $vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $vmvhdPath -Path $Env:ESUVMDir -Generation 2 -Switch $switchName
        Set-VMProcessor -VMName $vmName -Count 2
        Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    }

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Host "Set VM Auto Start/Stop"
    Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Host "Enabling Guest Integration Service"
    Get-VM -Name $vmName | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

    # Start all the VMs
    Write-Host "Starting VM"
    Start-VM -Name $vmName

    #Configure WinRM
    Enable-PSRemoting
    set-item wsman:\localhost\client\trustedhosts -Concatenate -value '10.10.1.100' -Force
    set-item wsman:\localhost\client\trustedhosts -Concatenate -value "$vmName" -Force
    Restart-Service WinRm -Force
    $file = "C:\Windows\System32\drivers\etc\hosts"
    $hostfile = Get-Content $file
    $hostfile += "10.10.1.100 $vmName"
    Set-Content -Path $file -Value $hostfile -Force

    # Restarting Windows VM Network Adapters
    Write-Host "Restarting Network Adapters"
    Start-Sleep -Seconds 20
    Invoke-Command -ComputerName $vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 90

    # Copy installation script to nested Windows VMs
    Write-Host "Transferring installation script to nested Windows VMs..."
    Copy-VMFile $vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ESUDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force

    Write-Host "Onboarding Arc-enabled servers"

    # Onboarding the nested VMs as Azure Arc-enabled servers
    Write-Host "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
    Invoke-Command -ComputerName $vmName -ScriptBlock { powershell -File $Using:nestedVMESUDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds

    }

    if ( $esu -eq "SQL" -or $esu -eq "sql" )
    {
        $imageName = "JSSQL12Base"
        $vmvhdPath = "$Env:ESUVMDir\${imageName}.vhdx"
        # Moved VHD storage account details here to keep only in place to prevent duplicates.
        $vhdDownload = "https://jsvhds.blob.core.windows.net/scenarios/prod/JSSQL12Base.vhdx?sp=r&st=2023-09-27T06:57:38Z&se=2027-09-11T14:57:38Z&spr=https&sv=2022-11-02&sr=b&sig=BXtEL%2B7RdLairRHXd3TA6n5q%2FNktjItvcU1rzol9Dl0%3D"

    Write-Host "Fetching VM"

    # Verify if VHD files already downloaded especially when re-running this script
    if (!([System.IO.File]::Exists($vmvhdPath) )) {
        <# Action when all if and elseif conditions are false #>
        $Env:AZCOPY_BUFFER_GB = 4
        Write-Host "Downloading nested VMs VHDX file for VM. This can take some time, hold tight..."
        azcopy copy $vhdDownload --include-pattern "${imageName}.vhdx" $Env:ESUVMDir --check-length=false --cap-mbps 1200 --log-level=ERROR
    }

    # Create the nested VMs if not already created
    Write-Host "Create Hyper-V VMs"
    $vmName = "JSSQL12Base"
    # Create the nested VM
    Write-Host "Create VM"
    if ((Get-VM -Name $vmName -ErrorAction SilentlyContinue).State -ne "Running") {
        Remove-VM -Name $vmName -Force -ErrorAction SilentlyContinue
        New-VM -Name $vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $vmvhdPath -Path $Env:ESUVMDir -Generation 2 -Switch $switchName
        Set-VMProcessor -VMName $vmName -Count 2
        Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
    }

    # We always want the VMs to start with the host and shut down cleanly with the host
    Write-Host "Set VM Auto Start/Stop"
    Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    Write-Host "Enabling Guest Integration Service"
    Get-VM -Name $vmName | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose

    # Start all the VMs
    Write-Host "Starting VM"
    Start-VM -Name $vmName

    #Configure WinRM
    Enable-PSRemoting
    set-item wsman:\localhost\client\trustedhosts -Concatenate -value '10.10.1.100' -Force
    set-item wsman:\localhost\client\trustedhosts -Concatenate -value "$vmName" -Force
    Restart-Service WinRm -Force
    $file = "C:\Windows\System32\drivers\etc\hosts"
    $hostfile = Get-Content $file
    $hostfile += "10.10.1.100 $vmName"
    Set-Content -Path $file -Value $hostfile -Force

    # Restarting Windows VM Network Adapters
    Write-Host "Restarting Network Adapters"
    Start-Sleep -Seconds 20
    Invoke-Command -ComputerName $vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $SQLCreds
    Start-Sleep -Seconds 90

    # Copy installation script to nested Windows VMs
    Write-Host "Transferring installation script to nested Windows VMs..."
    Copy-VMFile $vmName -SourcePath "$agentScript\installArcAgentSQL.ps1" -DestinationPath "$Env:ESUDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force

    Write-Host "Onboarding Arc-enabled servers"

    # Onboarding the nested VMs as Azure Arc-enabled servers
    Write-Host "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
    Invoke-Command -ComputerName $vmName -ScriptBlock { powershell -File $Using:nestedVMESUDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $SQLCreds

    }

    if ( $esu -eq "both" -or $esu -eq "BOTH" -or $esu -eq "Both" )
    {
        $SiteConfig = @{
            JSWin2K12Base = @{
                imageName = 'JSWin2K12Base'
                vmvhdPath = "$Env:ESUVMDir\JSWin2K12Base.vhdx"
                vhdDownload = "https://jsvhds.blob.core.windows.net/scenarios/prod/JSWin2K12Base.vhdx?sp=r&st=2023-09-11T08:05:53Z&se=2025-11-08T17:05:53Z&spr=https&sv=2022-11-02&sr=b&sig=zoVpd9AMzsTRRE0a7eLJYeFURexY4R9VSzOGKfLOx%2FQ%3D"
                vmName = "JSWin2K12Base"
                ip = "10.10.1.100"
                type = "Windows"
            }
            JSSQL12Base = @{
                imageName = "JSSQL12Base"
                vmvhdPath = "$Env:ESUVMDir\JSSQL12Base.vhdx"
                vhdDownload = "https://jsvhds.blob.core.windows.net/scenarios/prod/JSSQL12Base.vhdx?sp=r&st=2023-09-27T06:57:38Z&se=2027-09-11T14:57:38Z&spr=https&sv=2022-11-02&sr=b&sig=BXtEL%2B7RdLairRHXd3TA6n5q%2FNktjItvcU1rzol9Dl0%3D"
                vmName = "JSSQL12Base"
                ip = "10.10.1.101"
                type = "SQL"
            }
    }


          Write-Host "Downloading nested VMs VHDX file for VM. This can take some time, hold tight..."
          azcopy copy $SiteConfig.JSWin2K12Base.vhdDownload $Env:ESUVMDir --check-length=false --cap-mbps 1200 --log-level=ERROR
          azcopy copy $SiteConfig.JSSQL12Base.vhdDownload $Env:ESUVMDir --check-length=false --cap-mbps 1200 --log-level=ERROR

          foreach ($site in $SiteConfig.GetEnumerator()) {
          
          
          # Create the nested VMs if not already created
          Write-Host "Create Hyper-V VMs"

          # Create the nested VM
          Write-Host "Create VM"
          if ((Get-VM -Name $site.Value.vmName -ErrorAction SilentlyContinue).State -ne "Running") {
              Remove-VM -Name $site.Value.vmName -Force -ErrorAction SilentlyContinue
              New-VM -Name $site.Value.vmName -MemoryStartupBytes 12GB -BootDevice VHD -VHDPath $site.Value.vmvhdPath -Path $Env:ESUVMDir -Generation 2 -Switch $switchName
              Set-VMProcessor -VMName $site.Value.vmName -Count 2
              Set-VM -Name $site.Value.vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
          }
      
          # We always want the VMs to start with the host and shut down cleanly with the host
          Write-Host "Set VM Auto Start/Stop"
          Set-VM -Name $site.Value.vmName -AutomaticStartAction Start -AutomaticStopAction ShutDown
      
          Write-Host "Enabling Guest Integration Service"
          Get-VM -Name $site.Value.vmName | Get-VMIntegrationService | Where-Object { -not($_.Enabled) } | Enable-VMIntegrationService -Verbose
      
          # Start all the VMs
          Write-Host "Starting VM"
          Start-VM -Name $site.Value.vmName
      
          #Configure WinRM
          
          Enable-PSRemoting
          set-item wsman:\localhost\client\trustedhosts -Concatenate -value $site.Value.ip -Force
          set-item wsman:\localhost\client\trustedhosts -Concatenate -value $site.Value.vmName -Force
          Restart-Service WinRm -Force
          $file = "C:\Windows\System32\drivers\etc\hosts"
          $hostfile = Get-Content $file
          $entry = -join($site.Value.ip, " ", $site.Value.vmName)
          $hostfile += $entry
          Set-Content -Path $file -Value $hostfile -Force
      
          # Restarting Windows VM Network Adapters
          Write-Host "Restarting Network Adapters"
          Start-Sleep -Seconds 20
          if ($site.Value.vmName -eq "JSWin2K12Base") {
          Invoke-Command -ComputerName $site.Value.vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
            }
            else {
          Invoke-Command -ComputerName $site.Value.vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $SQLCreds
            }
          Start-Sleep -Seconds 90
      
          # Copy installation script to nested Windows VMs


          if ( $site.Value.type -eq "Windows")
          {
            Write-Host "Transferring installation script to nested Windows VMs..."
            Copy-VMFile $site.Value.vmName -SourcePath "$agentScript\installArcAgent.ps1" -DestinationPath "$Env:ESUDir\installArcAgent.ps1" -CreateFullPath -FileSource Host -Force
            Write-Host "Onboarding Arc-enabled servers"
      
            # Onboarding the nested VMs as Azure Arc-enabled servers
            Write-Host "Onboarding the nested Windows VMs as Azure Arc-enabled servers"
            Invoke-Command -ComputerName $site.Value.vmName -ScriptBlock { powershell -File $Using:nestedVMESUDir\installArcAgent.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $winCreds
          }

          if ( $site.Value.type -eq "SQL")
          {
            Write-Host "Transferring installation script to nested SQL VMs..."
            Copy-VMFile $site.Value.vmName -SourcePath "$agentScript\installArcAgentSQL.ps1" -DestinationPath "$Env:ESUDir\installArcAgentSQL.ps1" -CreateFullPath -FileSource Host -Force
            Write-Host "Onboarding Arc-enabled SQL Server"
      
            # Onboarding the nested VMs as Azure Arc-enabled SQL Server
            Write-Host "Onboarding the nested SQL VMs as Azure Arc-enabled SQL server"
            Invoke-Command -ComputerName $site.Value.vmName -ScriptBlock { powershell -File $Using:nestedVMESUDir\installArcAgentSQL.ps1 -spnClientId $Using:spnClientId, -spnClientSecret $Using:spnClientSecret, -spnTenantId $Using:spnTenantId, -subscriptionId $Using:subscriptionId, -resourceGroup $Using:resourceGroup, -azureLocation $Using:azureLocation } -Credential $SQLCreds
          }
        }
    }

    

    # Removing the LogonScript Scheduled Task so it won't run on next reboot
    Write-Host "Removing Logon Task"
    if ($null -ne (Get-ScheduledTask -TaskName "LogonScript" -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
    }

# Changing to Jumpstart  wallpaper

$imgPath = "$Env:ESUDir\wallpaper.png"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
    public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
        static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
        
        public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
        }
    }
} 
'@

    Write-Host "Changing Wallpaper"
    $imgPath = "$Env:ESUDir\wallpaper.png"
    Add-Type $code
    [Win32.Wallpaper]::SetWallpaper($imgPath)

Stop-Transcript
