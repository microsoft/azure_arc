---
type: docs
title: "Azure Video Indexer Arc extension on AKS"
linkTitle: "Azure Video Indexer Arc extension on AKS"
weight: 1
description: >
---

## Deploy a full Azure Video Indexer enabled by Arc envoiroment with Video Indexer extension on AKS

Azure Video Indexer enabled by Arc is aimed at running Video and Audio Analysis on Edge Devices in a connected fashion, only control plane data is passed to the cloud, while data plane data is stored only on the edge device.
The solution is designed to run on Azure Stack Edge Profile, a heavy edge device, and supports three video formats, including MP4 and four additional common formats. During the public preview, the solution supports eigth Azure languages: English (US), Spanish, German, French, Italian, Portuguese, Chinese (Simplified) in all basic audio-related models.

The following Jumpstart scenario will guide you on how to deploy a "Ready to Go" environment so you can start using [|||Azure Video Indexer enabled by Arc|||](https://azure.microsoft.com/products/ai-video-indexer) deployed on [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/azure/aks/intro-kubernetes) cluster.

By the end of this scenario, you will have an AKS cluster deployed with an App Service plan, a sample Web Application (Web App) and a Microsoft Windows Server 2022 (Datacenter) Azure VM, installed & pre-configured with all the required tools needed to work with Azure Arc-enabled app services.

> **NOTE: Currently, Azure Video Indexer enabled by Arc is in preview.**

## Prerequisites

>NOTE: In order to succesfully deploy the VI Extension it is **mandatory** that we approve your Azure subscription id in advance. Therefore you must first sign up using [this form](https://aka.ms/vi-register).

- Azure subscription with permissions to create Azure resources
- Azure Video Indexer Account. The quickest way is using the Azure Portal using this tutorial [Create Video Indexer account](https://learn.microsoft.com/azure/azure-video-indexer/create-account-portal#use-the-azure-portal-to-create-an-azure-video-indexer-account).
- For the manual deployment, you will need a working Azure Arc Kubernetes environmnet you can follow one of the guides [here](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/).
- Option 1: For running the script from a cloud shell environment you can read more [here](https://learn.microsoft.com/azure/cloud-shell/quickstart?tabs=azurecli).
- Option 2: Use [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), The latest version of connected Kubernetes Azure CLI extension, installed by running the following command.

```shell
az extension add --name connectedk8s
```

## Automation deployment

**This step is optional.** If you would like to test Video Indexer Edge Extension on a sample edge devide this deployment script can be used to quickly set up a K8S cluster and all pods to run VI on Edge. This script will deploy the following resources:

- Small 2 node AKS Cluster (costs are ~$0.80/hour)
- Enable ARC Extension on top of the cluster
- Add Video Indexer Arc Extension
- Add Video Indexer and Cognitive Services Speech + Translation containers
- Expose the Video Indexer Swagger API for dataplane operations

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
