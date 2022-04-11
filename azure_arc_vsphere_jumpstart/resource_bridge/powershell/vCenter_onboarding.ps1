# <--- Change the following environment variables according to your environment --->

$location = '<Azure region>'
$SubscriptionId = '<Subscription ID>'
$ResourceGroupName = '<Azure Resource Group Name>'
$applianceName = '<bridge appliance name>'
$customLocationName = '<Custom Location name>'
$vCenterName = '<vCenter name>'
$vcenterfqdn = '<vCenter FQDN>'
$vcenterusername = '<vCenter Username>'
$vcenterpassword = '<vCenter Password>'
$appID = '<Service principal AppID>'
$password = '<Service principal password>'
$tenantId = '<Tenant ID>'

$logFile = "arcvmware-output.log"
$loginValues = @($vcenterfqdn, $vcenterusername, $vcenterpassword)
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

log "Validating and installing 64-bit python"
try {
    $bitSize = py -c "import struct; print(struct.calcsize('P') * 8)"
    if ($bitSize -ne "64") {
        throw "Python is not 64-bit"
    }
    log "64-bit python is already installed"
}
catch {
    log "Installing python..."
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.8.8/python-3.8.8-amd64.exe" -OutFile ".temp/python-3.8.8-amd64.exe"
    $p = Start-Process .\.temp\python-3.8.8-amd64.exe -Wait -PassThru -ArgumentList '/quiet InstallAllUsers=0 PrependPath=1 Include_test=0'
    $exitCode = $p.ExitCode
    if ($exitCode -ne 0) {
        throw "Python installation failed with exit code $LASTEXITCODE"
    }
}
$ProgressPreference = 'Continue'

log "Enabling long path support for python..."
Start-Process powershell.exe -verb runas -ArgumentList "Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1" -Wait

py -m venv .temp\.env


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

.temp\.env\Scripts\python.exe -m pip install --upgrade pip wheel setuptools >> $logFile
.temp\.env\Scripts\pip install azure-cli >> $logFile

.temp\.env\Scripts\Activate.ps1


try {

    az provider register -n Microsoft.ResourceConnector --wait

    log "Installing az cli extensions for Arc"
    az extension add --upgrade --name arcappliance
    az extension add --upgrade --name k8s-extension
    az extension add --upgrade --name customlocation
    az extension add --upgrade --name connectedvmware

    log "Logging into azure"

    az login --service-principal -u $appID -p $password --tenant $tenantId

    az account set -s $SubscriptionId
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
    $user_in | az arcappliance validate vmware --config-file .\arcbridge001-appliance.yaml 2>> $logFile
    log "Preparing"
    $user_in | az arcappliance prepare vmware --config-file .\arcbridge001-appliance.yaml 2>> $logFile
    log "Deploying"
    $user_in | az arcappliance deploy vmware --config-file .\arcbridge001-appliance.yaml 2>> $logFile
    sleep -Seconds 20
    log "Creating"
    $user_in | az arcappliance create vmware --config-file .\arcbridge001-appliance.yaml --kubeconfig .\kubeconfig 2>> $logFile

    log "Adding Cluster extension"

    $applianceId = (az arcappliance show --subscription $SubscriptionId --resource-group $ResourceGroupName --name $applianceName --query id -o tsv 2>> $logFile)
    if (!$applianceId) {
        throw "Appliance creation has failed."
    }

    # Waiting for the resource bridge to be in a running state
    Do {
        Write-Host "Waiting for the resource bridge to be in a running state, hold tight..."
        Start-Sleep -Seconds 20
        $applianceStatus = (az resource show --debug --ids "$applianceId" --query 'properties.status' -o tsv 2>> $logFile)
        $status = $(if($applianceStatus -eq 'Running'){"Ready!"}Else{"Nope"})
        } while ($status -eq "Nope")

    log "Step 2/5: Arc resource bridge is up and running"
    log "Step 3/5: Installing cluster extension"


    $VMW_RP_OBJECT_ID = (az ad sp show --id 'ac9dc5fe-b644-4832-9d03-d9f1ab70c5f7' --query objectId -o tsv)
    if (!$VMW_RP_OBJECT_ID) {
        $msg = "The service principal ID was not found for the resource provider Microsoft.ConnectedVMwarevSphere for the subscription '$SubscriptionId'.`n" +
        "Please register the RP with the subscription using the following command and try again after some time.`n`n" +
        "`taz provider register --wait --namespace Microsoft.ConnectedVMwarevSphere --subscription '$SubscriptionId'`n"
        throw $msg
    }

    az k8s-extension create --debug --subscription $SubscriptionId --resource-group $ResourceGroupName --name azure-vmwareoperator --extension-type 'Microsoft.vmware' --scope cluster --cluster-type appliances --cluster-name $applianceName --config Microsoft.CustomLocation.ServiceAccount=azure-vmwareoperator --config global.rpObjectId="$VMW_RP_OBJECT_ID" 2>> $logFile

    $clusterExtensionId = (az k8s-extension show --subscription $SubscriptionId --resource-group $ResourceGroupName --name azure-vmwareoperator --cluster-type appliances --cluster-name $applianceName --query id -o tsv 2>> $logFile)
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
    az customlocation create --debug --tags Project=jumpstart_azure_arc_vsphere --subscription $SubscriptionId --resource-group $ResourceGroupName --name $customLocationName --location $location --namespace $customLocationNamespace --host-resource-id $applianceId --cluster-extension-ids $clusterExtensionId 2>> $logFile

    $customLocationId = (az customlocation show --subscription $SubscriptionId --resource-group $ResourceGroupName --name $customLocationName --query id -o tsv 2>> $logFile)
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

    az connectedvmware vcenter connect --debug --tags Project=jumpstart_azure_arc_vsphere --subscription $SubscriptionId --resource-group $ResourceGroupName --name $vCenterName --fqdn $vcenterfqdn --username $vcenterusername --password $vcenterpassword --custom-location $customLocationId --location $location --port 443

    $vcenterId = (az connectedvmware vcenter show --subscription $SubscriptionId --resource-group $ResourceGroupName --name $vCenterName --query id -o tsv 2>> $logFile)
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
finally {
    deactivate
}
