---
type: docs
title: "ARO Cluster"
linkTitle: "ARO Cluster"
weight: 1
description: >-
---

## Deploy Azure Red Hat OpenShift Cluster and connect it to Azure Arc using automation

The following is a guide on how to use the Azure Cloud Shell to deploy an [Azure Red Hat OpenShift](https://azure.microsoft.com/en-us/services/openshift/) 4 cluster and have it as a connected Azure Arc Kubernetes resource.

## Prerequisites

* Ensure the user logging into Azure portal as admin or co-admin rights to be able to create service principals and/or assign policies to those service principals.

* [Enable subscription with](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) the two resource providers for Azure Arc-enabled Kubernetes. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.Kubernetes
  az provider register --namespace Microsoft.KubernetesConfiguration
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.Kubernetes -o table
  az provider show -n Microsoft.KubernetesConfiguration -o table
  ```

## Deployment

There are two sets of resources that will be deployed, first is the Azure Red Hat OpenShift Container cluster. Second is the Azure Arc Kubernetes resource that will connect the ```aro``` cluster to Azure Arc.

The deployment of all resources is going to be done via Azure Cloud Shell.

* Log into Azure Cloud Shell.

  ![Screenshot showing Azure Cloud Shell](./image1.png)

* Run the following script:

  ```shell
  wget -O - https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_k8s_jumpstart/aro/run.sh | bash
  ```

  This script will perform the following tasks:

  * Deploy the following Resources:

    * Azure Container Instance
    * Azure VNet
    * Azure Red Hat  OpenShift (```aro```) cluster
    * Azure Arc K8s connected resource
    * Ensure required providers are registered
  
* When the script is finished copy the **device login code**
  
  ![Screenshot showing device login code](./image2.png)
  
* To start creating resources first log into [Azure device login page](https://microsoft.com/devicelogin) and authenticate your credentials and that code copied earlier.
  
  ![Screenshot showing how to use device code with Azure login](./image3.png)

* Close the Cloud Shell and navigate to the resource group

  ![Screenshot showing Azure Portal closing Cloud Shell](./image4.png)

  ![Screenshot showing Azure Portal](./image5.png)

* To track progress navigate to the logs of the container by selecting **Containers** under **Settings** and then selecting **Logs**. This deployment can take up to ***50 mins***.

  ![Screenshot showing Azure Portal container deployment](./image6.png)

* Upon completion, the following resources will be deployed in the resource group:

  * Azure Arc-enabled Kubernetes
  * OpenShift cluster
  * Azure VNet

  ![Screenshot showing Azure Portal with Azure Arc-enabled Kubernetes resources](./image7.png)

## Delete the deployment

The way to delete all the resources deployed is by deleting the resource group. This will delete the managed resource group as well the resources created for the Azure Arc-enabled Kubernetes cluster.

![Screenshot showing how to delete resource group from Azure Portal](./image8.png)
