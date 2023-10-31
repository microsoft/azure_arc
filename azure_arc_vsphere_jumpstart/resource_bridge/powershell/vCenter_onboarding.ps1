# <--- Change the following environment variables according to your environment --->

$location = '<Azure region>'
$subscriptionId = '<Subscription Id>'
$resourceGroupName = '<Azure Resource Group Name>'
$applianceName = '<resource bridge appliance name>'
$customLocationName = '<Custom Location name>'
$vcenterName = '<vCenter name>'
$vcenterFqdn = '<vCenter FQDN>'
$vcenterUsername = '<vCenter Username>'
$vcenterPassword = '<vCenter Password>'
$spnClientId = '<Service principal appId>'
$spnClientSecret = '<Service principal password>'
$spnTenantId = '<Service principal Tenant ID>'

## vSphere parameters
$vmTemplate = '<Arc appliance template name>'
$datacenter = '<vSphere datacenter name>'
$datastore = '<vSphere datastore name>'
$folder = '<vSphere template folder>'
$dnsServer = '<DNS server to be used for the appliance>'
$gateway = '<Gateway address to be used for the appliance>'
$ipAddressPrefix = '<Network address in CIDR notation>'

## Minimum size of two available IP addresses are required. One IP address is for the VM, and the other is reserved for upgrade scenarios
$k8sNodeIpPoolStart = '<IP range start>'
$k8sNodeIpPoolEnd = '<IP range end>'
$segment = '<Name of the virtual network or segment to which the appliance VM must be connected>'
$resourcePool = '<Name of the resource pool>'
$controlPlaneEndpoint = '<IP address of the Kubernetes cluster control plane>'

$vSphereRP = 'Microsoft.VMware Resource Provider'
# <--- Change the following environment variables according to your environment --->

# Copying the config files
Copy-Item .\config\arcbridge-appliance-stage.yaml -Force -Destination .
Copy-Item .\config\arcbridge-infra-stage.yaml -Force -Destination .
Copy-Item .\config\arcbridge-resource-stage.yaml -Force -Destination .

# Generating Infra YAML file
$InfraParams = ".\arcbridge-infra-stage.yaml"
(Get-Content -Path $InfraParams) -replace 'vmTemplate-stage',$vmTemplate | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'datacenter-stage',$datacenter | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'datastore-stage',$datastore | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'folder-stage',$folder | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'dnsServer-stage',$dnsServer | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'gateway-stage',$gateway | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'ipAddressPrefix-stage',$ipAddressPrefix | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'nodeIpPoolEnd-stage',$k8sNodeIpPoolEnd | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'nodeIpPoolStart-stage',$k8sNodeIpPoolStart | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'VmNetwork-stage',$segment | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'resourcePool-stage',$resourcePool | Set-Content -Path $InfraParams

# Generating appliance YAML file
$InfraParams = ".\arcbridge-appliance-stage.yaml"
(Get-Content -Path $InfraParams) -replace 'controlPlaneEndpoint-stage',$controlPlaneEndpoint | Set-Content -Path $InfraParams

# Generating resource YAML file
$InfraParams = ".\arcbridge-resource-stage.yaml"
(Get-Content -Path $InfraParams) -replace 'location-stage',$location | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'arcbridgeName-stage',$applianceName | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'resourceGroup-stage',$resourceGroupName | Set-Content -Path $InfraParams
(Get-Content -Path $InfraParams) -replace 'subscriptionId-stage',$subscriptionId | Set-Content -Path $InfraParams

$logFile = "arcvmware-output.log"
$loginValues = @($vcenterFqdn, $vcenterUsername, $vcenterPassword)
function log($msg) {
    Write-Host $msg
    Write-Output $msg >> $logFile
}

log "Step 1/5: Setting up the current workstation"

Write-Host "Setting the TLS Protocol for the current session to TLS 1.2."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$forceApplianceRun = ""
if ($Force) { $forceApplianceRun = "--force" }

log "Creating a temporary folder in the current directory (.temp)"
New-Item -Force -Path "." -Name ".temp" -ItemType "directory" > $null

$ProgressPreference = 'SilentlyContinue'

