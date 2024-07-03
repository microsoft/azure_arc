using 'main.bicep'

param sshRSAPublicKey = '<your RSA public key>'

param spnClientId = '<your service principal client id>'

param spnClientSecret = '<your service principal secret>'

param spnTenantId = '<your spn tenant id>'

param windowsAdminUsername = 'arcdemo'

param windowsAdminPassword = '<your windows admin password>'

param logAnalyticsWorkspaceName = '<your unique Log Analytics workspace name>'

param flavor = 'ITPro'

param deployBastion = false

param vmAutologon = true
