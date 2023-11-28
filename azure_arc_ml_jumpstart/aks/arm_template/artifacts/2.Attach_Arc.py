from azureml.core.compute import KubernetesCompute
from azureml.core.compute import ComputeTarget
from azureml.core import Workspace
import os
import argparse

# Create the parser
parser = argparse.ArgumentParser()

# Add the arguments
parser.add_argument("--connectedclusterid", "-c", type=str, help="Azure Arc connected cluster resource ID")

# Parse the arguments
args = parser.parse_args()

ws = Workspace.from_config()
print(f'Workspace name: {ws.name}')

# choose a name for your Azure Arc-enabled Kubernetes compute
amlarc_compute_name = os.environ.get("AML_COMPUTE_CLUSTER_NAME", "Arc-AML-AKS")
print(f'AML_COMPUTE_CLUSTER_NAME: {amlarc_compute_name}')

# resource ID for your Azure Arc-enabled Kubernetes cluster
resource_id = args.connectedclusterid
print(f'connectedClusterId: {resource_id}')

if amlarc_compute_name in ws.compute_targets:
    amlarc_compute = ws.compute_targets[amlarc_compute_name]
    if amlarc_compute and type(amlarc_compute) is KubernetesCompute:
        print(f'found compute target: {amlarc_compute_name}')
else:
    print("creating new compute target...")

    amlarc_attach_configuration = KubernetesCompute.attach_configuration(resource_id) 
    amlarc_compute = ComputeTarget.attach(ws, amlarc_compute_name, amlarc_attach_configuration)

 
    amlarc_compute.wait_for_completion(show_output=True)
    
     # For a more detailed view of current KubernetesCompute status, use get_status()
    print(amlarc_compute.get_status().serialize())
