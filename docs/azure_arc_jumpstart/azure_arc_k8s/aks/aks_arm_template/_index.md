---
type: docs
title: "AKS cluster ARM template"
linkTitle: "AKS cluster ARM template"
weight: 1
description: >
---

## Deploy AKS cluster and connect it to Azure Arc using an Azure ARM template

The following Jumpstart scenario will guide you on how to use the provided [Azure ARM Template](https://docs.microsoft.com/azure/azure-resource-manager/templates/overview) to deploy an [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/azure/aks/intro-kubernetes) cluster and connected it as an Azure Arc cluster resource.

  > **NOTE: Since AKS is a 1st-party Azure solution and natively supports capabilities such as [Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview) integration as well as GitOps configurations, it is not expected for an AKS cluster to be projected as an Azure Arc-enabled Kubernetes cluster. Connecting an Azure Kubernetes Service (AKS) cluster to Azure Arc is only required for running Arc enabled services like App Services and Data Services on the cluster.**

## Prerequisites

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```
  
- [Install or update Azure CLI to version 2.49.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- [Generate a new SSH key pair](https://docs.microsoft.com/azure/virtual-machines/linux/create-ssh-keys-detailed) or use an existing one (Windows 10 and above now comes with a built-in ssh client).

  ```shell
  ssh-keygen -t rsa -b 4096
  ```

  To retrieve the SSH public key after it's been created, depending on your environment, use one of the below methods:
  - In Linux, use the `cat ~/.ssh/id_rsa.pub` command.
  - In Windows (CMD/PowerShell), use the SSH public key file that by default, is located in the _`C:\Users\WINUSER/.ssh/id_rsa.pub`_ folder.

  SSH public key example output:

  ```shell
  ssh-rsa o1djFhyNe5NXyYk7XVF7wOBAAABgQDO/QPJ6IZHujkGRhiI+6s1ngK8V4OK+iBAa15GRQqd7scWgQ1RUSFAAKUxHn2TJPx/Z/IU60aUVmAq/OV9w0RMrZhQkGQz8CHRXc28S156VMPxjk/gRtrVZXfoXMr86W1nRnyZdVwojy2++sqZeP/2c5GoeRbv06NfmHTHYKyXdn0lPALC6i3OLilFEnm46Wo+azmxDuxwi66RNr9iBi6WdIn/zv7tdeE34VAutmsgPMpynt1+vCgChbdZR7uxwi66RNr9iPdMR7gjx3W7dikQEo1djFhyNe5rrejrgjerggjkXyYk7XVF7wOk0t8KYdXvLlIyYyUCk1cOD2P48ArqgfRxPIwepgW78znYuwiEDss6g0qrFKBcl8vtiJE5Vog/EIZP04XpmaVKmAWNCCGFJereRKNFIl7QfSj3ZLT2ZXkXaoLoaMhA71ko6bKBuSq0G5YaMq3stCfyVVSlHs7nzhYsX6aDU6LwM/BTO1c= user@pc
  ```

- Create Azure service principal (SP)

    To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

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

## Deployment Options and Automation Flow

This Jumpstart scenario provides multiple paths for deploying and configuring resources. Deployment options include:

- Azure portal
- ARM template via Azure CLI

For you to get familiar with the automation and deployment flow, below is an explanation.

1. User edits the environment variables in the Shell script file (1-time edit) which then be used throughout the deployment.

2. User uploads the script to Azure Cloud Shell and runs the shell script. The script will:

    - Connect to Azure using SPN credentials.
    - Get AKS credentials.
    - Install Azure Arc CLI extensions.
    - Connect the cluster to Azure Arc.

3. User verifies the Arc-enabled Kubernetes cluster.

## Deployment Option 1: Azure portal

- Click the <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fazure_arc%2Fmain%2Fazure_arc_k8s_jumpstart%2Faks%2Farm_template%2Fazuredeploy.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a> button and enter values for the the ARM template parameters.

  ![Screenshot showing Azure portal deployment](./01.png)

  ![Screenshot showing Azure portal deployment](./02.png)

## Deployment Option 2: ARM template with Azure CLI

- Before deploying the ARM template, determine which AKS Kubernetes versions are available in your region using the below Azure CLI command.

  ```shell
  az aks get-versions -l "<Your Azure Region>"
  ```

- The deployment is using the template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks/arm_template/azuredeploy.parameters.json) file to match your environment and using one of the available Kubernetes Versions from the previous step.

  ![Screenshot of Azure ARM template](./03.png)

- To deploy the ARM template, navigate to the [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_k8s_jumpstart/aks/arm_template) and run the below command:

  ```shell
  az group create --name <Name of the Azure resource group> --location <Azure Region>
  az deployment group create \
  --resource-group <Name of the Azure resource group> \
  --name <The name of this deployment> \
  --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/aks/arm_template/azuredeploy.json \
  --parameters <The *azuredeploy.parameters.json* parameters file location>
  ```

  For example:

  ```shell
  az group create --name Arc-AKS-Demo --location "East US"
  az deployment group create \
  --resource-group Arc-AKS-Demo \
  --name arcaksdemo01 \
  --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/aks/arm_template/azuredeploy.json \
  --parameters azuredeploy.parameters.json
  ```

  > **NOTE: If you receive an error message stating that the requested VM size is not available in the desired location (as an example: 'Standard_D8s_v3'), it means that there is currently a capacity restriction for that specific VM size in that particular region. Capacity restrictions can occur due to various reasons, such as high demand or maintenance activities. Microsoft Azure periodically adjusts the available capacity in each region based on usage patterns and resource availability. To continue deploying this scenario, please try to re-run the deployment using another region.**

- Once the ARM template deployment is completed, a new AKS cluster in a new Azure resource group is created.

  ![Screenshot of Azure portal showing AKS resource](./04.png)

  ![Screenshot of Azure portal showing AKS resource](./05.png)

## Connecting to Azure Arc

- Now that you have a running AKS cluster, edit the environment variables section in the included [az_connect_aks](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks/arm_template/scripts/az_connect_aks.sh) shell script.

  ![Screenshot of az_connect_aks shell script](./06.png)

  For example:

  ![Screenshot of az_connect_aks shell script](./07.png)

- In order to keep your local environment clean and untouched, we will use [Azure Cloud Shell](https://docs.microsoft.com/azure/cloud-shell/overview) (located in the top-right corner of the Azure portal) to run the *az_connect_aks* shell script against the AKS cluster. **Make sure Cloud Shell is configured to use Bash.**

  ![Screenshot of Azure Cloud Shell button in Visual Studio Code](./08.png)

- After editing the environment variables in the [*az_connect_aks*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/aks/arm_template/scripts/az_connect_aks.sh) shell script to match your parameters, save the file and then upload it to the Cloud Shell environment and run it using the ```. ./az_connect_aks.sh``` command.

  > **NOTE: The extra dot is due to the script having an *export* function and needs to have the vars exported in the same shell session as the other commands.**

  ![Screenshot showing upload of file to Cloud Shell](./09.png)

  ![Screenshot showing upload of file to Cloud Shell](./10.png)

- Once the script run has finished, the AKS cluster will be projected as a new Azure Arc cluster resource.

  ![Screenshot showing Azure portal with Azure Arc-enabled Kubernetes resource](./11.png)

  ![Screenshot showing Azure Portal with Azure Arc-enabled Kubernetes resource](./12.png)

  ![Screenshot showing Azure Portal with Azure Arc-enabled Kubernetes resource](./13.png)

## Delete the deployment

The most straightforward way is to delete the Azure Arc cluster resource via the Azure Portal, just select the cluster and delete it.

![Screenshot showing how to delete Azure Arc-enabled Kubernetes resource](./14.png)

If you want to nuke the entire environment, run the below commands.

```shell
az deployment group delete --name <Deployment name> --resource-group <Azure resource group name>
```

```shell
az group delete --name <Azure resource group name> --yes
```

For example:

```shell
az deployment group delete --name arcaksdemo01 --resource-group Arc-AKS-Demo
```

```shell
az group delete --name Arc-AKS-Demo --yes
```
