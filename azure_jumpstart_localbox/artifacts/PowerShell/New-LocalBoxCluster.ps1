Start-Transcript -Path $Env:LocalBoxLogsDir\New-LocalBoxCluster.log
$starttime = Get-Date

# Import Configuration data file
$Global:LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile

#region Main
$HostVMPath = $LocalBoxConfig.HostVMPath
$InternalSwitch = $LocalBoxConfig.InternalSwitch
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup

Import-Module Hyper-V

Update-AzDeploymentProgressTag -ProgressString 'Downloading nested VMs VHDX files' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Create paths
foreach ($path in $LocalBoxConfig.Paths.GetEnumerator()) {
    Write-Host "Creating $($path.Key) path at $($path.Value)"
    New-Item -Path $path.Value -ItemType Directory -Force | Out-Null
}

# Download LocalBox VHDs
Write-Host "[Build cluster - Step 1/11] Downloading LocalBox VHDs" -ForegroundColor Green

$Env:AZCOPY_BUFFER_GB = 4
Write-Output "Downloading nested VMs VHDX files. This can take some time, hold tight..."

#azcopy cp 'https://jumpstartprodsg.blob.core.windows.net/jslocal/localbox/prod/AzLocal2509.vhdx' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.vhdx" --recursive=true --check-length=false --log-level=ERROR
#azcopy cp 'https://jumpstartprodsg.blob.core.windows.net/jslocal/localbox/prod/AzLocal2509.sha256' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.sha256" --recursive=true --check-length=false --log-level=ERROR

azcopy cp 'https://azlocalvhds.blob.core.windows.net/images/AzLocal2601.vhdx' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.vhdx" --recursive=true --check-length=false --log-level=ERROR
azcopy cp 'https://azlocalvhds.blob.core.windows.net/images/AzLocal2601.sha256' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.sha256" --recursive=true --check-length=false --log-level=ERROR

$checksum = Get-FileHash -Path "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.vhdx"
$hash = Get-Content -Path "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.sha256"
if ($checksum.Hash -eq $hash) {
    Write-Host "AZSCHI.vhdx has valid checksum. Continuing..."
}
else {
    Write-Error "AZSCHI.vhdx is corrupt. Aborting deployment. Re-run C:\LocalBox\LocalBoxLogonScript.ps1 to retry"
    throw
}

azcopy cp https://jumpstartprodsg.blob.core.windows.net/hcibox23h2/WinServerApril2024.vhdx "$($LocalBoxConfig.Paths.VHDDir)\GUI.vhdx" --recursive=true --check-length=false --log-level=ERROR
azcopy cp https://jumpstartprodsg.blob.core.windows.net/hcibox23h2/WinServerApril2024.sha256 "$($LocalBoxConfig.Paths.VHDDir)\GUI.sha256" --recursive=true --check-length=false --log-level=ERROR

$checksum = Get-FileHash -Path "$($LocalBoxConfig.Paths.VHDDir)\GUI.vhdx"
$hash = Get-Content -Path "$($LocalBoxConfig.Paths.VHDDir)\GUI.sha256"
if ($checksum.Hash -eq $hash) {
    Write-Host "GUI.vhdx has valid checksum. Continuing..."
}
else {
    Write-Error "GUI.vhdx is corrupt. Aborting deployment. Re-run C:\LocalBox\LocalBoxLogonScript.ps1 to retry"
    throw
}

