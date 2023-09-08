# Jumpstart Agora - Contoso Supermarket deployment guide

## Overview

Jumpstart Agora provides a simple deployment process using Azure CLI and PowerShell that minimizes user interaction. This automation automatically configures the Contoso Supermarket scenario environment, including the infrastructure, the Contoso-Supermarket applications, CI/CD artifacts, and observability components in a physical machine that meets the requirements.

## Requirements

- Hardware Requirements:
  - CPU: Core i3 or better
  - RAM: 16GB Minimum
  - Storage: 200GB
  - OS: Windows 10 21H2, Windows 11, Windows IOT, Windows Server
  
### Prepare environment

Plesae follow the next steps to prepare your environment for succesfull deployment:

1. Enable Hyper-V in your host
2. Install Azure CLI
3. Install Git Client
4. Azure Account 

    The script requires a Service Principal to authenticate and create resources in Azure.

    Create service principal using [Azure Cloud Shell](https://shell.azure.com/) or Bash shell with Azure CLI:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartAgoraSPN" --role "Owner" --scopes /subscriptions/$subscriptionId
    ```

    Output should look similar to this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartAgora",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```


## Deployment

1. Open the physical_agora_params.psd1 and update the following fields:

    Change this values on the psd1 file:

     ```psd1
        GitHub                 = @{
            githubAccount      = ""
            githubBranch       = ""
            gitHubUser         = ""
            githubPat          = ""
        }
        # Required URLs

        AzureDeployment             =@{
            deploymentName     = ""
            azureLocation      = "westus2"
            appId              = ""
            spnClientSecret    = ""
            spnTenantId        = ""
            spnClientID        = ""
        }  spnClientID        = ""
    ```

2. Open a Powershell Windows (with Admin rights) and execute the physical_deployment.ps1 file. Note: the physical_agora_params.psd1 and the physical_deployment.ps1 file must be in the same directory.

 ```shell
    ./physical_deployment.ps1
```

After the succesfull deployment, you should see the local IP Addresses of the POS and the Store Manager App.

## Troubleshooting