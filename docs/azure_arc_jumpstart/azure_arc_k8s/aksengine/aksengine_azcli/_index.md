---
type: docs
title: "AKS Engine Kubernetes Cluster with Azure CLI"
linkTitle: "AKS Engine Kubernetes Cluster with Azure CLI"
weight: 1
description: >
---

## AKS Engine in Azure 

The following README will guide you on how to use the provided Bash script to deploy an AKS Engine in Azure and connect it as an Arc enabled cluster. [AKS Engine](https://github.com/Azure/aks-engine) is an ARM template based tool that allows you to provision a self-managed Kubernetes cluster on Azure.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```
  
* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure service principal (SP)

    To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcK8s",
    "name": "http://AzureArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)**
## Installing AKS Engine

* AKS Engine requires a binary installed in the system. You can refer to [AKS Engine Releases](https://github.com/Azure/aks-engine/releases/latest) to get the latest version, the following example downloads and installs version 0.61.0:

```bash
# Install AKS engine
# Go here: https://github.com/Azure/aks-engine/releases/latest
# Example with v0.61.0:
aksengine_exec=$(which aks-engine)
if [[ -n "$aksengine_exec" ]]
then
    echo "aks-engine executable found in ${aksengine_exec}"
else
    echo "Downloading and installing aks-engine executable..."
    aksengine_tmp=/tmp/aksengine.tar.gz
    wget https://github.com/Azure/aks-engine/releases/download/v0.61.0/aks-engine-v0.61.0-linux-amd64.tar.gz -O $aksengine_tmp
    tar xfvz $aksengine_tmp -C /tmp/
    sudo cp /tmp/aks-engine-v0.61.0-linux-amd64/aks-engine /usr/local/bin
fi
```

## Deployment

In this guide we will generate an AKS Engine cluster with 1 master node and 2 worker nodes. There are additional examples for the required JSON files with different configurations in [AKS Engine Examples](https://github.com/Azure/aks-engine/tree/master/examples). 

* Before initiating the deployment, edit the [*arc_k8s_aksengine.sh script*](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/azure_arc_k8s_jumpstart/aksengine/arc_k8s_aksengine.sh) script so that the environment variables match your setup:

  * k8s_rg: Azure Resource Group where all the AKS Engine resources get deployed. For example: arc-engine-demo
  * location: Azure location where the AKS Engine resource will be created in Azure. For example: westeurope
  * arc_rg: Azure Resource Group to connect your Azure Arc enabled cluster. For example: arc-engine-demo
  * arc_name: Name of for the Azure Arc connect cluster. For example: aks-engine-demo

* To start the automation, you will need to run the [arc_k8s_aksengine.sh script](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/azure_arc_k8s_jumpstart/aksengine/arc_k8s_aksengine.sh) to do that run the command below: 

```bash
./arc_k8s_aksengine.sh
```

* The script will:
  * Set up the environment variables that match your custom deployment.
  * Create the *aksengine_cluster.json* file to configure AKS Engine in Azure.
  * Use the *aks-engine* executable to create the cluster.
  * Export the KUBECONFIG variable to be able to connect to the cluster.
  * Onboard the cluster onto Azure Arc.

## Cleanup

You can delete all resources created in this guide with these commands:

```bash
# Delete both resource groups
az group delete -y --no-wait -n $k8s_rg
az group delete -y --no-wait -n $arc_rg
```

For example:

```bash
az group delete -y --no-wait -n arc-aksengine-demo
az group delete -y --no-wait -n arc-aksengine-demo
```