# Set credentials
$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "Administrator", (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($LocalBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Enable PSRemoting
Write-Host "[Build cluster - Step 2/11] Preparing Azure VM virtualization host..." -ForegroundColor Green
Write-Host "Enabling PS Remoting on client..."
Enable-PSRemoting
set-item WSMan:localhost\client\trustedhosts -value * -Force
Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($LocalBoxConfig.SDNDomainFQDN)" -Force

###############################################################################
# Configure Hyper-V host
###############################################################################

Update-AzDeploymentProgressTag -ProgressString 'Configure Hyper-V host' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

Write-Host "Checking internet connectivity"
Test-InternetConnect

Write-Host "Creating Internal Switch"
New-InternalSwitch -LocalBoxConfig $LocalBoxConfig

Write-Host "Creating NAT Switch"
Set-HostNAT -LocalBoxConfig $LocalBoxConfig

Write-Host "Configuring LocalBox-Client Hyper-V host"
Set-VMHost -VirtualHardDiskPath $HostVMPath -VirtualMachinePath $HostVMPath -EnableEnhancedSessionMode $true

Write-Host "Copying VHDX Files to Host virtualization drive"
$guipath = "$HostVMPath\GUI.vhdx"
$azlocalpath = "$HostVMPath\AzL-node.vhdx"

# Copy with verification and retry (prevents silent failures that leave VMs without OS disks)
$maxRetries = 3
$vhdxCopies = @(
    @{ Source = $LocalBoxConfig.guiVHDXPath;      Dest = $guipath;      Name = "GUI" },
    @{ Source = $LocalBoxConfig.AzLocalVHDXPath;   Dest = $azlocalpath;  Name = "AzLocal" }
)
foreach ($copy in $vhdxCopies) {
    if (-not (Test-Path $copy.Source)) {
        Write-Error "$($copy.Name) source VHDX not found at $($copy.Source). Aborting."
        throw "$($copy.Name) source VHDX not found at $($copy.Source)"
    }
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        Write-Host "  Copying $($copy.Name) VHDX (attempt $attempt/$maxRetries)..."
        try {
            Copy-Item -Path $copy.Source -Destination $copy.Dest -Force -ErrorAction Stop
        } catch {
            Write-Warning "  $($copy.Name) VHDX copy attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -eq $maxRetries) {
                Write-Error "$($copy.Name) VHDX copy failed after $maxRetries attempts. Source: $($copy.Source) Dest: $($copy.Dest)"
                throw "$($copy.Name) VHDX copy failed after $maxRetries attempts"
            }
            Start-Sleep -Seconds 10
            continue
        }
        if (Test-Path $copy.Dest) {
            $srcSize = (Get-Item $copy.Source).Length
            $dstSize = (Get-Item $copy.Dest -ErrorAction SilentlyContinue).Length
            if ($srcSize -eq $dstSize) {
                Write-Host "  $($copy.Name) VHDX copied successfully ($([math]::Round($dstSize/1GB,1)) GB)"
                break
            }
            Write-Warning "  $($copy.Name) VHDX size mismatch (src=$srcSize dst=$dstSize), retrying..."
            Remove-Item $copy.Dest -Force -ErrorAction SilentlyContinue
        } else {
            Write-Warning "  $($copy.Name) VHDX copy did not create destination file, retrying..."
        }
        if ($attempt -eq $maxRetries) {
            Write-Error "$($copy.Name) VHDX copy failed after $maxRetries attempts. Source: $($copy.Source) Dest: $($copy.Dest)"
            throw "$($copy.Name) VHDX copy failed after $maxRetries attempts"
        }
        Start-Sleep -Seconds 10
    }
}

################################################################################
# Create the three nested Virtual Machines
################################################################################

Update-AzDeploymentProgressTag -ProgressString 'Creating and configuring nested VMs' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# First create the Management VM (AzSMGMT)
Write-Host "[Build cluster - Step 3/11] Creating Management VM (AzLMGMT)..." -ForegroundColor Green

Update-AzDeploymentProgressTag -ProgressString 'Creating Management VM (AzLMGMT)' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

$mgmtMac = New-ManagementVM -Name $($LocalBoxConfig.MgmtHostConfig.Hostname) -VHDXPath "$HostVMPath\GUI.vhdx" -VMSwitch $InternalSwitch -LocalBoxConfig $LocalBoxConfig
Set-MgmtVhdx -VMMac $mgmtMac -LocalBoxConfig $LocalBoxConfig

# Create the Azure Local node VMs
Write-Host "[Build cluster - Step 4/11] Creating Azure Local node VMs (AzLHOSTx)..." -ForegroundColor Green

Update-AzDeploymentProgressTag -ProgressString 'Creating Azure Local node VMs (AzLHOSTx)' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

foreach ($VM in $LocalBoxConfig.NodeHostConfig) {
    $mac = New-AzLocalNodeVM -Name $VM.Hostname -VHDXPath $azlocalpath -VMSwitch $InternalSwitch -LocalBoxConfig $LocalBoxConfig
    if ([string]::IsNullOrWhiteSpace($mac)) {
        Write-Error "New-AzLocalNodeVM returned null/empty MAC for $($VM.Hostname). Aborting."
        throw "No MAC address returned for $($VM.Hostname)"
    }
    # Verify the node VM was created before proceeding
    $nodeVm = Get-VM -Name $VM.Hostname -ErrorAction SilentlyContinue
    if (-not $nodeVm) {
        Write-Error "Hyper-V VM '$($VM.Hostname)' not found after New-AzLocalNodeVM. Aborting."
        throw "Failed to create Hyper-V VM $($VM.Hostname)"
    }
    $vhdPath = ($nodeVm | Get-VMHardDiskDrive | Select-Object -First 1).Path
    if (-not $vhdPath -or -not (Test-Path $vhdPath)) {
        Write-Error "Node VM VHDX not found at $vhdPath after New-AzLocalNodeVM. Aborting."
        throw "Failed to create VHDX for $($VM.Hostname)"
    }
    Write-Host "  $($VM.Hostname) VM created successfully (VHDX: $([math]::Round((Get-Item $vhdPath).Length/1GB,1)) GB)"
    Set-AzLocalNodeVhdx -HostName $VM.Hostname -IPAddress $VM.IP -VMMac $mac -LocalBoxConfig $LocalBoxConfig
}

