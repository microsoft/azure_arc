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
About Azure Video Indexer enabled by Arc 
We are excited to announce the private preview release of the Video Indexer extension for Azure Arc and want to thank you for participating in this effort. 
The Video Indexer Edge private preview for basic audio analysis as an arc enabled service begins on June 20th, 2023. 
This release is the first step toward hybrid video indexing solution that will enable customers to index their video content anywhere it resides, from cloud, edge to multi-cloud.  
The solution is designed to run on a heavy edge device and supports a minimum set of video formats and a single preset – basic audio analysis, that includes AI modules for transcribing and translating video\audio content. 
Preview participants will be sent instructions. We appreciate your participation as the goal of the private preview is to collect valuable feedback before moving to public preview.

Known limitations 
Known limitations of the product during the private preview:
1)	Since we operate on a connected scenario, we require customers to always maintain connection to Azure Cloud. To avoid an incidental, disconnect from disrupting operation, there is a window we will continue to operate during incidental connectivity disruption, but this window is not defined yet.
2)	Only one extension can be added per Video indexer account.
3)	Only one video can be indexed at a time, if a second indexing is attempted while the previous one did not complete, the indexing will fail. 
4)	The customer is required to delete the Video indexer Arc extension when the private preview is completed. This can be easily done by deleting the extension resource, and we also recommend deleting other related resources if not other used. 
5)	Video file supported size limit is 2GB, though there is no active validation currently in place, indexing files larger than 2GB might fail. 
 
Before we start
Please get 5 to 10 video files ready to be indexed:
Video length: up to 30 minutes. 
Video size: up to 2GB.
Video formats: MP4, MP3, WAV, FLAC. 
Video codecs: AAC, H264, HEVC, WAV/PCM, VORBIS, Mpeg-layer 2+3, WMA, VC-1, FLAC.
Video language: English, German. 
Installing the extension follow this guide. 

Scenario

This private preview document is a step-by-step guide on how to index video files using Video indexer Arc extension, review the transcription of the video, translate the video to one or more languages, and play the video with captions. 
It will first cover the steps to do so from the web portal and then using the APIs. 

Step-by-step guide 
Video indexer web portal
1)	Access Video indexer, you can either browse external URL web portal, or the internal URL that was configured during the extension installation in the ‘frontend.endpointUri’ property. 
2)	Locate the new extension on the left pane. 
 
3)	Upload a video and start the indexing process:
a.	Select Upload.
 
b.	Select the file source. You can upload only one file at a time, if you select more than one file, the first file will be selected. 
To upload from your file system, select Browse files and choose the files you want to upload, or drag and drop a file to the designated area. 
 
c.	Set the video name, source language and if this is the first time you upload a media file, you need to check the consent checkbox to agree to the terms and conditions.
 
d.	Select ‘Upload + index’

e.	Review the summary page that shows the indexing settings and the upload progress.
 


 
4)	After the indexing is done, you can view the insights by selecting the video. 
Go to the video page by clicking on the indexed video:
a.	First, click on play video, the video will be streamed from the local location set at the extension installation. 

 
b.	Check the right side on the page, you will notice the video transcription located there including the time marks. 
check that while the movie is playing, the correct transcript line is highlighted.
 

c.	To translate the text to one of the supported languages: English (US), Spanish, German.
Click on the dropdown on the top right of the page, select German. 
now the transcript shown on the right of the page will display the translated transcript in the selected language. 
  

d.	Last step, to turn on the captions, click on the text bubble icon on the bottom right side of the player, select one of the supported languages.
cuptions should start to show while the movie is playing.  
 


