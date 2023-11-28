from azureml.core import Dataset
from azureml.opendatasets import MNIST
from azureml.core import Workspace
import os
from azureml.core.authentication import ServicePrincipalAuthentication 
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

svc_pr = ServicePrincipalAuthentication(
                        tenant_id = tenant_id,
                        service_principal_id = service_principal_id,
                        service_principal_password =     service_principal_password)


ws = Workspace(subscription_id = subscription_id, resource_group = resource_group, workspace_name = workspace_name, auth=svc_pr)

data_folder = "C:\Temp\data"
os.makedirs(data_folder, exist_ok=True)

mnist_file_dataset = MNIST.get_file_dataset()
mnist_file_dataset.download(data_folder, overwrite=True)

mnist_file_dataset = mnist_file_dataset.register(workspace=ws,
                                                 name='mnist_opendataset',
                                                 description='training and test dataset',
                                                 create_new_version=True)