from azureml.core import Workspace

subscription_id = 'subscription_id-stage'
resource_group  = 'resource_group-stage'
workspace_name  = 'workspace_name-stage'

try:
    ws = Workspace(subscription_id = subscription_id, resource_group = resource_group, workspace_name = workspace_name)
    ws.write_config()
    print('Library configuration succeeded')
except:
    print('Workspace not found')