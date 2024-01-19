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

# Import Configuration Module and create Azure login credentials
Write-Header 'Importing config'
$ConfigurationDataFile = 'C:\HCIBox\HCIBox-Config.psd1'
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Generate credential objects
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $HCIBoxConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password # Domain credential
$clusterName = $env:AKSClusterName
Copy-VMFile -Name $HCIBoxConfig.HostList[0] -SourcePath $env:HCIBoxDir\jumpstart-user-secret.yaml -DestinationPath C:\AksHci\jumpstart-user-secret.yaml -FileSource Host -Force
$TOKEN = Invoke-Command -VMName $HCIBoxConfig.HostList[0] -Credential $adcred -ScriptBlock {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl create serviceaccount jumpstart-user
    kubectl create clusterrolebinding jumpstart-user-binding --clusterrole cluster-admin --serviceaccount default:jumpstart-user
    kubectl apply -f C:\AksHci\jumpstart-user-secret.yaml
    $TOKEN = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret jumpstart-user-secret -o jsonpath='{$.data.token}'))))
    return $TOKEN
}

Write-Output "The service account bearer token below can be used to view Kubernetes resources inside the Azure portal. Copy the code starting after the dashed line (do not include the dashed line)."
Write-Output "----------------------------------"
Write-Output $TOKEN