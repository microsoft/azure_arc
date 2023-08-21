---
type: docs
title: "Azure Video Indexer Arc extention on AKS"
linkTitle: "Azure Video Indexer Arc extention on AKS"
weight: 1
description: >
---

## Deploy a full Azure Video Indexer enabled by Arc envoiroment with Video Indexer extention on AKS

Azure Video Indexer enabled by Arc is aimed at running Video and Audio Analysis on Edge Devices in a connected fashion, only control plane data is passed to the cloud, while data plane data is stored only on the edge device.
The solution is designed to run on Azure Stack Edge Profile, a heavy edge device, and supports three video formats, including MP4 and four additional common formats. During the public preview, the solution supports eigth Azure languages: English (US), Spanish, German, French, Italian, Portuguese, Chinese (Simplified) in all basic audio-related models.

The following Jumpstart scenario will guide you on how to deploy a "Ready to Go" environment so you can start using [|||Azure Video Indexer enabled by Arc|||](https://azure.microsoft.com/products/ai-video-indexer) deployed on [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/azure/aks/intro-kubernetes) cluster.

By the end of this scenario, you will have an AKS cluster deployed with an App Service plan, a sample Web Application (Web App) and a Microsoft Windows Server 2022 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc-enabled app services.

> **NOTE: Currently, Azure Video Indexer enabled by Arc is in preview.**

## Prerequisites

>NOTE: In order to succesfully deploy the VI Extention it is **mandatory** that we approve your Azure subscription id in advance. Therefore you must first sign up using [this form](https://aka.ms/vi-register).

- Azure subscription with permissions to create Azure resources
- Azure Video Indexer Account. The quickest way is using the Azure Portal using this tutorial [Create Video Indexer account](https://learn.microsoft.com/azure/azure-video-indexer/create-account-portal#use-the-azure-portal-to-create-an-azure-video-indexer-account).
- For the manual deployment, you will need a working Azure Arc Kubernetes environmnet you can follow one of the guides [here](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/).
- The latest version of [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli). You can skip if you're using cloud shell.
- The latest version of connected Kubernetes Azure CLI extension, installed by running the following command. **You can skip if you're using the Cloud Shell** option:

```shell
az extension add --name connectedk8s
```

### Minumum Hardware Requirements

The following is the minumum and recommended requirements if the extension contains single Languge support.
> **NOTE:** If you install multiple Speech and Translation containers with several languages, ensure to increase the hardware requirements accordingly.

| Component | Minimum Requirements | Recommended Requirements |
| --- | --- | --- |
| VM Count | 1 | 2 |
| CPU (Per Cluster)| 16 cores | 32 cores |
| RAM (Per Cluster)| 32 GB | 64 GB |
| Storage | 30 GB | 50 GB |

> **NOTE:** at least 2-node cluster is recommended for high availability and scalability. The Recommended Settings refer to cluster wide settings, so for example, if you have 2 nodes, each node should have 16 cores and 32 GB of RAM.

> **TIP:** We recommend creating a dedicate node-pool / auto-scaling groups to host the VI Solution

### Minimum Software Requirements

| Component |  Minimum Requirements |
| --- | --- |
| Operating System | Ubuntu 20.04 LTS or any Linux Compatible OS |
| Kubernetes | 1.24 |
| Azure CLI | 2.4.0 |

## Automation deployment

**This step is optional.** If you would like to test Video Indexer Edge Extention on a sample edge devide this deployment script can be used to quickly set up a K8S cluster and all pods to run VI on Edge. This script will deploy the following resources:

- Small 2 node AKS Cluster (costs are ~$0.80/hour)
- Enable ARC Extension on top of the cluster
- Add Video Indexer Arc Extension
- Add Video Indexer and Cognitive Services Speech + Translation containers
- Expose the Video Indexer Swagger API for dataplane operations

You can read more on how to set up your cloud shell environment [here](https://learn.microsoft.com/azure/cloud-shell/quickstart?tabs=azurecli).

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://shell.azure.com/bash?url=)

In the cloud shell execute these two commands:

```bash
curl -ssl https://github.com/microsoft/azure_arc/blob/main/azure_arc_video_indexer_jumpstart\aks\vi-edge-deployment-script.sh -o install_vi_arc.sh

sh install_vi_arc.sh
```

During the deployment the script will ask the following questions where you will need to provide your environment specific values. Below table explains each question and the desired value. Some will expect or have default values.

| Question | value | Details
| --- | --- | --- |
| What is the Video Indexer account ID during deployment? | GUID | Your Video Indexer Account ID |
| What is the Azure subscription ID during deployment? | GUID | Your Azure Subscription ID |
| What is the name of the Video Indexer resource group during deployment? | string | The Resource Group Name of your Video Indexer Account |
| What is the name of the Video Indexer account during deployment? | string | Your Video Indexer Account name |

Once deployed you will get a URL to the Data Plane API of your new Video Indexer on Edge extension which is now running on the AKS cluster. You can use this API to perform indexing jobs and test Video Indexer on Edge. Please note that this is **not** meant as a path to production and only provided to quickly test Video Indexer on Edge functionality. This concludes the demo script and you are done. Below are the steps if you want to deploy VI on Edge manually.

## Manual deployment

Follow these steps to deploy the Video Indexer Arc Extention to your Azure Arc-enabled Kubernetes cluster.

## Installation Steps

### Step 1 - Create Azure Arc Kubernetes Cluster and connect it to your cluster

>**NOTE:**
> -The following command assumes you have a kubernetes cluster and that the Current Contenxt on your ./kube/config file points to it.

Run the following command to connect your cluster. This command deploys the Azure Arc agents to the cluster and installs Helm v. 3.6.3 to the .azure folder of the deployment machine. This Helm 3 installation is only used for Azure Arc, and it does not remove or change any previously installed versions of Helm on the machine.

```shell
az connectedk8s connect --name myAKSCluster --resource-group myResourceGroup
```

> **TIP:** Follow the article [how to connect your cluster to Azure Arc][4] on Azure Docs
> for a complete walkthrough on this process

[4]: https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli

### Step 2 - Generate Cognitive Services Resources for the extension

>**NOTE:**
> The resources are created once per each subscription, and used by all the extenions under that subscription.

One of the prerequisites to installing a Video Indexer Arc extension are speech and translator resources. Once the resources are created, their key and endpoint need to be provided in the installation process.
The resources are created once per subscription.
Run the following commands:

```shell
$Subscription="<your subscription ID>"
$ResourceGroup="<your resource group name"
$AccountName="<your account name>"
az rest --method post --verbose --uri https://management.azure.com/subscriptions/${Subscription}/resourceGroups/${ResourceGroup}/providers/Microsoft.VideoIndexer/accounts/${AccountName}/CreateExtensionDependencies?api-version=2023-06-02-preview
```

If the response is 202 (accepted), the resources are being created. You can track their provisioning state by polling the location header returned in the response from the previous call as demonstrated in the below example, or simply wait for 1 minute, and proceed to the next step.

```shell
az rest --method get --uri <the uri from the location response header>
```

If the response is 409 (conflict), it means the resources already exist for your subscription and you can proceed to the below command without waiting.

Once the resources have been created, get their data using this command:

```shell
az rest --method post --uri  https://management.azure.com/subscriptions/${Subscription}/resourceGroups/${ResourceGroup}/providers/Microsoft.VideoIndexer/accounts/${AccountName}/ListExtensionDependenciesData?api-version=2023-06-02-preview
```

You will recieve a response of the following format:

```yaml
{
    "speechCognitiveServicesPrimaryKey": "<key>",
    "speechCognitiveServicesSecondaryKey": "<key>",
    "translatorCognitiveServicesPrimaryKey": "<key>",
    "translatorCognitiveServicesSecondaryKey": "<key>",
    "speechCognitiveServicesEndpoint": "<uri>",
    "translatorCognitiveServicesEndpoint": "<uri>"
}
```

Use this data in the next step.

### Step 3 - Create Azure Arc Video Indexer Extension

The following parameters will be used as input to the extension creation command:

| Parameter | Default | Description |
|-----------|---------|-------------|
| release-namespace | default | The kubernetes namespace which the extension will be installed into |
| cluster-name | | The kubernetes azure arc instance name |
| resource-group | | The kubernetes azure arc resource group name |
| version | 1.0.24-preview | Video Indexer Extension version |
| speech.endpointUri |  | Speech Service Url Endpoint |
| speech.secret |  | Speech Instance secret |
| translate.endpointUri |  | Translation Service Url Endpoint  |
| translate.secret |  | Translation Service secret |
| videoIndexer.accountId |  | Video Indexer Account Id |
| frontend.endpointUri |  | Video Indexer DNS Name to be used as the Portal endpoint |

```shell
                        az k8s-extension create --name videoindexer \
                            --extension-type Microsoft.videoindexer \
                            --scope cluster \
                            --release-namespace ${namespace} \
                            --cluster-name ${connectedClusterName} \
                            --resource-group ${connectedClusterRg} \
                            --cluster-type connectedClusters \
                            --release-train preview  \
                            --version ${version} \
                            --auto-upgrade-minor-version false \
                            --config-protected-settings "speech.endpointUri=${speechUri}" \
                            --config-protected-settings "speech.secret=${speechSecret}" \
                            --config-protected-settings "translate.endpointUri=${translateUri}" \
                            --config-protected-settings "translate.secret=${translateSecret}" \
                            --config "videoIndexer.accountId=${viAccountId}" \
                            --config "frontend.endpointUri=${dnsName}" 

```

There are some additional Parameters that can be used in order to have a fine grain control on the extension creation

| Parameter | Default | Description |
|-----------|---------|-------------|
| AI.nodeSelector | - | The node Selector label on which the AI Pods (speech and translate)  will be assigned to |
| speech.resource.requests.cpu | 1 | The requested number of cores for the speech pod |
| speech.resource.requests.mem | 2Gi | The requested memory capactiy for the speech pod |
| speech.resource.limits.cpu | 2 | The limits number of cores for the speech pod. must be > speech.resource.requests.cpu  |
| speech.resource.limits.mem | 3Gi | The limits memory capactiy for the speech pod. must be > speech.resource.requests.mem  |
| translate.resource.requests.cpu | 1 | The requested number of cores for the translate pod |
| translate.resource.requests.mem | 16Gi | The requested memory capactiy for the translate pod |
| translateeech.resource.limits.cpu | -- | The limits number of cores for the translate pod. must be > translate.resource.requests.cpu  |
| translate.resource.limits.mem | -- | The limits memory capactiy for the translate pod. must be > translate.resource.requests.mem  |
| videoIndexer.webapi.resources.requests.cpu | 0.5 | The request number of cores for the web api pod  |
| videoIndexer.webapi.resources.requests.mem | 4Gi | The request memory capactiy for the web api pod  |
| videoIndexer.webapi.resources.limits.cpu | 1 | The limits number of cores for the web api pod  |
| videoIndexer.webapi.resources.limits.mem | 6Gi | The limits memory capactiy for the web api pod  |
| videoIndexer.webapi.resources.limits.mem | 6Gi | The limits memory capactiy for the web api pod  |
| storage.storageClass | "" | The storage class to be used |
| storage.useExternalPvc | false | determines whether an external PVC is used. if true, the VideoIndexer PVC will not be installed |

example deploy script :

```shell
                        az k8s-extension create --name videoindexer \
                            --extension-type Microsoft.videoindexer \
                            .......
                            
                            --config AI.nodeSelector."beta\\.kubernetes\\.io/os"=linux
                            --config "speech.resource.requests.cpu=500m" \
                            --config "speech.resource.requests.mem=2Gi" \
                            --config "speech.resource.limits.cpu=1" \
                            --config "speech.resource.limits.mem=4Gi" \
                            --config "videoIndexer.webapi.resources.requests.mem=4Gi"\
                            --config "videoIndexer.webapi.resources.limits.mem=8Gi"\
                            --config "videoIndexer.webapi.resources.limits.cpu=1"\
                            --config "storage.storageClass=azurefile-csi" 

```

### Step 4 - Verify Deployment

```shell
kubectl get pods -n video-indexer
```

## Updating the extension

In case updates are required to the extension, the following command can be used to update the extension with either another version or with different configuration parameters

```shell
           az k8s-extension update --name videoindexer \
                            --cluster-name ${connectedClusterName} \
                            --resource-group ${connectedClusterRg} \
                            --cluster-type connectedClusters \
                            --release-train ${releaseTrain}  \
                            --version ${version} \
                            --config "speech.resource.requests.cpu=500m"

                            
```

> **NOTE:** You must specify the cluster name and resurce group name in order to update the extension.
