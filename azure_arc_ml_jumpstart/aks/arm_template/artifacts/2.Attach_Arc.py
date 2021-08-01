from azureml.core.compute import KubernetesCompute
from azureml.core.compute import ComputeTarget
from azureml.core import Workspace
import os

ws = Workspace.from_config()

# choose a name for your Azure Arc-enabled Kubernetes compute
amlarc_compute_name = os.environ.get("AML_COMPUTE_CLUSTER_NAME", "arc")

# resource ID for your Azure Arc-enabled Kubernetes cluster
resource_id = "/subscriptions/182c901a-129a-4f5d-86e4-cc6b294590a2/resourceGroups/raki-arc-aks-inf-rg/providers/Microsoft.Kubernetes/connectedClusters/Arc-Data-AKS"

if amlarc_compute_name in ws.compute_targets:
    amlarc_compute = ws.compute_targets[amlarc_compute_name]
    if amlarc_compute and type(amlarc_compute) is KubernetesCompute:
        print("found compute target: " + amlarc_compute_name)
else:
    print("creating new compute target...")

    amlarc_attach_configuration = KubernetesCompute.attach_configuration(resource_id) 
    amlarc_compute = ComputeTarget.attach(ws, amlarc_compute_name, amlarc_attach_configuration)

 
    amlarc_compute.wait_for_completion(show_output=True)
    
     # For a more detailed view of current KubernetesCompute status, use get_status()
    print(amlarc_compute.get_status().serialize())