# Start Virtual Machines
Write-Host "[Build cluster - Step 5/11] Starting VMs..." -ForegroundColor Green
Write-Host "Starting VM: $($LocalBoxConfig.MgmtHostConfig.Hostname)"
Start-VM -Name $LocalBoxConfig.MgmtHostConfig.Hostname
foreach ($VM in $LocalBoxConfig.NodeHostConfig) {
    Write-Host "Starting VM: $($VM.Hostname)"
    Start-VM -Name $VM.Hostname
}

#######################################################################################
# Prep the virtualization environment
#######################################################################################
Write-Host "[Build cluster - Step 6/11] Configuring host networking and storage..." -ForegroundColor Green

Update-AzDeploymentProgressTag -ProgressString 'Configuring host networking and storage...' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Wait for AzSHOSTs to come online
Test-AllVMsAvailable -LocalBoxConfig $LocalBoxConfig -Credential $localCred

Start-Sleep -Seconds 60

# Format and partition data drives
Set-DataDrives -LocalBoxConfig $LocalBoxConfig -Credential $localCred

# Configure networking
Set-NICs -LocalBoxConfig $LocalBoxConfig -Credential $localCred

# Create NAT Virtual Switch on AzSMGMT
New-NATSwitch -LocalBoxConfig $LocalBoxConfig

# Configure fabric network on AzSMGMT
Set-FabricNetwork -LocalBoxConfig $LocalBoxConfig -localCred $localCred -domainCred $domainCred

#######################################################################################
# Provision the router, domain controller, and WAC VMs and join the hosts to the domain
#######################################################################################

Update-AzDeploymentProgressTag -ProgressString 'Provisioning Router VM' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Provision Router VM on AzSMGMT
Write-Host "[Build cluster - Step 7/11] Build router VM..." -ForegroundColor Green
New-RouterVM -LocalBoxConfig $LocalBoxConfig -localCred $localCred

Update-AzDeploymentProgressTag -ProgressString 'Provisioning Domain controller VM' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Provision Domain controller VM on AzSMGMT
Write-Host "[Build cluster - Step 8/11] Building Domain Controller VM..." -ForegroundColor Green

Update-AzDeploymentProgressTag -ProgressString 'Building Domain Controller VM...' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

New-DCVM -LocalBoxConfig $LocalBoxConfig -localCred $localCred -domainCred $domainCred

# Provision Admincenter VM
# Write-Host "[Build cluster - Step 9/12] Building Windows Admin Center gateway server VM... (skipping step)" -ForegroundColor Green
#New-AdminCenterVM -LocalBoxConfig $LocalBoxConfig -localCred $localCred -domainCred $domainCred

Write-Host "[Build cluster - Step 9/11] Preparing Azure local cluster cloud deployment..." -ForegroundColor Green

Update-AzDeploymentProgressTag -ProgressString 'Preparing Azure Local cluster deployment' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

Invoke-AzureEdgeBootstrap -LocalBoxConfig $LocalBoxConfig -localCred $localCred

Set-AzLocalDeployPrereqs -LocalBoxConfig $LocalBoxConfig -localCred $localCred -domainCred $domainCred

& "$Env:LocalBoxDir\Generate-ARM-Template.ps1"

#######################################################################################
# Validate and deploy the cluster
#######################################################################################

Write-Host "[Build cluster - Step 10/11] Validate cluster deployment..." -ForegroundColor Green

# Ensure mandatory resource providers are registered before HCI validation
# This prevents the "ArcIntegration requirements not met" error (step 90)
# when providers registered in Phase 1 haven't fully propagated
Write-Host "Verifying mandatory resource provider registrations..." -ForegroundColor Yellow
$mandatoryProviders = @(
    "Microsoft.KubernetesConfiguration",
    "Microsoft.ExtendedLocation",
    "Microsoft.HybridContainerService",
    "Microsoft.HybridCompute",
    "Microsoft.AzureStackHCI",
    "Microsoft.ResourceConnector",
    "Microsoft.Kubernetes",
    "Microsoft.EdgeMarketplace"
)
foreach ($rp in $mandatoryProviders) {
    $rpState = (Get-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue).RegistrationState | Select-Object -Unique
    if ($rpState -ne 'Registered') {
        Write-Host "  Registering $rp (current: $($rpState -join ', '))..." -ForegroundColor Yellow
        Register-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue | Out-Null
    }
}
# Poll until all are Registered (max 5 minutes)
$rpDeadline = (Get-Date).AddMinutes(5)
$allRegistered = $false
while (-not $allRegistered -and (Get-Date) -lt $rpDeadline) {
    $allRegistered = $true
    foreach ($rp in $mandatoryProviders) {
        $rpState = (Get-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue).RegistrationState | Select-Object -Unique
        if ($rpState -ne 'Registered') {
            $allRegistered = $false
            Write-Host "  Waiting for $rp registration ($($rpState -join ', '))..." -ForegroundColor DarkGray
            break
        }
    }
    if (-not $allRegistered) {
        Start-Sleep -Seconds 15
    }
}
if ($allRegistered) {
    Write-Host "All mandatory resource providers verified as Registered" -ForegroundColor Green
} else {
    Write-Warning "Some providers may not be fully registered — proceeding anyway (HCI validation will catch remaining issues)"
}

