using 'main.bicep'

param sshRSAPublicKey = '<your RSA public key>'

param tenantId = '<your tenant id>'

param windowsAdminUsername = 'arcdemo'

param windowsAdminPassword = '<your windows admin password>'

param logAnalyticsWorkspaceName = '<your unique Log Analytics workspace name>'

param flavor = 'ITPro'

param deployBastion = false

param vmAutologon = true

param resourceTags = {} // Add tags as needed
