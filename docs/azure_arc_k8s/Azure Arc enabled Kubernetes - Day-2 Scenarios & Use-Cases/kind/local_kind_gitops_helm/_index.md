---
title: "Deploy GitOps configurations and perform Helm-based GitOps flow on kind as an Azure Arc Connected Cluster"
linkTitle: "Local Kind GitOps Helm"
weight: 1
description: >
---

# Deploy GitOps configurations and perform Helm-based GitOps flow on kind as an Azure Arc Connected Cluster

## Overview

The following README will guide you on how to create [Helm](https://helm.sh/)-based GitOps configuration on a [kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/) cluster which is projected as an Azure Arc connected cluster resource.

In this guide, you will first deploy a nginx ingress controller to your cluster. Then you will deploy & attach a GitOps configuration to your cluster. This will be a namespace-level config to deploy the "Hello Arc" web application on your Kubernetes cluster.

By doing so, you will be able to make real-time changes to the application and show how the GitOps flow takes effect.

**Note: This guide assumes you already deployed a kind and connected it to Azure Arc. If you haven't, this repository offers you a way to do so in the [kind onboarding guide](../../../kind/local_kind).**

## Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* Fork/Clone the ["Hello Arc"](https://github.com/likamrat/hello_arc) demo application repository. 

* (Optional) Install the "Tab Auto Refresh" extension for your browser. This will help you to show the real-time changes on the application in an automated way. 

    * [Microsoft Edge](https://microsoftedge.microsoft.com/addons/detail/odiofbnciojkpogljollobmhplkhmofe)

    * [Google Chrome](https://chrome.google.com/webstore/detail/tab-auto-refresh/jaioibhbkffompljnnipmpkeafhpicpd?hl=en)

    * [Mozilla Firefox](https://addons.mozilla.org/en-US/firefox/addon/tab-auto-refresh/)

* As mentioned, this guide starts at the point where you already have a connected kind cluster to Azure Arc.

    ![](./01.png)

    ![](./02.png)

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    To connect a Kubernetes cluster to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor```

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
# Manually setting up an ingress contoller on kind

The demo application that will be deployed later in this guide relies on an ingress controller. For ingress controllers to work on kind, a specific configuration of the ingress needs to be deployed. For more information related to this, please refer to the [kind documentation](https://kind.sigs.k8s.io/docs/user/ingress/).

### NGINX Controller Deployment
* Run the following command to install the nginx ingress controller on kind:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
    ```
* This command will create a new namespace and deploy the required components in this namespace. To verify the deployment of the ingress controller was successful, make sure the pod with name `ingress-nginx-controller-<random id>-<random id>` is in a running state with 1/1 containers ready:

![](./03.png)

* Finally, test that the ingress is responding to traffic. To test this, either browse to [http://localhost](http://localhost) or use the command line to connect to `localhost`. You should get a HTTP 404 reponse with a nginx footer. This shows that the ingress is working. The 404 response is to be expected since you haven't setup an ingress route yet. You will do that in the next section.

![](./04.png)
![](./05.png)



## Cluster-level Config vs. Namespace-level Config 

### Cluster-level Config

With Cluster-level GitOps config, the goal is to have "horizontal components" or "management components" deployed on your Kubernetes cluster which will then be used by your applications. Good examples are Service Meshes, Security products, Monitoring solutions, etc. 
**Note: You will not be creating a cluster-level config in this guide. For an example of a cluster-level configuration please refer to either the [Helm-based GitOps on AKS scenario](../../aks/aks_gitops_helm) or the [GKE one](../../gke/gke_gitops_helm).**

### Namespace-level Config

With Namespace-level GitOps config, the goal is to have Kubernetes resources deployed only in the namespace selected. The most obvious use-case here is simply your application and its respective pods, services, ingress routes, etc. In the next section will have the "Hello Arc" application deployed on a dedicated namespace. 

## Azure Arc Kubernetes GitOps Configuration with Helm

### The Mechanism (In a nutshell)

In the process of creating Azure Arc enabled Kubernetes GitOps configuration, [Weaveworks Flux Kubernetes Operator](https://github.com/fluxcd/flux) is deployed on the cluster. 

The Operator is aware of the "HelmRelease" Custom Resource Definition (CRD). This HelmRelease points to a helm chart in a git repo and can optionally contain specific values to input into the helm chart. Due to this configuration, a user can choose to leave the chart values intact or to have different values for different releases. 

For example, an application (captured in an Helm chart) dev release can have no pod replication (single pod) while a production release, using the same chart can have 3 pod replicas. 

In the next section will use the "Hello Arc" Helm chart to deploy a production release which we will then change and see the results in real-time.

### Deployment Flow

For our scenario, we will deploy the "Hello Arc" application from the ["demo repository"](https://github.com/likamrat/hello_arc) through GitOps. We will deploy the "Hello Arc" application (a Namespace-level component) with 1 replica to the *prod* namespace.

![](./06.png)

![](./07.png)


### Deployment

* Edit the environment variables in the [*az_k8sconfig_helm_kind*](https://github.com/microsoft/azure_arc/blob/master/azure_arc_k8s_jumpstart/kind/gitops/helm/az_k8sconfig_helm_kind.sh) shell script to match your parameters, and run it using the ```. az_k8sconfig_helm_kind.sh``` command.

**Note**: The extra dot is due to the script having an *export* function and that needs to have the vars exported in the same shell session as the rest of the commands. 

The `az_k8sconfig_helm_kind.sh` script will:

- Login to your Azure subscription using the SPN credentials.
- Create the GitOps configurations for the Azure Arc Connected Cluster. The configuration will be using the Helm chart located in the "Hello Arc" repository. This will create a namespace-level config to deploy the "Hello Arc" application Helm chart.

**Disclaimer: For the purpose of this guide, notice how the "*git-poll-interval 3s*" is set. The 3 seconds interval is useful for demo purposes since it will make the git-poll interval to rapidly track changes on the repository but it is recommended to have longer interval in your production environment (default value is 5min)**

* Once the script will complete its run, you will have the GitOps configuration created and all the resources deployed in your local kind Kubernetes cluster. **Note:** it can take a few minutes for the configuration to change its Operator state status from "Pending" to "Installed".

    ![](./08.png)

    ![](./09.png)


    * The Namespace-level config initiated the "Hello Arc" Pod (1 replica), Service and Ingress Route resource deployment.

        ```bash
        kubectl get pods -n prod
        kubectl get svc -n prod
        kubectl get ing -n prod
        ```

    ![](./10.png) 

## Initiating "Hello Arc" Application GitOps

* The GitOps flow works as follow:

    1. The Flux operator holds the "desired state" of the "Hello Arc" Helm release. This is the configuration we deployed against the Azure Arc connected cluster. The operator will pull the state of the releases in the repository every 3 seconds.

    2. Changing the application release will trigger the Flux operator to kick-in the GitOps flow. In our case, we will be changing the welcome message and the amount of replicas.

    3. A new version of the application will be deployed on the cluster with more replicas as configured. Once the new pods are successfully deployed, the old ones will be terminated (rolling upgrade). 

* To show the above flow, open 2 (ideally 3) side-by-side windows:

    - Local shell running ```kubectl get pods -n prod -w```

    ![](./11.png) 

    - In your own repository fork, open the "Hello Arc" [*hello-arc.yaml*](https://github.com/likamrat/hello_arc/blob/master/releases/prod/hello-arc.yaml) Helm release file. 

    - Another browser window that has the webpage <http://localhost> open  

    End result should look something like this:

    ![](./12.png)   

    As mentioned in the Prerequisites above, it is optional but very recommended to configure the "Tab Auto Refresh" extension for your browser. If you did, in the "Hello Arc" application window, configure it to refresh every 2 seconds.   

    ![](./13.png)   

* In the repository window showing the *hello-arc.yaml* file, change the number of *replicaCount* to 3 as well as the the message text and commit your changes. Alternatively, you can open the forked repository in your IDE, make the change, commit and push it.

    ![](./14.png)

* Upon committing the changes, notice how the rolling upgrade starts. Once the Pods are up & running, the new "Hello Arc" application version window will show the new messages as well as the additional pods replicas, showing the rolling upgrade is completed and the GitOps flow is successful. 

    ![](./15.png)

    ![](./16.png)

    ![](./17.png)

## Cleanup

To delete the GitOps configuration and it's respective Kubernetes resources, edit the environment variables to match the Azure Arc Kubernetes cluster and Resources in the [az_k8sconfig_helm_cleanup_kind](https://github.com/microsoft/azure_arc/blob/master/azure_arc_k8s_jumpstart/kind/gitops/helm/az_k8sconfig_helm_cleanup_kind.sh) shell script. It is recommended to run this script locally, since it also removes elements from the local cluster.

```bash
. ./az_k8sconfig_helm_cleanup_kind.sh
```
![](./18.png)

If you also wish to remove the local kind cluster and the Arc connected cluster from Azure, you can run the following commands:

```bash
kind delete cluster --name <cluster-name>
az group delete -n <resource group name>
```
