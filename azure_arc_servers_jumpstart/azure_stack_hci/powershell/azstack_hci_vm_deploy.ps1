# Powershell script to deploy VM in Azure Stack HCI and Arc enable it

# Environment variables for the optional configurations
$DHCPEnabled = 'Select $true if DHCP is enabled on your environment, $false if not'

    #If $DHCPEnabled = $false, please fill the following variables. Otherwise, attribute the value $null
    $IPAddress = 'Provide the static IP to assign the to the VM'
    $PrefixLenght = 'Provide the length of the subnet mask to assign to the VM'
    $DefaultGateway = 'Provide the default gateway to assign to the VM'
    $DNSServer = 'Provide the DNS Server to assign to the VM'

$ServerClusterEnabled = 'Select $true if you have a server cluster created, $false if the not'
    
    #If $ServerClusterEnabled = $true,  please provide the path to the cluster storage in the format "<Disk Letter>:\Folder"
    #If $ServerClusterEnabled = $false, please provide the path to a folder where the VM will be created in the format "<Disk Letter>:\Folder"
    $vmdir =  "<Disk Letter>:\Folder"

# Environment variables for the VM creation
$NodeName = 'Provide the name of the node where the VM will be created'
$DomainName = 'Provide the name of the domain where the node is added'
$VMName = 'Provide the name of the VM'
$VSwitchName = 'Provide the name of the Virtual Switch'

# Environment variables to onboard the VM to Azure Arc
$subID = "Provide the subscriptionID"
$appID =  "Provide the Service Principal ApplicationID"
$secret = "Provide the Service Principal Secret"
$tID = "Provide the tenantID"
$rgroup = "Provide the Resource Group Name"
$location = "Provide the Region"

# Deployment
$pos = $vmdir.IndexOf(":")
$leftPart = $vmdir.Substring(0, $pos)
$rightPart = $vmdir.Substring($pos+1)
$nodepath = "\\" + $NodeName + '\' +  $leftPart + "$" + $rightpart

# Download of Windows VM VHDX file 
New-Item -Path $nodepath -Name "ArcJumpstart" -ItemType "directory"
Write-Verbose "Downloading Windows Server VHDX file. Hold tight, this might take a few minutes..." -Verbose
function downloadVHDx() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri "https://azhcicloudwitness1123.blob.core.windows.net/vhds/ArcVM-HCIJS-win.vhdx"  -OutFile $nodepath\ArcJumpstart\ArcVM-HCIJS-win.vhdx}
downloadVHDx

# Enable CredSSP
Set-Item WSMAN:\localhost\client\auth\credssp –value $true
Enable-WSManCredSSP -Role Client -DelegateComputer "$NodeName.$DomainName"

# PS Remote Session to Host
Write-Verbose "Insert credentials for node $NodeName ..." -Verbose
$CustomCred = Get-Credential
$s = New-PSSession -ComputerName "$NodeName.$DomainName" -Credential $CustomCred -Authentication Credssp 

Write-Verbose "Starting Powershell Remote Session to $NodeName ..." -Verbose
Invoke-Command -Session $s -ScriptBlock{

    # Windows VM creation

    Write-Verbose "Creating VM $using:VMName in $using:NodeName ..." -Verbose
    New-VM -Name $using:VMName -MemoryStartupBytes 2GB -BootDevice VHD -VHDPath "$using:vmdir\ArcJumpstart\ArcVM-HCIJS-win.vhdx" -Path "$using:vmdir\ArcJumpstart" -Generation 2 -Switch $using:VSwitchName
    Set-VMProcessor -VMName $using:VMName -Count 2

    Write-Verbose "Set VM auto start/stop" -Verbose
    Set-VM  -Name $using:VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown

    if($using:ServerClusterEnabled){
        #Add VM to cluster
        Write-Verbose "Adding VM $using:VMName in Server Cluster ..." -Verbose
        Add-ClusterVirtualMachineRole -VirtualMachine $using:VMName
    }
    
    Write-Verbose "Starting VM $using:VMName ..." -Verbose
    Start-VM –Name $using:VMName
    Start-Sleep -Seconds 20
}

#Assign IP address manually or DHCP
if (!$DHCPEnabled){
    Invoke-Command -Session $s -ScriptBlock{
            
            $User = "Administrator"
            $PWord = ConvertTo-SecureString -String 'Pa$$w0rd1234' -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
            
            Write-Verbose "Assigning static IP to VM $using:VMName ..." -Verbose
            Invoke-Command -VMName $using:VMName -Credential $Credential -ArgumentList $using:IPAddress, $using:DefaultGateway, $using:PrefixLenght, $using:DNSServer -ScriptBlock{
            
                Remove-NetIPAddress -InterfaceIndex (Get-NetAdapter).InterfaceIndex
                Remove-NetRoute -InterfaceIndex (Get-NetAdapter).InterfaceIndex
                New-NetIPAddress –IPAddress $args[0] -DefaultGateway $args[1] -PrefixLength $args[2] -InterfaceIndex (Get-NetAdapter).InterfaceIndex
                Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter).InterfaceIndex -ServerAddresses $args[3]
           }
    }
}

Start-Sleep -Seconds 20

#Azure Arc Agent Installation
Write-Verbose "Installing Azure Arc agent in VM $VMName ..." -Verbose
Invoke-Command -Session $s -ScriptBlock{
            
            $User = "Administrator"
            $PWord = ConvertTo-SecureString -String 'Pa$$w0rd1234' -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
            
            Invoke-Command -VMName $using:VMName -Credential $Credential -ArgumentList $using:subID, $using:appID, $using:secret, $using:tID, $using:rgroup, $using:location -ScriptBlock{
            
                $env:subscriptionId=$args[0]
                $env:appId=$args[1]
                $env:password=$args[2]
                $env:tenantId=$args[3]
                $env:resourceGroup=$args[4]
                $env:location=$args[5]

                # Download the package
                function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
                download

                # Install the package
                msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

                # Run connect command
                 & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
                 --resource-name "Arc-AzsHCI-VM01" `
                 --service-principal-id $env:appId `
                 --service-principal-secret $env:password `
                 --resource-group $env:resourceGroup `
                 --tenant-id $env:tenantId `
                 --location $env:location `
                 --subscription-id $env:subscriptionId `
                 --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

           }
}

Write-Verbose "Installation completed!" -Verbose
