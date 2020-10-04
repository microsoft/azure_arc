
# <--- Change the following environment variables according to your Azure Service Principle name --->

# Azure vars
$env:subscription_id = 'Your Azure Subscription ID'
$env:client_id = 'Your Azure Service Principle name'
$env:client_secret = 'Your Azure Service Principle password'
$env:tenant_id = 'Your Azure tenant ID'
$env:resourceGroup = 'Azure Resource Group Name where the Azure Arc servers will be onboarded to'
$env:location = 'Azure Region' # For example: "eastus"

# VMware vSphere vars
$env:vCenterAddress = 'vCenter FQDN/IP'
$env:vCenterUser = 'vCenter user account' # For example: admin@myvsphere.local
$env:vCenterUserPassword = 'vCenter user account Password'
$env:SrcPath = 'Folder location of the downloaded scripts' # For example: C:\Users\Lior\git\azure_arc\azure_arc_servers_jumpstart\vmware\scale_deploy_winsrv\powercli\
$env:VMFolder = 'The vCenter folder where the VMs are located'
$env:OSAdmin = 'Windows Administrator user account for the VM'
$env:OSAdminPassword = 'Windows Administrator user account for the VM'