function getLatestAzVersion() {
    # https://github.com/Azure/azure-cli/blob/4e21baa4ff126ada2bc232dff74d6027fd1323be/src/azure-cli-core/azure/cli/core/util.py#L295
    $gitUrl = "https://raw.githubusercontent.com/Azure/azure-cli/main/src/azure-cli/setup.py"
    try {
        $response = Invoke-WebRequest -Uri $gitUrl -TimeoutSec 30
    }
    catch {
        logWarn "Failed to get the latest version from '$gitUrl': $($_.Exception.Message)"
        return $null
    }
    
    if ($response.StatusCode -ne 200) {
        logWarn "Failed to fetch the latest version from '$gitUrl' with status code '$($response.StatusCode)' and reason '$($response.StatusDescription)'"
        return $null
    }

    $content = $response.Content
    foreach ($line in $content -split "`n") {
        if ($line.StartsWith('VERSION')) {
            $match = [System.Text.RegularExpressions.Regex]::Match($line, 'VERSION = "(.*)"')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    }

    logWarn "Failed to extract the latest version from the content of '$gitUrl'"
    return $null
}

function shouldInstallAzCli() {
    # This function returns a boolean value, but any undirected / uncaptured stdout
    # inside the function might be interpreted as true value by the caller.
    # We can redirect using *>> to avoid this.
    log "Validating and installing 64-bit azure-cli"
    $azCmd = (Get-Command az -ErrorAction SilentlyContinue)
    if ($null -eq $azCmd) {
        log "Azure CLI is not installed. Installing..."
        return $true
    }

    $currentAzVersion = az version --query '\"azure-cli\"' -o tsv 2>> $logFile
    log "Azure CLI version $currentAzVersion found in PATH at location: '$($azCmd.Source)'"
    $azVersion = az --version *>&1;
    $azVersionLines = $azVersion -split "`n"
    # https://github.com/microsoft/knack/blob/e0c14114aea5e4416c70a77623e403773aba73a8/knack/cli.py#L126
    $pyLoc = $azVersionLines | Where-Object { $_ -match "^Python location" }
    if ($null -eq $pyLoc) {
        logWarn "Warning: Python location could not be found from the output of az --version:`n$($azVersionLines -join "`n"))"
        return $true
    }
    log $pyLoc
    $pythonExe = $pyLoc -replace "^Python location '(.+?)'$", '$1'
    try {
        log "Determining the bitness of Python at '$pythonExe'"
        $arch = & $pythonExe -c "import struct; print(struct.calcsize('P') * 8)";
        if ($arch -lt 64) {
            log "Azure CLI is $arch-bit. Installing 64-bit version..."
            return $true
        }
    }
    catch {
        log "Warning: Python version could not be determined from the output of az --version:`n$($azVersionLines -join "`n"))"
        return $true
    }

    log "$arch-bit Azure CLI is already installed. Checking for updates..."
    $latestAzVersion = getLatestAzVersion
    if ($latestAzVersion -and ($latestAzVersion -ne $currentAzVersion)) {
        log "A newer version of Azure CLI ($latestAzVersion) is available, installing it..."
        return $true
    }

    log "Azure CLI is up to date."
    return $false
}


