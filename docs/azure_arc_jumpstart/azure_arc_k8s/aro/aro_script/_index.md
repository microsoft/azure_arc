---
title: "Deploy Azure Redhat Openshift Cluster and connect it to Azure Arc using automation"
linkTitle: "Deploy Azure Redhat Openshift Cluster and connect it to Azure Arc using automation"
weight: 1
description: >-
---

# Deploy Azure Redhat Openshift Cluster and connect it to Azure Arc using automation

The following is a guide on how to use the Azure Cloud Shell to deploy an [Azure Red Hat OpenShift](https://azure.microsoft.com/en-us/services/openshift/) 4 cluster and have it as a connected Azure Arc Kubernetes resource.

## Prerequisite 
Ensure the user logging into Azure portal as admin or co-admin rights to be able to create service principals and/or assign policies to those service principals.

## Deployment
There are two sets of resources that will be deployed, first is the Azure RedHat Openshift Container cluster. Second is the Azure Arc Kubernetes resource that will connect the ```aro``` cluster to Azure Arc.

The deployment of all resources is going to be done via Azure Cloud Shell.


  * Log into Azure Cloud Shell.

    ![](./image1.png)

  * Run the following script:
    ```bash
    wget -O - https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_k8s_jumpstart/aro/run.sh | bash
    ```
  
    This script will perform the following tasks:
      *  Deploy the following Resources:
         *  Azure Container Instance
         * Azure VNet
         * Azure Redhat OpenShift (```aro```) cluster
         * Azure Arc K8s connected resource
      *  Ensure required providers are registered
    
    When the script is finished copy the **device login code**
    
    ![](./image2.png)
  
  * To start creating resources first log into [Azure device login page](https://microsoft.com/devicelogin) and authenticate your credentials and that code copied earlier.
  
    ![](./image3.png)
    
  * Close the Cloud Shell and navigate to the Resource Group

    ![](./image4.png)

    ![](./image5.png)

  *  To track progress navigate to the logs of the container by selecting **Containers** under **Settings** and then selecting **Logs**. This deployment can take upto ***50 mins***.

      ![](./image6.png)

  * Upon completion, the following resources will be deployed in the resource group:
    *  Azure Arc enabled Kubernetes
    *  OpenShift cluster
    *  Azure VNet<br><br>

    ![](./image7.png)

## Delete the deployment

The way to delete all the resources deployed is by deleting the resource group. This will delete the managed resource group as well that was created for Azure Redhat OpenShift cluster.

![](./image8.png)