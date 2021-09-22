---
type: docs
title: "Integrate Azure Monitor for Containers with AKS as an Azure Arc Connected Cluster"
linkTitle: "Integrate Azure Monitor for Containers with AKS as an Azure Arc Connected Cluster"
weight: 3
description: >
---

## Integrate Azure Monitor for Containers with AKS as an Azure Arc Connected Cluster

The following README will guide you on how to onboard an Azure Kubernetes Service (AKS) cluster which is projected an Azure Arc connected cluster resource on to [Azure Monitor for Containers](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-overview).

In this guide, you will hook the AKS cluster to Azure Monitor by deploying the [OMS agent](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/log-analytics-agent) on your Kubernetes cluster to start collecting telemetry.  

> **Note: This guide assumes you already deployed an AKS cluster and connected it to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion using either [ARM Template](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks/aks_arm_template/) or [Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/aks/aks_terraform/).**

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

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

## Azure Monitor for Containers Integration

* In order to keep your local environment clean and untouched, we will use [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) (located in the top-right corner in the Azure portal) to run the *aks_monitor_onboarding* script against the AKS connected cluster. For your convenient, both shell and PowerShell scripts are [provided](https://github.com/microsoft/azure_arc/tree/main/azure_arc_k8s_jumpstart/aks/azure_monitor).

* Before integrating the cluster with Azure Monitor for Containers, click on the "Insights (preview)" blade for the connected Arc cluster to show how the cluster is not currently being monitored.

    ![An existing Azure Arc-enabled Kubernetes cluster](./01.png)

    ![An existing Azure Arc-enabled Kubernetes cluster with no Azure Monitor integration](./02.png)

* Edit the environment variables in either of the scripts to match your environment parameters, upload it to the Cloud Shell environment and run it using the ```. ./aks_monitor_onboarding.sh``` (Bash) or ```./aks_monitor_onboarding.ps1``` (PowerShell) command.

    > **Note: The extra dot is due to the shell script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands.**

    ![Open Azure Cloud Shell](./03.png)

    ![Upload a file to Azure Cloud Shell](./04.png)

    ![Upload a file to Azure Cloud Shell](./05.png)

    ![Upload a file to Azure Cloud Shell](./06.png)

    ![Upload a file to Azure Cloud Shell](./07.png)

    The script will:

  * Login to your Azure subscription using the SPN credentials
  * Download the OMS script
  * Retrieve the Azure Arc Connected Cluster Azure Resource ID as well as the cluster credentials (KUBECONFIG)
  * Execute the script which will create Azure Log Analytics workspace, deploy the OMS agent on the Kubernetes cluster and tag the cluster
  * Delete the downloaded script

* Once the script will complete it's run, you will have an Azure Arc connected cluster integrated with Azure Monitor for Containers. At the end of it's run, the script generates URL for you to click on. This URL will open a new browser tab leading to the Azure Monitor for Containers Insights page.

    > **Note: As the OMS start collecting telemetry from the cluster nodes and pods, it will take 5-10min for data to start show up in the Azure Portal.**

    ![Installing the OMS agent on the cluster](./08.png)

    ![Installing the OMS agent on the cluster](./09.png)

* Click the "Connected Clusters" tab and see the Azure Arc connected cluster was added. Now that your cluster is being monitored, navigate through the different tabs and sections and watch the monitoring telemetry for the cluster nodes and pods.  

    ![Agent install on the cluster](./10.png)

    ![New Azure Monitor telemetry](./11.png)

    ![New Azure Monitor telemetry](./12.png)

    ![New Azure Monitor telemetry](./13.png)

    ![New Azure Monitor telemetry](./14.png)
