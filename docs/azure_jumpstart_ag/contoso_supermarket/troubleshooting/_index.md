---
type: docs
weight: 100
toc_hide: true
---

# Jumpstart Agora - Contoso Supermarket troubleshooting

## Basic Troubleshooting

Occasionally deployments of the Agora Contoso Supermarket experience may fail at various stages. Common reasons for failed deployments include:

- Invalid Azure service principal id, service principal secret, or service principal Azure tenant ID provided in _azuredeploy.parameters.json_ file.
- Invalid SSH public key provided in _azuredeploy.parameters.json_ file.
  - An example SSH public key is shown here. Note that the public key includes "ssh-rsa" at the beginning. The entire value should be included in your _main.parameters.json_ file.

    ![Screenshot showing SSH public key example](./img/ssh_example.png)

- User has not forked the [jumpstart-agora-apps GitHub repository](https://github.com/microsoft/jumpstart-agora-apps). To simulate the developer experience, you must first fork the sample apps repo so that you have your own version of the underlying source code to work with. Instructions on how to fork this repo are included in the [deployment guide](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md).
- Not enough vCPU quota available in your target Azure region - check vCPU quota and ensure you have at least 40 available vCPU.
  - You can use the command ```az vm list-usage --location <your location> --output table``` to check your available vCPU quota.

    ![Screenshot showing az vm list-usage](./img/az_vm_list_usage.png)

- Target Azure region does not support all required Azure services - ensure you are running Agora in one of the supported regions listed in the [deployment guide](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md).

### Exploring logs from the _Agora-Client-VM_ virtual machine

Occasionally, you may need to review log output from scripts that run on the _Agora-Client-VM_ virtual machine in case of deployment failures. To make troubleshooting easier, the Agora deployment scripts collect all relevant logs in the _C:\Agora\Logs_ folder on _Agora-Client-VM_. A short description of the logs and their purpose can be seen in the list below:

| Log file | Description |
| ------- | ----------- |
| _C:\Agora\Logs\AgLogonScript.log_ | Output from the primary PowerShell script that drives most of the automation tasks. |
| _C:\Agora\Logs\ArcConnectivity.log_ | Output from the tasks that onboard servers and Kubernetes clusters to Azure Arc. |
| _C:\Agora\Logs\AzCLI.log_ | Output from Az CLI login. |
| _C:\Agora\Logs\AzPowerShell.log_ | Output from the installation of PowerShell modules. |
| _C:\Agora\Logs\Bookmarks.log_ | Output from the configuration of Microsoft Edge bookmarks. |
| _C:\Agora\Logs\Bootstrap.log_ | Output from the initial bootstrapping script that runs on _Agora-Client-VM_. |
| _C:\Agora\Logs\ClusterSecrets.log_ | Output of secret creation on Kubernetes clusters. |
| _C:\Agora\Logs\GitOps-Ag-*.log_ | Output of scripts that collect GitOps logs on the remote Kubernetes clusters. |
| _C:\Agora\Logs\IoT.log_ | Output of automation tasks that configure Azure IoT services. |
| _C:\Agora\Logs\L1AKSInfra.log_ | Output of scripts that configure AKS Edge Essentials clusters on the nested virtual machines. |
| _C:\Agora\Logs\Nginx.log_ | Output from the script that configures Nginx load balancing on the Kubernetes clusters. |
| _C:\ArcBox\Logs\Observability.log_ | Output from the script that configures observability components of the solution. |
| _C:\ArcBox\Logs\Tools.log_ | Output from the tasks that set up developer tools on _Agora-Client-VM_. |

  ![Screenshot showing Agora logs folder on ArcBox-Client](./PLACEHOLDER.png)
