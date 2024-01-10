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

$ingressNamespace = "ingress-nginx"

$certname = "ingress-cert"
$certdns = "hcibox.devops.com"

$appClonedRepo = "https://github.com/microsoft/azure-arc-jumpstart-apps"

if ($host.Name -match 'ISE') {throw "Running this script in PowerShell ISE is not supported"}

try {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-GitOps.log
}
catch {
    Start-Transcript -Path $Env:HCIBoxLogsDir\Deploy-GitOps.log
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
az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId
az config set extension.use_dynamic_install=yes_without_prompt

# Required for azcopy
$azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

# Setting kubeconfig
$clusterName = az connectedk8s list --resource-group $Env:resourceGroup --query "[].{Name:name} | [? contains(Name,'hcibox')]" --output tsv
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    Get-AksHciCredential -name $using:clusterName -Confirm:$false
    kubectl get nodes
    foreach ($namespace in @('hello-arc')) {
        kubectl create namespace $namespace
    }
}

# Create random 13 character string for Key Vault name
$strLen = 13
$randStr = (-join ((0x30..0x39) + (0x61..0x7A) | Get-Random -Count $strLen | ForEach-Object {[char]$_}))
$keyVaultName = "HCIBox-KV-$randStr"

[System.Environment]::SetEnvironmentVariable('keyVaultName', $keyVaultName, [System.EnvironmentVariableTarget]::Machine)

# Create Azure Key Vault
Write-Header "Creating Azure KeyVault"
az keyvault create --name $keyVaultName --resource-group $Env:resourceGroup --location $Env:azureLocation

# Allow SPN to import certificates into Key Vault
Write-Header "Setting KeyVault Access Policies"
az keyvault set-policy --name $keyVaultName --spn $Env:spnClientID --key-permissions --secret-permissions get --certificate-permissions get list import

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

#############################
# - Apply GitOps Configs
#############################

Write-Header "Applying GitOps Configs"

# Create GitOps config for NGINX Ingress Controller
Write-Host "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create `
    --cluster-name $clusterName `
    --resource-group $Env:resourceGroup `
    --name config-nginx `
    --namespace $ingressNamespace `
    --cluster-type connectedClusters `
    --scope cluster `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=nginx path=./nginx/release

# Create GitOps config for Hello-Arc application
Write-Host "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create `
    --cluster-name $clusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc `
    --namespace hello-arc `
    --cluster-type connectedClusters `
    --scope namespace `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=helloarc path=./hello-arc/yaml

################################################
# - Install Key Vault Extension / Create Ingress
################################################

Write-Header "Installing KeyVault Extension"

Write-Host "Generating a TLS Certificate"
$cert = New-SelfSignedCertificate -DnsName $certdns -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddYears(1) -CertStoreLocation "Cert:\CurrentUser\My"
$certPassword = ConvertTo-SecureString -String "arcbox" -Force -AsPlainText
Export-PfxCertificate -Cert "cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath "$Env:TempDir\$certname.pfx" -Password $certPassword
Copy-VMFile AzSMGMT -SourcePath "$Env:TempDir\$certname.pfx" -DestinationPath "C:\VMConfigs\$certname.pfx" -FileSource Host
$localCred = new-object -typename System.Management.Automation.PSCredential -argumentlist "Administrator", (ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)
Invoke-Command -VMName AzSMGMT -Credential $localcred -ScriptBlock {
    Enable-VMIntegrationService -VMName AdminCenter -Name "Guest Service Interface"
}
Start-Sleep 20
Invoke-Command -VMName AzSMGMT -Credential $localcred -ScriptBlock {
    Copy-VMFile AdminCenter -SourcePath "C:\VMConfigs\$using:certname.pfx" -DestinationPath "C:\VHDs\$using:certname.pfx" -FileSource Host
}
Invoke-Command -ComputerName AdminCenter -Credential $adcred -ScriptBlock {
    Import-PfxCertificate -FilePath "C:\VHDs\$using:certname.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Password $using:certPassword
}

Write-Host "Importing the TLS certificate to Key Vault"
az keyvault certificate import `
    --vault-name $keyVaultName `
    --password "arcbox" `
    --name $certname `
    --file "$Env:TempDir\$certname.pfx"

Write-Host "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name 'akvsecretsprovider' `
    --extension-type Microsoft.AzureKeyVaultSecretsProvider `
    --scope cluster `
    --cluster-name $clusterName `
    --resource-group $Env:resourceGroup `
    --cluster-type connectedClusters `
    --release-namespace kube-system `
    --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Replace Variable values
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/devops_ingress/hello-arc.yaml") -OutFile $Env:HCIBoxKVDir\hello-arc.yaml
Get-ChildItem -Path $Env:HCIBoxKVDir |
    ForEach-Object {
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_CERTNAME}', $certname | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_KEYVAULTNAME}', $keyVaultName | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_HOST}', $certdns | Set-Content -Path $_.FullName
        (Get-Content -path $_.FullName -Raw) -Replace '\{JS_TENANTID}', $Env:spnTenantId | Set-Content -Path $_.FullName
    }

Write-Header "Creating Ingress Controller"

# Deploy Ingress resources for Bookstore and Hello-Arc App
Copy-VMFile $SDNConfig.HostList[0] -SourcePath "$Env:HCIBoxKVDir\hello-arc.yaml" -DestinationPath "C:\VHD\hello-arc.yaml" -FileSource Host
$clientId = $env:spnClientID
$clientSecret = $env:spnClientSecret
Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    foreach ($namespace in @('hello-arc')) {
        # Create the Kubernetes secret with the service principal credentials
        kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=$using:clientId --from-literal clientsecret=$using:clientSecret
        kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

        # Deploy Key Vault resources and Ingress for Book Store and Hello-Arc App
        kubectl --namespace $namespace apply -f "C:\VHD\hello-arc.yaml"
    }
}
[string]$ip = Invoke-Command -VMName $SDNConfig.HostList[0] -Credential $adcred -ScriptBlock  {
    $ip = kubectl get service/ingress-nginx-controller --namespace $using:ingressNamespace --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'
    return $ip
}
# Insert into HOSTS file
Invoke-Command -ComputerName AdminCenter -Credential $adcred -ScriptBlock {
    Add-Content -Path $Env:windir\System32\drivers\etc\hosts -Value "`n`t$using:ip`t$using:certdns" -Force
}

Write-Header "Creating Desktop Icons"

# # Creating CAPI Hello Arc Icon on Desktop
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/icons/arc.ico") -OutFile $Env:HCIBoxIconDir\arc.ico
Copy-VMFile AzSMGMT -SourcePath "$Env:HCIBoxIconDir\arc.ico" -DestinationPath "C:\VMConfigs\arc.ico" -FileSource Host
Invoke-Command -VMName AzSMGMT -Credential $localcred -ScriptBlock {
    Copy-VMFile AdminCenter -SourcePath "C:\VMConfigs\arc.ico" -DestinationPath "C:\VHDs\arc.ico" -FileSource Host
}

Invoke-Command -ComputerName AdminCenter -Credential $adcred -ScriptBlock {
    $shortcutLocation = "$Env:Public\Desktop\Hello-Arc.lnk"
    $wScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
    $shortcut.TargetPath = "https://$using:certdns"
    $shortcut.IconLocation="C:\VHDs\arc.ico, 0"
    $shortcut.WindowStyle = 3
    $shortcut.Save()
}

Stop-Transcript