function installAzCli64Bit() {
    $azCliMsi = "https://aka.ms/installazurecliwindowsx64"
    $azCliMsiPath = "AzureCLI.msi"
    Invoke-WebRequest -Uri $azCliMsi -OutFile $azCliMsiPath
    log "Installing 64 bit Azure CLI"
    log "This might take a while..."
    $p = Start-Process msiexec.exe -Wait -Passthru -ArgumentList "/i `"$azCliMsiPath`" /quiet /qn /norestart"
    $exitCode = $p.ExitCode
    if ($exitCode -ne 0) {
        throw "Azure CLI installation failed with exit code $exitCode. See $msiInstallLogPath for additional details."
    }
    
    $azCmdDir = Join-Path $env:ProgramFiles "Microsoft SDKs\Azure\CLI2\wbin"
    [System.Environment]::SetEnvironmentVariable('PATH', $azCmdDir + ';' + $Env:PATH)
    log "Azure CLI has been installed."
}

if (shouldInstallAzCli) {
    installAzCli64Bit
}

$ProgressPreference = 'Continue'


log "Checking previous installations of Azure CLI"

$AzureCLI = Get-WmiObject -Class Win32_Product  | Where-Object{$_.Name -eq "Microsoft Azure CLI"}

If([string]::IsNullOrWhiteSpace($AzureCLI)) {            
    log "No previous Azure CLI installation was found"
} else {
    log "Removing Azure CLI current install"
    $AzureCLI.uninstall()
}


log "Installing 64 bit Azure CLI"
log "This might take a while..."



try {

    az provider register -n Microsoft.ResourceConnector --wait
    az provider register -n Microsoft.ConnectedVMwarevSphere --wait

    log "Installing az cli extensions for Arc"
    az extension add --name arcappliance
    az extension add --name k8s-extension
    az extension add --name customlocation
    az extension add --name connectedvmware

    log "Logging into azure"

    az login --service-principal -u $spnClientId -p $spnClientSecret --tenant $spnTenantId

    az account set -s $subscriptionId
    if ($LASTEXITCODE) {
        $Error[0] | Out-String >> $logFile
        throw "The default subscription for the az cli context could not be set."
    }

    log "Step 1/5: Workstation was set up successfully"


    log "Step 2/5: Creating the Arc resource bridge"
    log "Provide vCenter details to deploy Arc resource bridge VM. The credentials will be used by Arc resource bridge to update and scale itself."
    $user_in = ""
    foreach ($val in $loginValues) { $user_in = $user_in + "`n" + $val }
    $login_password = $loginValues[2]

    log "Validating"
    $user_in | az arcappliance validate vmware --config-file .\arcbridge-appliance-stage.yaml 2>> $logFile
    log "Preparing"
    $user_in | az arcappliance prepare vmware --config-file .\arcbridge-appliance-stage.yaml 2>> $logFile
    log "Deploying"
    $user_in | az arcappliance deploy vmware --config-file .\arcbridge-appliance-stage.yaml 2>> $logFile
    sleep -Seconds 20
    log "Creating"
    $user_in | az arcappliance create vmware --config-file .\arcbridge-appliance-stage.yaml --kubeconfig .\kubeconfig 2>> $logFile

    log "Adding Cluster extension"

    $applianceId = (az arcappliance show --subscription $subscriptionId --resource-group $resourceGroupName --name $applianceName --query id -o tsv 2>> $logFile)
    if (!$applianceId) {
        throw "Appliance creation has failed."
    }

    # Waiting for the resource bridge to be in a running state
    Do {
        Write-Host "Waiting for the resource bridge to be in a running state, hold tight... (45 seconds loop)"
        Start-Sleep -Seconds 45
        $applianceStatus = (az resource show --debug --ids "$applianceId" --query 'properties.status' -o tsv 2>> $logFile)
        $status = $(if($applianceStatus -eq 'Running'){"Ready!"}Else{"Nope"})
        } while ($status -eq "Nope")

    log "Step 2/5: Arc resource bridge is up and running"
    log "Step 3/5: Installing cluster extension"


    $VMW_RP_OBJECT_ID = $vSphereRP
    if (!$VMW_RP_OBJECT_ID) {
        $msg = "The service principal ID was not found for the resource provider Microsoft.ConnectedVMwarevSphere for the subscription '$subscriptionId'.`n" +
        "Please register the RP with the subscription using the following command and try again after some time.`n`n" +
        "`taz provider register --wait --namespace Microsoft.ConnectedVMwarevSphere --subscription '$subscriptionId'`n"
        throw $msg
    }

    az k8s-extension create --debug --subscription $subscriptionId --resource-group $resourceGroupName --name azure-vmwareoperator --extension-type 'Microsoft.vmware' --scope cluster --cluster-type appliances --cluster-name $applianceName --config Microsoft.CustomLocation.ServiceAccount=azure-vmwareoperator --config global.rpObjectId="$VMW_RP_OBJECT_ID" 2>> $logFile

    $clusterExtensionId = (az k8s-extension show --subscription $subscriptionId --resource-group $resourceGroupName --name azure-vmwareoperator --cluster-type appliances --cluster-name $applianceName --query id -o tsv 2>> $logFile)
    if (!$clusterExtensionId) {
        throw "Cluster extension installation failed."
    }
    $clusterExtensionState = (az resource show --debug --ids "$clusterExtensionId" --query 'properties.provisioningState' -o tsv 2>> $logFile)
    if ($clusterExtensionState -ne "Succeeded") {
        throw "Provisioning State of cluster extension is not succeeded. Current state: $clusterExtensionState."
    }

    log "Step 3/5: Cluster extension installed successfully"
    log "Step 4/5: Creating custom location"

    $customLocationNamespace = ("$customLocationName".ToLower() -replace '[^a-z0-9-]', '')
    az customlocation create --debug --tags Project=jumpstart_azure_arc_vsphere --subscription $subscriptionId --resource-group $resourceGroupName --name $customLocationName --location $location --namespace $customLocationNamespace --host-resource-id $applianceId --cluster-extension-ids $clusterExtensionId 2>> $logFile

    $customLocationId = (az customlocation show --subscription $subscriptionId --resource-group $resourceGroupName --name $customLocationName --query id -o tsv 2>> $logFile)
    if (!$customLocationId) {
        throw "Custom location creation failed."
    }
    $customLocationState = (az resource show --debug --ids $customLocationId --query 'properties.provisioningState' -o tsv 2>> $logFile)
    if ($customLocationState -ne "Succeeded") {
        throw "Provisioning State of custom location is not succeeded. Current state: $customLocationState."
    }

    log "Step 4/5: Custom location created successfully"
    log "Step 5/5: Connecting to vCenter"

    log "Provide vCenter details"
    log "`t* These credentials will be used when you perform vCenter operations through Azure."
    log "`t* You can provide the same credentials that you provided for Arc resource bridge earlier."

    az connectedvmware vcenter connect --debug --tags Project=jumpstart_azure_arc_vsphere --subscription $subscriptionId --resource-group $resourceGroupName --name $vcenterName --fqdn $vcenterFqdn --username $vcenterUsername --password $vcenterPassword --custom-location $customLocationId --location $location --port 443 2>> $logFile

    $vcenterId = (az connectedvmware vcenter show --subscription $subscriptionId --resource-group $resourceGroupName --name $vcenterName --query id -o tsv 2>> $logFile)
    if (!$vcenterId) {
        throw "Connect vCenter failed."
    }
    $vcenterState = (az resource show --debug --ids "$vcenterId" --query 'properties.provisioningState' -o tsv 2>> $logFile)
    if ($vcenterState -ne "Succeeded") {
        throw "Provisioning State of vCenter is not succeeded. Current state: $vcenterState."
    }

    log "Step 5/5: vCenter was connected successfully"
    log "Your vCenter has been successfully onboarded to Azure Arc!"
}
catch {
    $err = $_.Exception | Out-String
    log ("Script execution failed: " + $err)
}