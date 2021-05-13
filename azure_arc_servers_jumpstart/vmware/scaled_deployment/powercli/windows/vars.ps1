
# <--- Change the following environment variables according to your Azure service principal name --->

# Azure vars
$env:subscription_id = 'Your Azure subscription ID'
$env:servicePrincipalClientId = 'Your Azure service principal name'
$env:servicePrincipalSecret = 'Your Azure service principal password'
$env:tenant_id = 'Your Azure tenant ID'
$env:resourceGroup = 'Azure resource group name where the Azure Arc servers will be onboarded to'
$env:location = 'Azure Region' # For example: "eastus"

# VMware vSphere vars
$env:vCenterAddress = 'vCenter FQDN/IP'
$env:vCenterUser = 'vCenter user account' # For example: admin@myvsphere.local
$env:vCenterUserPassword = 'vCenter user account Password'
$env:SrcPath = 'Folder location of the downloaded scripts' # For example: C:\Users\Lior\git\azure_arc\azure_arc_servers_jumpstart\vmware\scale_deploy_winsrv\powercli\
$env:VMFolder = 'The vCenter folder where the VMs are located'
$env:OSAdmin = 'Windows Administrator user account for the VM'
$env:OSAdminPassword = 'Windows Administrator user account for the VM'
