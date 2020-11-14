$azurePassword = ConvertTo-SecureString $env:servicePrincipalSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:servicePrincipalAppId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:servicePrincipalTenantId -ServicePrincipal
# az login --service-principal --username $env:servicePrincipalAppId --password $env:servicePrincipalSecret --tenant $env:servicePrincipalTenantId

# Set Log Analytics Workspace Environment Variables
$WorkspaceName = "log-analytics-" + (Get-Random -Maximum 99999)

# Get the Resource Group
Get-AzResourceGroup -Name $env:resourceGroup -ErrorAction Stop -Verbose

# Create the workspace
New-AzOperationalInsightsWorkspace -Location $env:location -Name $WorkspaceName -Sku Standard -ResourceGroupName $env:resourceGroup -Verbose

Write-Host "Enabling Log Analytics Solutions"
$Solutions = "Security", "Updates", "SQLAssessment"
foreach ($solution in $Solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $env:resourceGroup -WorkspaceName $WorkspaceName -IntelligencePackName $solution -Enabled $true -Verbose
}

# Get the workspace ID and Key
$workspaceId = $(az resource show --resource-group $env:resourceGroup --name $WorkspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $env:resourceGroup --workspace-name $WorkspaceName --query primarySharedKey -o tsv)

# Deploy MMA Azure Extension ARM Template
New-AzResourceGroupDeployment -Name MMA `
  -ResourceGroupName $env:resourceGroup `
  -arcServerName $env:computername `
  -location $env:location `
  -workspaceId $workspaceId `
  -workspaceKey $workspaceKey `
  -TemplateFile C:\tmp\mma.json

Write-Host "Configuring SQL Azure Assessment"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_sqlsrv_jumpstart/azure/arm_template/scripts/Microsoft.PowerShell.Oms.Assessments.zip" -OutFile "C:\tmp\Microsoft.PowerShell.Oms.Assessments.zip"
Expand-Archive "C:\tmp\Microsoft.PowerShell.Oms.Assessments.zip" -DestinationPath 'C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell'
$env:PSModulePath = $env:PSModulePath + ";C:\Program Files\'Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\"
Import-Module $env:ProgramFiles\'Microsoft Monitoring Agent\Agent\PowerShell\Microsoft.PowerShell.Oms.Assessments\Microsoft.PowerShell.Oms.Assessments.dll'
$SecureString = ConvertTo-SecureString '${admin_password}' -AsPlainText -Force
Add-SQLAssessmentTask -SQLServerName $env:computername -WorkingDirectory "C:\sql_assessment\work_dir" -RunWithManagedServiceAccount $False -ScheduledTaskUsername $env:USERNAME -ScheduledTaskPassword $SecureString
