from azureml.core import Workspace

subscription_id = '182c901a-129a-4f5d-86e4-cc6b294590a2'
resource_group  = 'raki-arc-aks-inf-rg'
workspace_name  = 'raki-arc-aks-inf-rg-ws'

try:
    ws = Workspace(subscription_id = subscription_id, resource_group = resource_group, workspace_name = workspace_name)
    ws.write_config()
    print('Library configuration succeeded')
except:
    print('Workspace not found')