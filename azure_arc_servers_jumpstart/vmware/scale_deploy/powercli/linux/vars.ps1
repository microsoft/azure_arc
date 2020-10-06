
# <--- Change the following environment variables according to your VMware vSphere environment --->

# VMware vSphere vars
$env:vCenterAddress = 'vCenter FQDN/IP'
$env:vCenterUser = 'vCenter user account' # For example: admin@myvsphere.local
$env:vCenterUserPassword = 'vCenter user account Password'
$env:VMFolder = 'The vCenter folder where the VMs are located'

# OS vars
$env:OSAdmin = 'Linux Administrator user account for the VM'
$env:OSAdminPassword = 'Linux Administrator user account for the VM'

# File vars
$env:SrcPath = 'Folder location of the downloaded scripts' # For example: C:\Users\Lior\git\azure_arc\azure_arc_servers_jumpstart\vmware\scale_deploy\powercli\linux\

# Azure vars
Set-Content -Path .\vars.sh -Value{
#!/bin/sh
# Azure vars
export subscription_id='Your Azure Subscription ID'
export client_id='Your Azure Service Principal name'
export client_secret='Your Azure Service Principal password'
export tenant_id='Your Azure tenant ID'
export resourceGroup='Azure Resource Group Name where the Azure Arc servers will be onboarded to'
export location='Azure Region' # For example: "eastus"
}
