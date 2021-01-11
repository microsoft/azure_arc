---
type: docs
title: "Azure Provider"
linkTitle: "Azure Provider"
weight: 1
description: >
---

## Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider

The following README will guide you on to deploy an Kubernetes cluster in Azure virtual machines and connected it as an Azure Arc cluster resource by leveraging the [Kubernetes Cluster API (CAPI) project](https://cluster-api.sigs.k8s.io/introduction.html) and it's [Cluster API Azure provider (CAPZ)](https://cloudblogs.microsoft.com/opensource/2020/12/15/introducing-cluster-api-provider-azure-capz-kubernetes-cluster-management/).

  > **Note: Currently, Azure Arc enabled Kubernetes is in [public preview](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/).**

## Architecture (In a nutshell)

From the Cluster API Book docs:

"Cluster API requires an existing Kubernetes cluster accessible via kubectl; during the installation process the Kubernetes cluster will be transformed into a management cluster by installing the Cluster API provider components, so it is recommended to keep it separated from any application workload."

In this guide (as explained in the CAPI Book docs), you will deploy a local [kind](https://kind.sigs.k8s.io/) cluster which will be used as the management cluster. This cluster will then be used to deploy the workload cluster using the Cluster API Azure provider (CAPZ).

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```
  
* [Install or update Azure CLI to version 2.7.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* Create Azure service principal (SP)

    To connect a Kubernetes cluster to Azure Arc, Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

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

    > **Note: It is optional but highly recommended to scope the SP to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)**

* Enable subscription with the two resource providers for Azure Arc enabled Kubernetes. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.Kubernetes
  az provider register --namespace Microsoft.KubernetesConfiguration
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.Kubernetes -o table
  az provider show -n Microsoft.KubernetesConfiguration -o table
  ```

* As mentioned, you will need to deploy a local, small footprint Kubernetes cluster using kind which will act the management/provisioner cluster. To install kind on your machine, use the below command.

  > **Note: In order for you to complete this scenario, either a Linux ([WSL incl.](https://docs.microsoft.com/en-us/windows/wsl/install-win10)) or MacOS is required. Currently, this scenario does not support Windows OS**

  On Linux:

  ```shell
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  ```
  
  On MacOS:

  ```shell
  brew install kind
  ```

  ![Screenshot of kind CLI](./01.png)

## Deployment - Management Cluster

> **Disclaimer: The deployment process of a the management cluster and the *clusterctl* CLI tool described in below are taken straight from the ["Cluster API Book"](https://cluster-api.sigs.k8s.io/user/quick-start.html) and deserves it's writers all the credit for it!**
**The reason being for this process to be included is to provide you with the end-to-end user experience which also include the proprietary automation developed for this Jumpstart scenario and will be used later on in this guide.**

* Now that you have kind installed, deploy the local management cluster and test to ensure it's ready using the below commands:

  ```shell
  kind create cluster
  kubectl cluster-info
  ```

  ![Screenshot of kind management cluster deployment](./02.png)

* Install the *clusterctl* CLI tool which handles the lifecycle of a Cluster API management cluster using the below commands:

  On Linux:

  ```shell
  curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.12/clusterctl-linux-amd64 -o clusterctl
  chmod +x ./clusterctl
  sudo mv ./clusterctl /usr/local/bin/clusterctl
  clusterctl version
  ```
  
  On MacOS:

  ```shell
  curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.12/clusterctl-darwin-amd64 -o clusterctl
  chmod +x ./clusterctl
  sudo mv ./clusterctl /usr/local/bin/clusterctl
  clusterctl version
  ```

  ![Screenshot clusterctl installation](./03.png)

## Deployment - Workload Cluster

* In the your directory of the cloned Jumpstart repository, navigate to where the [*arc_capi_azure*](https://github.com/microsoft/azure_arc/tree/main/azure_arc_k8s_jumpstart/cluster_api/capi_azure) bash script is located.

  The script will transform the kind Kubernetes cluster to management cluster with the Azure Cluster API provisioner components that are needed. It will then deploy the workload cluster and it's Azure resources based on the environment variables you will edit in the next bullet. Once the deployment is completed, the cluster will be onboard as an Azure Arc enabled Kubernetes cluster.

* Edit the environment variables to match your Azure subscription and SPN details created in the prerequisites section in this guide as well as the required workload cluster details.

  * *KUBERNETES_VERSION*="Kubernetes version. For example: 1.18.10"
  * *CONTROL_PLANE_MACHINE_COUNT*="Control Plane node count. For example: 1"
  * *WORKER_MACHINE_COUNT*="Workers node count. For example: 2"
  * *AZURE_LOCATION*="Azure region. For example: eastus"
  * *CAPI_WORKLOAD_CLUSTER_NAME*="Workload cluster name. For example: arc-capi-azure". Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
  * *AZURE_SUBSCRIPTION_ID*="Azure subscription id"
  * *AZURE_TENANT_ID*="Azure tenant id"
  * *AZURE_CLIENT_ID=*"Azure SPN application client id"
  * *AZURE_CLIENT_SECRET*="Azure SPN application client secret"
  * *AZURE_CONTROL_PLANE_MACHINE_TYPE*="Control Plane node Azure VM type .For example: Standard_D2_v3"
  * *AZURE_NODE_MACHINE_TYPE*="Worker node Azure VM type .For example: Standard_D4s_v3"

  ![Screenshot of user environment variables](./04.png)

* Execute the script using the below command. The script runtime can take ~10-20min, depends on the number of control plane and worker nodes you chose to deploy. In case you don't have the required Azure CLI extensions already installed or if they are requires an update, the script will either install it or perform an update.

  ```shell
  . ./arc_capi_azure.sh
  ```

  > **Note: The extra dot is due to the script having an *export* function and needs to have the vars exported in the same shell session as the other commands.**

  ![Screenshot of workload cluster deployment script runtime](./05.png)

  ![Screenshot of workload cluster deployment script runtime](./06.png)

  ![Screenshot of workload cluster deployment script runtime](./07.png)

  ![Screenshot of workload cluster deployment script runtime](./08.png)

  ![Screenshot of workload cluster deployment script runtime](./09.png)

* Upon completion, you will have a new Kubernetes cluster deployed on top of Azure virtual machines  that is already onboard as an Azure Arc enabled Kubernetes cluster.

  The script will generate the cluster definition *yaml* file which was used to deploy the workload cluster as will as the *kubeconfig* file. To test the cluster is up and running use the below command.

  ```shell
  kubectl --kubeconfig=./<Name of your workload cluster>.kubeconfig get nodes
  ```

  ![Screenshot of the workload cluster nodes](./10.png)

* In the Azure portal, you can see how all the resources were deployed in a new resource group as well as the Azure Arc enabled Kubernetes cluster resource.

  ![Screenshot of the deployment Azure virtual machines](./11.png)

  ![Screenshot of the Azure Arc enabled Kubernetes cluster in a resource group](./12.png)

  ![Screenshot of the Azure Arc enabled Kubernetes cluster resource](./13.png)  

## Cleanup

* To delete only the workload cluster (and as a result, the Azure resources as well), run the below command. Deletion can take ~10min, depends on the number of control plane and worker nodes you have chosen to deploy.

  ```shell
  kubectl delete cluster "<Name of your cluster>"
  ```

  ![Screenshot of the workload cluster deletion](./14.png)

* In addition, you can also delete the management cluster using the below command.

  ```shell
  kind delete cluster
  ```

  ![Screenshot of the management cluster deletion](./15.png)
