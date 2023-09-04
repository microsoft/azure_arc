---
type: docs
title: "Azure Kubernetes Service"
linkTitle: "Azure Kubernetes Service"
weight: 1
description: >-
  If you do not yet have a Kubernetes cluster, the scenarios in this section will guide on creating an AKS cluster with Azure Video Indexer enabled by Arc in an automated fashion using az commands. 
  
  The purpose of Azure Video Indexer enabled by Arc is to perform video and audio analysis on edge devices in a connected fashion, only control plane data is passed to the cloud, while data plane data is stored only on the edge device. 
  To achieve this goal, the video indexer extension that this guide explains how to create needs to be linked to an Azure Video Indexer cloud account. If you don't have such an account, this section will provide instructions on how to create one.
---
Video Indexer APIs
In this section you will learn how to leverage Video Indexer APIs for the following tasks:
•	Get details about the installed extension, including indexing statistics, supported languages and version. 
•	Run through the process of indexing a video, list the videos indexed via the extension, get insights for a specific indexed video, get captions for a specific video and the streaming endpoint URL for a specific video. 
Before you can start to run the APIs, you will first need to locate the Video indexer account Id. In the portal, select ‘account settings’ on the left side pane and copy the account ID. it will be used as a parameter for all the APIs.
 
Also, you will need to generate an access token and use the token to authenticate the call. 
From the Azure portal, go to the Azure video indexer account, under 
“Management API”, set permission type ‘Contributor’, set scope ‘Account’,
click generate. 
  
Alternatively, you can call the generate access token API
Video tutorial - how to generate an access token via the Azure Portal and via postman 
 
Next, access the swagger UI to run the APIs
Browes to internal URL that was configured during the extension installation in the ‘frontend.endpointUri’ property including ‘swagger/index.html’.
ex: https://127.0.0.1/swagger/index.html

Last, enter the generated access token in Swagger UI
 
 


 
