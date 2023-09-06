@description('Workspace Resource ID.')
param WorkspaceResourceId string

@description('Workspace Location.')
param WorkspaceLocation string

@description('This is the name of the AMA-VMI Data Collection Rule(DCR)')
@metadata({ displayName: 'Name of the Data Collection Rule(DCR)' })
param userGivenDcrName string = 'ama-vmi-default-perfAndda-dcr'

module VMI_DCR_Deployment_userGivenDcr './nested_VMI_DCR_Deployment_userGivenDcr.bicep' = {
  name: 'VMI-DCR-Deployment-${uniqueString(userGivenDcrName)}'
  scope: resourceGroup(split(WorkspaceResourceId, '/')[2], split(WorkspaceResourceId, '/')[4])
  params: {
    userGivenDcrName: userGivenDcrName
    WorkspaceLocation: WorkspaceLocation
    WorkspaceResourceId: WorkspaceResourceId
  }
}
