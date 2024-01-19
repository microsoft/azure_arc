---
type: docs
title: "Cluster API Azure Provider"
linkTitle: "Cluster API Azure Provider"
weight: 1
description: >
---

## Deploy Kubernetes cluster and connect it to Azure Arc using Cluster API Azure provider

The following Jumpstart scenario will guide you on how to deploy a Kubernetes cluster in Azure virtual machines and connected it as an Azure Arc cluster resource by using the [Kubernetes Cluster API (CAPI) project](https://cluster-api.sigs.k8s.io/introduction.html) and it's [Cluster API Azure provider (CAPZ)](https://cloudblogs.microsoft.com/opensource/2020/12/15/introducing-cluster-api-provider-azure-capz-kubernetes-cluster-management/).

## Architecture (In a nutshell)

From the Cluster API Book docs:

"Cluster API requires an existing Kubernetes cluster accessible via kubectl; during the installation process the Kubernetes cluster will be transformed into a management cluster by installing the Cluster API provider components, so it is recommended to keep it separated from any application workload."

in this scenario, a [Rancher K3s](https://rancher.com/docs/k3s/latest/en/), single node cluster will be automatically deployed for you and will be used as the management cluster. This cluster will then be used to deploy the workload cluster using the Cluster API Azure provider (CAPZ).

## Prerequisites

- The automation for this scenario is designed with the assumption that an existing (brownfield) Ubuntu server is already deployed. This can achieved in multiple ways but we recommend using either an [Ubuntu Azure virtual machine](https://docs.microsoft.com/azure/virtual-machines/linux/quick-create-portal) or Ubuntu deployed [using Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/windows/wsl/install).

- [Install or update Azure CLI to version 2.49.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- Create Azure service principal (SP). To deploy this scenario, an Azure service principal assigned with "Contributor" Role-based access control (RBAC) is required for provisioning Azure resources

    To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArcK8s" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password**.

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

- User is downloading the [provided deployment shell script file](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/cluster_api/capi_azure/installCAPI.sh)

- User is editing the environment variables section in the in the script file (1-time edit). These variables values will be used throughout the deployment.

- At a high level, the script will then perform the following tasks:
  - Download and install all the required artifacts
  - Install the required Azure Arc-enabled Kubernetes required Azure CLI extension
  - Automatically log in to Azure using the provided service principal credentials and will create the deployment Azure resource group
  - Deploy a single node Rancher K3s cluster and will convert it to a CAPI management cluster
  - Download the required [Kustomize](https://kustomize.io/) patch files from the Jumpstart repository for deploying the CAPI workload cluster using the Cluster API Azure provider
  - Onboard the cluster as an Azure Arc-enabled Kubernetes cluster

## Deployment

- As mentioned in the prerequisites section, an existing Ubuntu machine is required.

- In the your directory of the cloned Jumpstart repository, navigate to where the [_installCAPI_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/cluster_api/capi_azure/installCAPI.sh) bash script is located. Alternatively, you can also download just the script instead of cloning the entire repository.

  The script will transform the Rancher K3s Kubernetes cluster to a CAPI management cluster with the Azure Cluster API provisioned (CAPZ) components that are needed. It will then deploy the workload cluster and it's Azure resources based on the environment variables as described in the next bullet. Upon deployment completion, the cluster will be onboarded as an Azure Arc-enabled Kubernetes cluster.

    > **Disclaimer: The CAPI/CAPZ _clusterctl_ CLI tool commands used in the script are taken straight from the ["Cluster API Book"](https://cluster-api.sigs.k8s.io/user/quick-start.html) and deserves it's writers all the credit for it!**
    **The reason being for this process to be included is to provide you with the end-to-end user experience which also include the proprietary automation developed for this Jumpstart scenario.**

- To download the script from the Ubuntu machine, use the below command.

    ```shell
    curl -L https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/cluster_api/capi_azure/installCAPI.sh -o ~/installCAPI.sh
    ```

    ![Screenshot showing the curl command and the downloaded script in the Ubuntu machine](01.png)

- Once downloaded, edit the environment variables to match your Azure subscription and service principal details created in the prerequisites section as well as the required workload cluster details. The following screenshots shows the downloaded/copied script before editing the environment variables.

    ![Screenshot showing the script empty environment variables](02.png)

    > **NOTE: Editing the script can be done either before copy/downloading it to the Ubuntu machine by using an your preferred IDE (for example, VS Code) or after, in the machine itself, using native Linux text editor such as vi or nano.**

- Edit **ONLY** the following environment variables:

    > **NOTE: Both the _`githubAccount`_ and the _`githubBranch`_ are used for testing purposes. Unless you are developing independent tests that are based on the script, there is no need to edit these variables.**

    ![Screenshot showing the githubAccount and the githubBranch environment variables](03.png)

  - _`CONTROL_PLANE_MACHINE_COUNT`_ - Control Plane node count. For example: 1
  - _`WORKER_MACHINE_COUNT`_ - Workers node count. For example: 2
  - _`AZURE_LOCATION`_ - Azure region. For example: eastus2
  - _`AZURE_RESOURCE_GROUP`_ - Name of the Azure resource group will be used for this deployment.
  - _`AZURE_ARC_CLUSTER_RESOURCE_NAME`_ - Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal. A GUID suffix will be added automatically.
  - _`AZURE_SUBSCRIPTION_ID`_ - Azure subscription id
  - _`AZURE_TENANT_ID`_ - Azure tenant id
  - _`AZURE_CLIENT_ID`_ - Azure SPN application client id
  - _`AZURE_CLIENT_SECRET`_ - Azure SPN application client secret
  - _`AZURE_CONTROL_PLANE_MACHINE_TYPE`_ - Control Plane node Azure VM type. For example: "Standard_D4s_v4"
  - _`AZURE_NODE_MACHINE_TYPE`_ - Worker node Azure VM type. For example: "Standard_D8s_v4"

    ![Screenshot showing the user environment variables](./04.png)

- Execute the script using the below command. The script runtime can take ~10-20min, depending on the number of control plane and worker nodes you chose to deploy.

  ```shell
  sudo chmod +x installCAPI.sh && . ./installCAPI.sh
  ```

  > **NOTE: The extra dot is due to the script using the _export_ command, used for exporting the environment variables in the same shell session as the other commands in the script.**

    ![Screenshot showing the script runtime](./05.png)

    ![Screenshot showing the script runtime](./06.png)

    ![Screenshot showing the script runtime](./07.png)

    ![Screenshot showing the script runtime](./08.png)

    ![Screenshot showing the script runtime](./09.png)

    ![Screenshot showing the script runtime](./10.png)

    ![Screenshot showing the script runtime](./11.png)

    ![Screenshot showing the script runtime](./12.png)

    ![Screenshot showing the script runtime](./13.png)

    ![Screenshot showing the script runtime](./14.png)

- Upon completion, you will have a new Cluster API Kubernetes cluster deployed on top of Azure virtual machines that are already onboarded as an Azure Arc-enabled Kubernetes cluster.

  ![Screenshot showing the Azure resource group](./15.png)

  ![Screenshot showing the Azure Arc-enabled Kubernetes cluster resource](./16.png)

## Logging

For ease of troubleshooting and tracking, a deployment log will be created automatically as part of the script runtime. To view the deployment log use the below command:

```shell
cat /home/<USER>/jumpstart_logs/installCAPI.log
```

![Screenshot showing the installCAPI log file](./17.png)

## Cleanup

To cleanup the deployment, simply delete the Azure resource group.

![Screenshot showing the deletion of the Azure resource group](./18.png)
