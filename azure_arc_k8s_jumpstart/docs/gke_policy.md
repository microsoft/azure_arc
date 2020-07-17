# Overview

The following README will guide you on how to enable [Azure Policy for Kubernetes](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#:~:text=Azure%20Policy%20extends%20Gatekeeper%20v3,Kubernetes%20clusters%20from%20one%20place.) on a Google Kubernetes Engine (GKE) cluster that is projected as an Azure Arc connected cluster as well as how to create GitOps policy to apply on the cluster. 

**Note: This guide assumes you already deployed a GKE cluster and connected it to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion using [Terraform](gke_terraform.md).**

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* As mentioned, this guide starts at the point where you already have a connected GKE cluster to Azure Arc.

    ![](../img/gke_policy/01.png)

    ![](../img/gke_policy/02.png)

* Before installing the Azure Policy Add-on or enabling any of the service features, your subscription must enable the Microsoft.PolicyInsights resource provider and create a role assignment for the cluster service principal. To do that, open [Azure Cloud Shell](https://shell.azure.com/) and run either the Azure CLI or Azure Powershell command. 

    ![](../img/gke_policy/03.png)

    Azure CLI:
    ```bash
    az provider register --namespace 'Microsoft.PolicyInsights'
    ```

    Azure Powershell:
    ```powershell
    Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
    ```

    To verify successful registration, run either the below Azure CLI or Azure Powershell command. 

    Azure CLI:
    ```bash
    az provider show --namespace 'Microsoft.PolicyInsights'
    ```

    Azure Powershell:
    ```powershell
    Get-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
    ```

    ![](../img/gke_policy/04.png)

    ![](../img/gke_policy/05.png)

* Create Azure Service Principal (SP)   

    **Note: This guide assumes you will be working with a service principal assigned with the 'Contributor' role as described below. If you want to further limit the RBAC scope of your service principle, you can assign it with the 'Policy Insights Data Writer (Preview)' role the Azure Arc enabled Kubernetes cluster as described [here](https://github.com/MicrosoftDocs/azure-docs/edit/master/articles/governance/policy/concepts/policy-for-kubernetes#L247-L275).**
    
    To connect a Kubernetes cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in Azure Cloud Shell).

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

# Azure Policy for Azure Arc Connected Cluster Integration

* In order to keep your local environment clean and untouched, we will use [Google Cloud Shell](https://cloud.google.com/shell) to run the [*gke_policy_onboarding*](../gke/azure_policy/gke_policy_onboarding.sh) shell script against the GKE connected cluster.
 
* Edit the environment variables in the script to match your environment parameters, upload it to the Cloud Shell environment and run it using the ```. ./gke_policy_onboarding.sh``` command. **If you decided to use the 'Policy Insights Data Writer (Preview)' role assignment as described in the perquisites section, make sure to use it's respective *appId*, *password* and *tenantId*** 

    **Note**: The extra dot is due to the shell script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands.  

    ![](../img/gke_policy/06.png)

    ![](../img/gke_policy/07.png)

    ![](../img/gke_policy/08.png)

    ![](../img/gke_policy/09.png)

    ![](../img/gke_policy/10.png)

    The script will:

    - Install Helm 3 & Azure CLI
    - Install NGINX Ingress Controller
    - Login to your Azure subscription using the SPN credentials
    - Retrieve cluster Azure Resource ID
    - Install the 'azure-policy-addon' helm chart & Gatekeeper

    After few seconds, by running the the ```kubectl get pods -A``` command, you will notice all pods have been deployed. 

    ![](../img/gke_policy/11.png)

# Deploy GitOps to Azure Arc Kubernetes cluster using Azure Policy 

Although you can [deploy GitOps configuration individually](gke_gitops.md) on each of your Azure Arc connected clusters, Azure Policy for Kubernetes allows to do the same on a broader scope (i.e Subscription or Resource Group). That way, you can guarantee existing and newly added Azure Arc connected clusters to all have the same GitOps configuration and as a result, the same cluster baseline and/or application version deployed.   

* Before assigning the policy, in the Azure portal, click the *Configuration* setting in your GKE connected cluster. Notice how no GitOps configurations are deployed.

    ![](../img/gke_policy/12.png)

* In the Search bar, look for *Policy* and click on *Definitions* which will show you all of the available Azure policies.

    ![](../img/gke_policy/13.png)

    ![](../img/gke_policy/14.png)

 * The "[Preview]: Deploy GitOps to Kubernetes cluster" policy is part of the Kubernetes policies. Once you filter to find these, click on the policy and the 'Assign' button.

    ![](../img/gke_policy/15.png)

    ![](../img/gke_policy/16.png)

* In the below example, the scope of the policy represent the Resource Group where the GKE connected cluster Azure Arc resource is located. Alternatively, the scope could have been the entire Azure Subscription or a Resource Group with many Azure Arc connected clusters. Also, make sure *Policy enforcement* is set to *Enabled*.   

    For this GitOps configuration policy, we will be using the ["Hello Arc"](https://github.com/likamrat/hello_arc) application repository which includes the Kubernetes Service for external access, Deployment as well as the ingress rule to be used by the NGINX ingress controller.

    ![](../img/gke_policy/17.png)

    ![](../img/gke_policy/18.png)

    ![](../img/gke_policy/19.png)

    ![](../img/gke_policy/20.png)

* Once the policy configuration deployed, after ~10-20min, the policy remediation task will start the evaluation against the Kubernetes cluster, recognize it as "Non-compliant" (since it's still does note have the GitOps configuration deployed) and lastly, after the configuration has been deployed the policy will move to a "Compliant" state. To check this, go back to the main Policy page in the Azure portal.

    **Note: The process of evaluation all the way to the point that the GitOps configuration is deployed against the cluster can take ~15-30min.**

    ![](../img/gke_policy/21.png)

    ![](../img/gke_policy/22.png)

    ![](../img/gke_policy/23.png)    

    ![](../img/gke_policy/24.png)  

    ![](../img/gke_policy/25.png)  

# Verify GitOps Configuration & App Deployment

* Now that the policy is in compliant state, let's first verify the GitOps configurations. In the Azure portal click the GKE connected Azure Arc cluster and open the Configurations settings. 

    ![](../img/gke_policy/26.png)  

    ![](../img/gke_policy/27.png)  

    ![](../img/gke_policy/28.png)          

* In order to verify the "Hello Arc" application and it's component has been deployed, In the Google Cloud Shell, run the below commands.

    ```bash
    kubectl get pods -n hello-arc
    kubectl get ing -n hello-arc
    kubectl get svc -n hello-arc
    ```

    You can see how the Flux GitOps operator, Memcached, the "Hello Arc" application and the ingress rule now deployed on the cluster as well the Service with an external IP. 

    ![](../img/gke_policy/29.png)  

* Copy the Service external IP and paste in your browser. 

    ![](../img/gke_policy/30.png) 

# Clean up environment

Complete the following steps to clean up your environment.

* Delete the GKE cluster as described in the [teardown instructions](gke_terraform.md).

* From the Policy page in the Azure portal, remove the "[Preview]: Deploy GitOps to Kubernetes cluster" policy assignment from the cluster.

    ![](../img/gke_policy/31.png) 

    ![](../img/gke_policy/32.png)
     