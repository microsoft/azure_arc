# Overview

The following README will guide you on how to enable [Azure Monitor for Containers](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-overview) for a Google Kubernetes Engine (GKE) cluster that is projected as an Azure Arc connected cluster.

In this guide, you will hook the GKE cluster to Azure Monitor by deploying the [OMS agent](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/log-analytics-agent) on your Kubernetes cluster in order to start collecting telemetry.  

**Note: This guide assumes you already deployed a GKE cluster and connected it to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion using [Terraform](gke_terraform.md).**

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    To connect a Kubernetes cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```bash
    az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor
    ```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcK8s",
    "name": "http://AzureArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Azure Monitor for Containers Integration

* In order to keep your local environment clean and untouched, we will use [Google Cloud Shell](https://cloud.google.com/shell) to run the [*gke_monitor_onboarding*](../gke/gke_monitor/gke_monitor_onboarding.sh) shell script against the GKE connected cluster.

* Before integrating the cluster with Azure Monitor for Containers, click on the "Insights (preview)" blade for the connected Arc cluster to show how the cluster is not currently being monitored. 

    ![](../img/gke_monitor/01.png)

    ![](../img/gke_monitor/02.png)

* Edit the environment variables in the script to match your environment parameters, upload it to the Cloud Shell environment and run it using the ```. ./gke_monitor_onboarding.sh``` command.

    **Note**: The extra dot is due to the shell script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands. 

    ![](../img/gke_monitor/03.png)

    ![](../img/gke_monitor/04.png)

    ![](../img/gke_monitor/05.png)

    ![](../img/gke_monitor/06.png)

    ![](../img/gke_monitor/07.png)

    The script will:

    - Login to your Azure subscription using the SPN credentials
    - Download and modify the downloaded OMS script to be able login to Azure using your SPN credentials instead of your device token
    - Retrieve cluster Azure resource ID as well as the cluster credentials (KUBECONFIG)
    - Execute the modify script which will create Azure Log Analytics workspace, deploy the OMS agent on the Kubernetes cluster and tag the cluster
    - Delete both the downloaded and the modify scripts

* Once the script will complete it's run, you will have an Azure Arc connected cluster integrated with Azure Monitor for Containers. At the end of it's run, the script generates URL for you to click on. This URL will open a new browser tab leading to the Azure Monitor for Containers Insights page. 

    **Note: As the OMS start collecting telemetry from the cluster nodes and pods, it will take 5-10min for data to start show up in the Azure Portal.**

    ![](../img/gke_monitor/08.png)

    ![](../img/gke_monitor/09.png)

* Click the "Connected Clusters" tab and see the Azure Arc connected cluster was added. Now that your cluster is being monitored, navigate trough the different tabs and sections and watch the monitoring telemetry for the cluster nodes and pods.  

    ![](../img/gke_monitor/10.png)

    ![](../img/gke_monitor/11.png)

    ![](../img/gke_monitor/12.png)

    ![](../img/gke_monitor/13.png)

    ![](../img/gke_monitor/14.png)
