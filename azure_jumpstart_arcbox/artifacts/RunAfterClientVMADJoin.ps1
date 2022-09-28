
##############################################
# This script will be executed after Client VM AD join setup scheduled task to run under domain account.
##############################################
Import-Module ActiveDirectory

$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxDir = "C:\ArcBox"
Start-Transcript -Path "$Env:ArcBoxLogsDir\RunAfterClientVMADJoin.log"

# Get Activectory Information
$netbiosname = $Env:addsDomainName.Split('.')[0].ToUpper()

$adminuser = "$netbiosname\$Env:adminUsername"
$secpass = $Env:adminPassword | ConvertTo-SecureString -AsPlainText -Force
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser, $secpass
#$dcName = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName

$dcInfo = Get-ADDomainController -Credential $adminCredential

# Print domain information
Write-Host "===========Domain Controller Information============"
$dcInfo
Write-Host "===================================================="

# Create login session with domain credentials
$cimsession = New-CimSession -Credential $adminCredential

# Creating scheduled task for DataServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $adminuser
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Env:ArcBoxDir\DataOpsLogonScript.ps1"
$WorkbookAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1"

# Register schedule task under local account
Register-ScheduledTask -TaskName "DataOpsLogonScript" -Trigger $Trigger -Action $Action -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'DataOpsLogonScript' to run at user logon."

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -Action $WorkbookAction -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'MonitorWorkbookLogonScript' to run at user logon."

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterClientVMADJoin

# Onboarding AKS clusters to Azure Arc
# Required for CLI commands
Write-Header "Az CLI Login"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Register Azure providers
Write-Header "Registering Providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait

# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt

# Getting AKS clusters' credentials
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksArcClusterName --admin --file "$Env:ArcBoxDir\config"
az aks get-credentials --resource-group $Env:resourceGroup --name $Env:aksdrArcClusterName --admin --file "$Env:ArcBoxDir\config"

$clusters = $(az aks list --resource-group $Env:resourceGroup --query [].name --output tsv)
foreach ($cluster in $clusters){
    $context = "$cluster-admin"
    az connectedk8s connect --name $cluster `
                --resource-group $Env:resourceGroup `
                --location $Env:azureLocation `
                --correlation-id "6038cc5b-b814-4d20-bcaa-0f60392416d5" `
                --kube-context $context `
                --kube-config "$Env:ArcBoxDir\config"

            Start-Sleep -Seconds 10

            # Enabling Container Insights cluster extension on primary AKS cluster
            Write-Host "`n"
            Write-Host "Enabling Container Insights cluster extension"
            az k8s-extension create --name "azuremonitor-containers" --cluster-name $cluster --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceId
            Write-Host "`n"
}

Remove-Item "$Env:ArcBoxDir\config" -Force

Stop-Transcript