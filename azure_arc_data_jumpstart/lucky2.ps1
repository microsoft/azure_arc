$azurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($appId , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal 

Import-AzAksCredential -ResourceGroupName $resourceGroup -Name $arcClusterName

