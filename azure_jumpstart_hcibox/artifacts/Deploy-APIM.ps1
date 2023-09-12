$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'
# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxGitOpsDir = "C:\HCIBox\GitOps"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"
$rg = $env:resourceGroup



if ($host.Name -match 'ISE') {throw "Running this script in PowerShell ISE is not supported"}

try {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-APIM.log
}
catch {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-APIM.log
}

# Import Configuration Module
$ConfigurationDataFile = "$Env:HCIBoxDir\HCIBox-Config.psd1"
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt


# Setting kubeconfig
$clusterName = az connectedk8s list --resource-group $Env:resourceGroup --query "[].{Name:name} | [? contains(Name,'hcibox')]" --output tsv
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl get nodes

}
# Deploy APIM and set up weather api
$apimDeploymentOutput = az deployment group create --resource-group $rg --template-file $Env:HCIBoxDir\artifacts\apim\apim.bicep --parameters $Env:HCIBoxDir\artifacts\apim\apim.bicepparam | ConvertFrom-Json
$selfhostKey = $apimDeploymentOutput.properties.outputs.gatewayKey.value
kubectl create secret generic selfhost-token --from-literal=value="GatewayKey ${selfhostKey}"  --type=Opaque
kubectl apply -f $Env:HCIBoxDir\artifacts\apim\selfhost.yaml

Stop-Transcript
