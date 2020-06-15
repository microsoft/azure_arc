# Overview

The following is a guide on how to use the Azure Cloud Shell to deploy an Azure Red Hat OpenShift 4 cluster and have it as a connected Azure Arc Kubernetes resource.

# Deployment
There are two sets of resources that will be deployed, first is the Azure RedHat Openshift Container cluster. Second is the Azure Arc Kubernetes resource that will connect the ```aro``` cluster to Azure Arc.

The deployment of all resources is going to be done via Azure Cloud Shell.


  * Log into Azure Cloud Shell.

    <img src="../img/aro/image1.png" width="80%"><br>

  * Run the following script:
    ```bash
    wget -O - https://raw.githubusercontent.com/alihhussain/AzureTemplates/master/arc/aro/run.sh | bash
    ```
  
    This script will perform the following tasks:
      *  Deploy the following Resources:
         resources are deployed. 
         * Azure VNet
         * Azure Redhat OpenShift (```aro```) cluster
         * Azure Arc K8s connected resource
         * Azure Container Instance
           * This is a helper container which will orchestrate the deployment of all the resources and delete itself when 
      
    There are going to be two resource groups created:
      *  1st Resource Group's named **arcarodemo-** followed by 4 random characters and will container:
         * VNet
         * Aro cluster
         * Arc connectedk8s resource
      *  2nd Resource Group will be named randomly and will contain:
         * All resourced needed for ```aro``` cluster
         * Aro resource requires:
         * atleast 3 master nodes
         * alteast 3 worker nodes
         * The smallest worker nodes SKU type is **Standard_D4as_v4**
         * The smallest master nodes SKU type is **Standard_D8s_v3**

    Deleting the first resource will delete the **managed** resource as well.
    
    When the script is finished copy the **device login code**
    
    <img src="../img/aro/image2.png" width="80%"><br>
  
  * To start creating resources first log into [Azure device login page](https://microsoft.com/devicelogin) and authenticate your credentials and that code copied earlier.
  
    <img src="../img/aro/image3.png" width="80%"><br>
    
  * Close the Cloud Shell and navigate to the Resource Group

    <img src="../img/aro/image4.png" width="80%"><br>

    <img src="../img/aro/image5.png" width="80%"><br>

  *  To track progress navigate to the logs of the container by selecting **Containers** under **Settings** and then selecting **Logs**. The deployment of resources can take up to **50 mins**.

      <img src="../img/aro/image6.png" width="80%"><br>

  * Upon completion, the following resources will be deployed in the resource group:
    *  Azure Arc enabled Kubernetes
    *  OpenShift cluster
    *  Azure VNet<br><br>

    <img src="../img/aro/image7.png" width="90%">

# Delete the deployment

The way to delete all the resources deployed is by deleting the resource group. This will delete the managed resource group as well that was created for Azure Redhat OpenShift cluster.

<img src="../img/aro/image8.png" width="90%">