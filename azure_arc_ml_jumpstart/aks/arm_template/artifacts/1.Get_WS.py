import os 
from azureml.core.authentication import ServicePrincipalAuthentication 
from azureml.core import Workspace
import argparse

# Create the parser
parser = argparse.ArgumentParser()

# Add the arguments
parser.add_argument("--mlworkspace", "-w", type=str, help="ML workspace name")

# Parse the arguments
args = parser.parse_args()

tenant_id = os.environ.get('spnTenantId')
service_principal_id = os.environ.get('spnClientId')
service_principal_password = os.environ.get('spnClientSecret')
subscription_id = os.environ.get('subscriptionId')
resource_group  = os.environ.get('resourceGroup')
workspace_name  = args.mlworkspace

print(f'subscription_id = {subscription_id}, resource_group = {resource_group}, workspace_name = {workspace_name}')

svc_pr = ServicePrincipalAuthentication(
    tenant_id = tenant_id,
    service_principal_id = service_principal_id,
    service_principal_password =     service_principal_password)

try:
    print('Get workspace details to configure library')
    ws = Workspace(subscription_id = subscription_id, resource_group = resource_group, workspace_name = workspace_name, auth=svc_pr)
    print(ws.get_details())
    ws.write_config()

    print('Verifying workspace details in config')
    ws = Workspace.from_config()
    print(ws.get_details())
    print('Library configuration succeeded')
except:
    print('Workspace not found')
