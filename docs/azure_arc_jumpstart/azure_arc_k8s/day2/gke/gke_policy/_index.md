---
type: docs
title: "Apply GitOps configurations on GKE as an Azure Arc Connected Cluster using Azure Policy for Kubernetes"
linkTitle: "Apply GitOps configurations on GKE as an Azure Arc Connected Cluster using Azure Policy for Kubernetes"
weight: 4
description: >
---

## Apply GitOps configurations on GKE as an Azure Arc Connected Cluster using Azure Policy for Kubernetes

The following README will guide you on how to enable [Azure Policy for Kubernetes](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#:~:text=Azure%20Policy%20extends%20Gatekeeper%20v3,Kubernetes%20clusters%20from%20one%20place.) on a Google Kubernetes Engine (GKE) cluster that is projected as an Azure Arc connected cluster as well as how to create GitOps policy to apply on the cluster.

> **Note: This guide assumes you already deployed a GKE cluster and connected it to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion using [Terraform](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/gke/gke_terraform/).**

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* As mentioned, this guide starts at the point where you already have a connected GKE cluster to Azure Arc.

    ![Existing GKE Azure Arc-enabled Kubernetes cluster](./01.png)

    ![Existing GKE Azure Arc-enabled Kubernetes cluster](./02.png)

* Before installing the Azure Policy addon or enabling any of the service features, your subscription must enable the Microsoft.PolicyInsights resource provider and create a role assignment for the cluster service principal. To do that, open [Azure Cloud Shell](https://shell.azure.com/) and run either the Azure CLI or Azure PowerShell command.

    ![Azure Cloud Shell](./03.png)

    Azure CLI:

    ```shell
    az provider register --namespace 'Microsoft.PolicyInsights'
    ```

    PowerShell:

    ```powershell
    Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
    ```

* To verify successful registration, run either the below Azure CLI or Azure PowerShell command.

    Azure CLI:

    ```shell
    az provider show --namespace 'Microsoft.PolicyInsights'
    ```

    PowerShell:

    ```powershell
    Get-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
    ```

    ![Installing the Azure Policy addon resource provider](./04.png)

    ![Installing the Azure Policy addon resource provider](./05.png)

* Create Azure service principal (SP)

    > **Note: This guide assumes you will be working with a service principal assigned with the 'Contributor' role as described below. If you want to further limit the RBAC scope of your service Principal, you can assign it with the 'Policy Insights Data Writer (Preview)' role the Azure Arc-enabled Kubernetes cluster as described [here](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/governance/policy/concepts/policy-for-kubernetes.md#install-azure-policy-add-on-for-azure-arc-enabled-kubernetes-preview).**

* To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in Azure Cloud Shell).

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

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

## Azure Policy for Azure Arc Connected Cluster Integration

* In order to keep your local environment clean and untouched, we will use [Google Cloud Shell](https://cloud.google.com/shell) to run the [*gke_policy_onboarding*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/gke/azure_policy/gke_policy_onboarding.sh) shell script against the GKE connected cluster.

* Edit the environment variables in the script to match your environment parameters, upload it to the Cloud Shell environment and run it using the ```. ./gke_policy_onboarding.sh``` command. **If you decided to use the 'Policy Insights Data Writer (Preview)' role assignment as described in the perquisites section, make sure to use it's respective *appId*, *password* and *tenantId***.

    **Note**: The extra dot is due to the shell script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands.  

    ![Run GCP Cloud Shell](./06.png)

    ![Run GCP Cloud Shell](./07.png)

    ![Upload a file to GCP Cloud Shell](./08.png)

    ![Upload a file to GCP Cloud Shell](./09.png)

    ![Upload a file to GCP Cloud Shell](./10.png)

    The script will:

  * Install Helm 3 & Azure CLI
  * Install NGINX Ingress Controller
  * Login to your Azure subscription using the SPN credentials
  * Retrieve cluster Azure Resource ID
  * Install the 'azure-policy-addon' helm chart & Gatekeeper

    After few seconds, by running the the ```kubectl get pods -A``` command, you will notice all pods have been deployed.

    ![kubectl get pods](./11.png)

## Deploy GitOps to Azure Arc Kubernetes cluster using Azure Policy

Although you can [deploy GitOps configuration individually](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_gitops_basic/) on each of your Azure Arc connected clusters, Azure Policy for Kubernetes allows to do the same on a broader scope (i.e Subscription or resource group). That way, you can guarantee existing and newly added Azure Arc connected clusters to all have the same GitOps configuration and as a result, the same cluster baseline and/or application version deployed.

* Before assigning the policy, in the Azure portal, click the *Configuration* setting in your GKE connected cluster. Notice how no GitOps configurations are deployed.

    ![No GitOps configurations](./12.png)

* In the Search bar, look for *Policy* and click on *Definitions* which will show you all of the available Azure policies.

    ![Search for Azure Policy Definitions in the Azure portal](./13.png)

    ![Search for Azure Policy Definitions in the Azure portal](./14.png)

* The "[Preview]: Deploy GitOps to Kubernetes cluster" policy is part of the Kubernetes policies. Once you filter to find these, click on the policy and the 'Assign' button.

    ![Azure Policy in the Azure portal](./15.png)

    ![Azure Policy definitions in the Azure portal](./16.png)

* In the below example, the scope of the policy represent the resource group where the GKE connected cluster Azure Arc resource is located. Alternatively, the scope could have been the entire Azure subscription or a resource group with many Azure Arc connected clusters. Also, make sure *Policy enforcement* is set to *Enabled*.

    For this GitOps configuration policy, we will be using the ["Hello Arc"](https://github.com/likamrat/hello_arc) application repository which includes the Kubernetes Service for external access, Deployment as well as the ingress rule to be used by the NGINX ingress controller.

    ![Assign the "[Preview]: Deploy GitOps to Kubernetes cluster" Azure Policy](./17.png)

    ![Assign the "[Preview]: Deploy GitOps to Kubernetes cluster" Azure Policy](./18.png)

    ![Assign the "[Preview]: Deploy GitOps to Kubernetes cluster" Azure Policy](./19.png)

    ![Assign the "[Preview]: Deploy GitOps to Kubernetes cluster" Azure Policy](./20.png)

* Once the policy configuration deployed, after ~10-20min, the policy remediation task will start the evaluation against the Kubernetes cluster, recognize it as "Non-compliant" (since it's still does note have the GitOps configuration deployed) and lastly, after the configuration has been deployed the policy will move to a "Compliant" state. To check this, go back to the main Policy page in the Azure portal.

    > **Note: The process of evaluation all the way to the point that the GitOps configuration is deployed against the cluster can take ~15-30min.**

    ![Verifying Azure Policy status and compliance state](./21.png)

    ![Verifying Azure Policy status and compliance state](./22.png)

    ![Verifying Azure Policy status and compliance state](./23.png)

    ![Verifying Azure Policy status and compliance state](./24.png)

    ![Verifying Azure Policy status and compliance state](./25.png)

## Verify GitOps Configuration & App Deployment

* Now that the policy is in compliant state, let's first verify the GitOps configurations. In the Azure portal click the GKE connected Azure Arc cluster and open the Configurations settings.

    ![Newly created GitOps configurations](./26.png)

    ![Newly created GitOps configurations](./27.png)

    ![Newly created GitOps configurations](./28.png)

* In order to verify the "Hello Arc" application and it's component has been deployed, In the Google Cloud Shell, run the below commands.

    ```shell
    kubectl get pods -n hello-arc
    kubectl get ing -n hello-arc
    kubectl get svc -n hello-arc
    ```

    You can see how the Flux GitOps operator, Memcached, the "Hello Arc" application and the ingress rule now deployed on the cluster as well the Kubernetes service with an external IP.

    ![Running kubectl commands to verifying successful deployment](./29.png)

* Copy the Service external IP and paste in your browser to see the deployed "Hello Arc" application.

    ![Deployed "Hello Arc" application](./30.png)

## Clean up environment

Complete the following steps to clean up your environment.

* Delete the GKE cluster as described in the [teardown instructions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/gke/gke_terraform/).

* From the Policy page in the Azure portal, remove the "[Preview]: Deploy GitOps to Kubernetes cluster" policy assignment from the cluster.

    ![Delete Azure Policy assignment](./31.png)

    ![Delete Azure Policy assignment](./32.png)
