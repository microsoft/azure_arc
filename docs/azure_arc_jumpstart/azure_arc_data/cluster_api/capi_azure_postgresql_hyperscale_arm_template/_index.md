---
type: docs
title: "PostgreSQL Hyperscale ARM Template"
linkTitle: "PostgreSQL Hyperscale ARM Template"
weight: 3
description: >
---

## Deploy Azure Arc-enabled PostgreSQL Hyperscale in directly connected mode on Cluster API Kubernetes cluster with Azure provider using an ARM Template

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using [Azure Arc-enabled data services](https://docs.microsoft.com/azure/azure-arc/data/overview) and [PostgreSQL Hyperscale](https://docs.microsoft.com/azure/azure-arc/data/what-is-azure-arc-enabled-postgres-hyperscale) deployed on [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/introduction.html) Kubernetes cluster and it's [Cluster API Azure provider (CAPZ)](https://cloudblogs.microsoft.com/opensource/2020/12/15/introducing-cluster-api-provider-azure-capz-kubernetes-cluster-management/).

By the end of this guide, you will have a CAPI Kubernetes cluster deployed with an Azure Arc Data Controller, PostgreSQL Hyperscale instance (with a sample database), and a Microsoft Windows Server 2022 (Datacenter) Azure sidecar VM, installed & pre-configured with all the required tools needed to work with Azure Arc-enabled data services.

> **NOTE: Currently, Azure Arc-enabled data services with PostgreSQL Hyperscale is in [public preview](https://docs.microsoft.com/azure/azure-arc/data/release-notes)**.

## Prerequisites

- Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

- [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

- [Generate SSH Key](https://docs.microsoft.com/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

- Create Azure service principal (SP). To deploy this scenario, an Azure service principal assigned with multiple RBAC roles is required:

  - "Contributor" - Required for provisioning Azure resources
  - "Security admin" - Required for installing Cloud Defender Azure-Arc enabled Kubernetes extension and dismiss alerts
  - "Security reader" - Required for being able to view Azure-Arc enabled Kubernetes Cloud Defender extension findings
  - "Monitoring Metrics Publisher" - Required for being Azure Arc-enabled data services billing, monitoring metrics, and logs management

    To create it login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Security admin" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Security reader" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Monitoring Metrics Publisher" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArcDataSvc" --role "Contributor" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "JumpstartArcDataSvc" --role "Security admin" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "JumpstartArcDataSvc" --role "Security reader" --scopes /subscriptions/$subscriptionId
    az ad sp create-for-rbac -n "JumpstartArcDataSvc" --role "Monitoring Metrics Publisher" --scopes /subscriptions/$subscriptionId
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArcDataSvc",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password**.

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

## Architecture (In a nutshell)

From the Cluster API Book docs:

"Cluster API requires an existing Kubernetes cluster accessible via kubectl; during the installation process the Kubernetes cluster will be transformed into a management cluster by installing the Cluster API provider components, so it is recommended to keep it separated from any application workload."

In this guide and as part of the automation flow (described below), a [Rancher K3s](https://rancher.com/docs/k3s/latest/en/) cluster will be deployed which will be used as the management cluster. This cluster will then be used to deploy the workload cluster using the Cluster API Azure provider (CAPZ).

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

- User is editing the ARM template parameters file (1-time edit). These parameters values are being used throughout the deployment.

- Main [_azuredeploy_ ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/azuredeploy.json) will initiate the deployment of the linked ARM templates:

  - [_VNET_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/VNET.json) - Deploys a Virtual Network with a single subnet to be used by the Client virtual machine.
  - [_ubuntuCapi_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/ubuntuCapi.json) - Deploys an Ubuntu Linux VM which will have Rancher K3s installed and transformed into a Cluster API management cluster via the Azure CAPZ provider. As part of it's automation and the [_installCAPI_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/artifacts/installCAPI.sh) shell script, a new Azure Arc-enabled Kubernetes cluster will already be created to be used by the rest of the Azure Arc-enabled data services automation. Azure Arc-enabled data services deployed in directly connected are using this type of resource in order to deploy the data services [cluster extension](https://docs.microsoft.com/azure/azure-arc/kubernetes/conceptual-extensions) as well as for using Azure Arc [Custom location](https://docs.microsoft.com/azure/azure-arc/kubernetes/conceptual-custom-locations).
  - [_clientVm_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/clientVm.json) - Deploys the client Windows VM. This is where all user interactions with the environment are made from.
  - [_mgmtStagingStorage_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/mgmtStagingStorage.json) - Used for staging files in automation scripts.
  - [_logAnalytics_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/logAnalytics.json) - Deploys Azure Log Analytics workspace to support Azure Arc-enabled data services logs uploads.

- User remotes into client Windows VM, which automatically kicks off the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/artifacts/DataServicesLogonScript.ps1) PowerShell script that deploy and configure Azure Arc-enabled data services on the CAPI workload cluster including the data controller.

- In addition to deploying the data controller and PostgreSQL Hyperscale, the sample [_AdventureWorks_](https://docs.microsoft.com/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=ssms) database will restored automatically for you as well.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single template that will initiate the entire automation for this scenario.

- The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [_azuredeploy.parameters.json_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/azuredeploy.parameters.json) file located in your local cloned repository folder.

  - _'sshRSAPublicKey'_ - Your SSH public key
  - _'spnClientId'_ - Your Azure service principal id
  - _'spnClientSecret'_ - Your Azure service principal secret
  - _'spnTenantId'_ - Your Azure tenant id
  - _'windowsAdminUsername'_ - Client Windows VM Administrator name
  - _'windowsAdminPassword'_ - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  - _'myIpAddress'_ - Your local IP address. This is used to allow remote RDP and SSH connections to the client Windows VM and K3s Rancher VM.
  - _'logAnalyticsWorkspaceName'_ - Unique name for the deployment log analytics workspace.
  - _'deploySQLMI'_ - Boolean that sets whether or not to deploy SQL Managed Instance, for this scenario we leave it set to _**false**_.
  - _'SQLMIHA`_ - Boolean that sets whether or not to deploy SQL Managed Instance with high-availability (business continuity) configurations, for this scenario we leave it set to _**false**_.
  - _'deployPostgreSQL'_ - Boolean that sets whether or not to deploy PostgreSQL Hyperscale, for this Azure Arc-enabled PostgreSQL Hyperscale scenario we will set it to _**true**_.
  - _'deployBastion'_ - Choice (true | false) to deploy Azure Bastion or not to connect to the client VM.
  - _'bastionHostName'_ - Azure Bastion host name.

- To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM) and run the below command:

    ```shell
    az group create --name <Name of the Azure resource group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > **NOTE: Make sure that you are using the same Azure resource group name as the one you've just used in the _azuredeploy.parameters.json_ file**

    For example:

    ```shell
    az group create --name Arc-Data-Demo --location "East US"
    az deployment group create \
    --resource-group Arc-Data-Demo \
    --name arcdatademo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

    > **NOTE: The deployment time for this scenario can take ~15-20min**

- Once Azure resources has been provisioned, you will be able to see it in Azure portal. As mentioned, a new Azure Arc-enabled Kubernetes cluster resource will already be available at this point.

    ![Screenshot showing ARM template deployment completed](./01.png)

    ![Screenshot showing the new Azure resource group with all resources](./02.png)

    ![Screenshot showing the new Azure resource group with all resources](./03.png)

## Windows Login & Post Deployment

- Now that the first phase of the automation is completed, it is time to RDP to the client VM. If you have not chosen to deploy Azure Bastion in the ARM template, RDP to the VM using its public IP.

    ![Screenshot showing Client VM public IP](./04.png)

- If you have chosen to deploy Azure Bastion in the ARM template, use it to connect to the VM.

    ![Screenshot showing connecting using Azure Bastion](./05.png)

- At first login, as mentioned in the "Automation Flow" section above, the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/ARM/artifacts/DataServicesLogonScript.ps1) PowerShell logon script will start it's run.

- Let the script to run its course and **do not close** the PowerShell session, this will be done for you once completed. Once the script will finish it's run, the logon script PowerShell session will be closed, the Windows wallpaper will change and both the Azure Arc Data Controller and PostgreSQL will be deployed on the cluster and be ready to use.

  ![Screenshot showing the PowerShell logon script run](./06.png)

  ![Screenshot showing the PowerShell logon script run](./07.png)

  ![Screenshot showing the PowerShell logon script run](./08.png)

  ![Screenshot showing the PowerShell logon script run](./09.png)

  ![Screenshot showing the PowerShell logon script run](./10.png)

  ![Screenshot showing the PowerShell logon script run](./11.png)

  ![Screenshot showing the PowerShell logon script run](./12.png)

  ![Screenshot showing the PowerShell logon script run](./13.png)

  ![Screenshot showing the PowerShell logon script run](./14.png)

  ![Screenshot showing the PowerShell logon script run](./15.png)

  ![Screenshot showing the PowerShell logon script run](./16.png)

  ![Screenshot showing the PowerShell logon script run](./17.png)

  ![Screenshot showing the PowerShell logon script run](./18.png)

  ![Screenshot showing the PowerShell logon script run](./19.png)

  ![Screenshot showing the PowerShell logon script run](./20.png)

  ![Screenshot showing the PowerShell logon script run](./21.png)

  ![Screenshot showing the PowerShell logon script run](./22.png)

  ![Screenshot showing the PowerShell logon script run](./23.png)

  ![Screenshot showing the post-run desktop](./24.png)

- Since this scenario is deploying the Azure Arc Data Controller, you will also notice additional newly deployed Azure resources in the resources group. The important ones to notice are:

  - Custom location - provides a way for tenant administrators to use their Azure Arc-enabled Kubernetes clusters as target locations for deploying Azure services instances.

  - Azure Arc Data Controller - The data controller that is now deployed on the Kubernetes cluster.

  - Azure Arc-enabled PostgreSQL Hyperscale - The PostgreSQL Hyperscale instance that is now deployed on the Kubernetes cluster.

  ![Screenshot showing additional Azure resources in the resource group](./25.png)

- As part of the automation, Azure Data Studio is installed along with the _Azure Data CLI_, _Azure CLI_, _Azure Arc_ and the _PostgreSQL_ extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see the installed extensions.

    ![Screenshot showing Azure Data Studio shortcut](./26.png)

    ![Screenshot showing Azure Data Studio extensions](./27.png)

- Additionally, the PostgreSQL connection will be configured automatically for you. As mentioned, the sample _AdventureWorks_ database was restored as part of the automation.

  ![Screenshot showing Azure Data Studio PostgresSQL Hyperscale connection](./28.png)

## Cluster extensions

In this scenario, four Azure Arc-enabled Kubernetes cluster extensions were installed:

- _microsoft.policyinsights_ - The Azure Policy cluster extension. To learn more about it, read the [Understand Azure Policy for Kubernetes clusters](https://docs.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes) Azure doc.

- _microsoft.azuredefender.kubernetes_ - The Microsoft Defender for Cloud cluster extension. To learn more about it, you can check our Jumpstart ["Integrate Azure Defender with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions"](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_defender_extension/#create-azure-defender-extensions-instance) scenario.

- _azuremonitor-containers_ - The Azure Monitor Container Insights cluster extension. To learn more about it, you can check our Jumpstart ["Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_monitor_extension/) scenario.

- _arc-data-services_ - The Azure Arc-enabled data services cluster extension that was used throughout this scenario in order to deploy the data services infrastructure.

- In order to view these cluster extensions, click on the Azure Arc-enabled Kubernetes resource Extensions settings.

  ![Screenshot showing the Azure Arc-enabled Kubernetes cluster extensions settings](./29.png)

  ![Screenshot showing the Azure Arc-enabled Kubernetes installed extensions](./30.png)

### Exploring logs from the Client virtual machine

Occasionally, you may need to review log output from scripts that run on the _Arc-Data-Client_ or _Arc-Data-CAPI-MGMT_ virtual machines in case of deployment failures. To make troubleshooting easier, the scenario deployment scripts collect all relevant logs in the _C:\Temp_ folder on _Arc-Data-Client_. A short description of the logs and their purpose can be seen in the list below:

| Logfile | Description |
| ------- | ----------- |
| _C:\Temp\Bootstrap.log_ | Output from the initial bootstrapping script that runs on _Arc-Data-Client_. |
| _C:\Temp\DataServicesLogonScript.log_ | Output of _DataServicesLogonScript.ps1_ which configures Azure Arc-enabled data services baseline capability. |
| _C:\Temp\DeployPostgreSQL.log_ | Output of _deployPostgreSQL.ps1_ which deploys and configures PostgreSQL Hyperscale with Azure Arc. |
| _C:\Temp\installCAPI.log_ | Output from the custom script extension which runs on _Arc-Data-CAPI-MGMT_ and configures the Cluster API for Azure cluster and onboards it as an Azure Arc-enabled Kubernetes cluster. If you encounter ARM deployment issues with _ubuntuCapi.json_ then review this log. |

![Screenshot showing the Temp folder with deployment logs](./31.png)

## Cleanup

- If you want to delete the entire environment, simply delete the deployment resource group from the Azure portal.

    ![Delete Azure resource group](./32.png)