# Wait before starting validation to allow Connected Machines to register device information
Start-Sleep -Seconds 600

if ("True" -eq $env:autoDeployClusterResource) {

Update-AzDeploymentProgressTag -ProgressString 'Validating Azure Local cluster deployment' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

$TemplateFile = Join-Path -Path $env:LocalBoxDir -ChildPath "azlocal.json"
$TemplateParameterFile = Join-Path -Path $env:LocalBoxDir -ChildPath "azlocal.parameters.json"

try {
    New-AzResourceGroupDeployment -Name 'localcluster-validate' -ResourceGroupName $env:resourceGroup -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile -OutVariable ClusterValidationDeployment -ErrorAction Stop
}
catch {
    Write-Output "Validation failed. Re-run New-AzResourceGroupDeployment to retry. Error: $($_.Exception.Message)"
}


<#
  Adding known governance tags for avoiding disruptions to the deployment. These tags are applicable to ONLY Microsoft-internal Azure lab tenants and designed for managing automated governance processes related to cost optimization and security controls.
  Some resources are not created by the Bicep template for LocalBox, hence the need to add them here as part of the automation.
#>

$VmResource = Get-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines'

if ($VmResource.Tags.ContainsKey('CostControl') -and $VmResource.Tags.ContainsKey('SecurityControl')) {

    if($VmResource.Tags.CostControl -eq 'Ignore' -and $VmResource.Tags.SecurityControl -eq 'Ignore') {

        Write-Output "CostControl and SecurityControl tags are set to 'Ignore' for the VM resource, adding them to other resources created by the Azure Local deployment"

        $tags = @{
            'CostControl' = 'Ignore'
            'SecurityControl' = 'Ignore'
        }

        Get-AzResource -ResourceGroupName $env:resourceGroup -ResourceType 'Microsoft.KeyVault/vaults' | Update-AzTag -Tag $tags -Operation Merge

        Get-AzResource -ResourceGroupName $env:resourceGroup -ResourceType 'Microsoft.Storage/storageAccounts' | Update-AzTag -Tag $tags -Operation Merge

        Get-AzResource -ResourceGroupName $env:resourceGroup -ResourceType 'Microsoft.Compute/disks' | Update-AzTag -Tag $tags -Operation Merge

    }

}

Write-Host "[Build cluster - Step 11/11] Run cluster deployment..." -ForegroundColor Green

if ($ClusterValidationDeployment.ProvisioningState -eq "Succeeded") {


    Update-AzDeploymentProgressTag -ProgressString 'Deploying Azure Local cluster' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

    Write-Host "Validation succeeded. Deploying Local cluster..."

    try {
        New-AzResourceGroupDeployment -Name 'localcluster-deploy' -ResourceGroupName $env:resourceGroup -TemplateFile $TemplateFile -deploymentMode "Deploy" -TemplateParameterFile $TemplateParameterFile -OutVariable ClusterDeployment -ErrorAction Stop
    }
    catch {
        Write-Output "Deployment command failed. Re-run New-AzResourceGroupDeployment to retry. Error: $($_.Exception.Message)"
    }

    if ("True" -eq $env:autoUpgradeClusterResource -and $ClusterDeployment.ProvisioningState -eq "Succeeded") {

        Write-Host "Deployment succeeded. Upgrading Local cluster..."

        Update-AzDeploymentProgressTag -ProgressString 'Upgrading Azure Local cluster' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

        Update-AzLocalCluster -LocalBoxConfig $LocalBoxConfig -domainCred $domainCred

    }
    else {

        Write-Host '$autoUpgradeClusterResource is false, skipping Local cluster upgrade...follow the documentation to upgrade the cluster manually'

    }

}
else {

    Write-Error "Validation failed. Aborting deployment. Re-run New-AzResourceGroupDeployment to retry."

}

}
else {
    Write-Host '$autoDeployClusterResource is false, skipping Local cluster deployment. If desired, follow the documentation to deploy the cluster manually'
}



$endtime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "Successfully deployed LocalBox infrastructure." -ForegroundColor Green
Write-Host "Infrastructure deployment time was $($timeSpan.Hours):$($timeSpan.Minutes) (hh:mm)." -ForegroundColor Green

Stop-Transcript

#endregion
