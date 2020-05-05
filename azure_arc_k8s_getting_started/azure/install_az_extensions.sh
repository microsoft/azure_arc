#!/bin/bash

curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output connectedk8s-0.1.3-py2.py3-none-any.whl
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output k8sconfiguration-0.1.6-py2.py3-none-any.whl

az extension add --source connectedk8s-0.1.3-py2.py3-none-any.whl --yes
az extension add --source k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes
