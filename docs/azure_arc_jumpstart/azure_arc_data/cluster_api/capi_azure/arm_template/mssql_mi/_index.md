---
type: docs
title: "SQL Managed Instance ARM Template"
linkTitle: "SQL Managed Instance ARM Template"
weight: 2
description: >
---

## Deploy Azure Arc-enabled SQL Managed Instance in directly connected mode on Cluster API Kubernetes cluster with Azure provider using an ARM Template

The following README will guide you on how to deploy a "Ready to Go" environment so you can start using [Azure Arc-enabled data services](https://docs.microsoft.com/en-us/azure/azure-arc/data/overview) and [SQL Managed Instance](https://docs.microsoft.com/en-us/azure/azure-arc/data/managed-instance-overview) deployed on [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/introduction.html) Kubernetes cluster and it's [Cluster API Azure provider (CAPZ)](https://cloudblogs.microsoft.com/opensource/2020/12/15/introducing-cluster-api-provider-azure-capz-kubernetes-cluster-management/).

By the end of this guide, you will have a CAPI Kubernetes cluster deployed with an Azure Arc Data Controller, SQL Managed Instance (with a sample database), and a Microsoft Windows Server 2022 (Datacenter) Azure sidecar VM, installed & pre-configured with all the required tools needed to work with Azure Arc-enabled data services.

> **Note: Currently, Azure Arc-enabled data services with PostgreSQL Hyperscale is in [public preview](https://docs.microsoft.com/en-us/azure/azure-arc/data/release-notes)**.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure service principal (SP). To deploy this scenario, an Azure service principal assigned with multiple RBAC roles is required:

  * "Contributor" - Required for provisioning Azure resources
  * "Security admin" - Required for installing Cloud Defender Azure-Arc enabled Kubernetes extension and dismiss alerts
  * "Security reader" - Required for being able to view Azure-Arc enabled Kubernetes Cloud Defender extension findings
  * "Monitoring Metrics Publisher" - Required for being Azure Arc-enabled data services billing, monitoring metrics, and logs management

    To create it login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor"
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Security admin"
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Security reader"
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Monitoring Metrics Publisher"
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "JumpstartArcBox" --role "Contributor"
    az ad sp create-for-rbac -n "JumpstartArcBox" --role "Security admin"
    az ad sp create-for-rbac -n "JumpstartArcBox" --role "Security reader"
    az ad sp create-for-rbac -n "JumpstartArcBox" --role "Monitoring Metrics Publisher"
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcData",
    "name": "http://AzureArcData",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: It is optional, but highly recommended, to scope the SP to a specific [Azure subscription](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest).**

* Enable subscription for the *Microsoft.AzureArcData* resource provider for Azure Arc-enabled data services. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.AzureArcData
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.AzureArcData -o table
  ```

## Architecture (In a nutshell)

From the Cluster API Book docs:

"Cluster API requires an existing Kubernetes cluster accessible via kubectl; during the installation process the Kubernetes cluster will be transformed into a management cluster by installing the Cluster API provider components, so it is recommended to keep it separated from any application workload."

In this guide and as part of the automation flow (described below), a [Rancher K3s](https://rancher.com/docs/k3s/latest/en/) cluster will be deployed which will be used as the management cluster. This cluster will then be used to deploy the workload cluster using the Cluster API Azure provider (CAPZ).

## Automation Flow

For you to get familiar with the automation and deployment flow, below is an explanation.

* User is editing the ARM template parameters file (1-time edit). These parameters values are being used throughout the deployment.

* Main [_azuredeploy_ ARM template](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/azuredeploy.json) will initiate the deployment of the linked ARM templates:

  * [_ubuntuCapi_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/ubuntuCapi.json) - Deploys an Ubuntu Linux VM which will have Rancher K3s installed and transformed into a Cluster API management cluster via the Azure CAPZ provider.
  * [_clientVm_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/clientVm.json) - Deploys the client Windows VM. This is where all user interactions with the environment are made from.
  * [_mgmtStagingStorage_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/mgmtStagingStorage.json) - Used for staging files in automation scripts.
  * [_logAnalytics_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/logAnalytics.json) - Deploys Azure Log Analytics workspace to support Azure Arc-enabled data services logs uploads.

* User remotes into client Windows VM, which automatically kicks off the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/artifacts/DataServicesLogonScript.ps1) PowerShell script that deploy and configure Azure Arc-enabled data services on the CAPI workload cluster including the data controller.

## Deployment

As mentioned, this deployment will leverage ARM templates. You will deploy a single template that will initiate the entire automation for this scenario.

* The deployment is using the ARM template parameters file. Before initiating the deployment, edit the [_azuredeploy.parameters.json_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/azuredeploy.parameters.json) file located in your local cloned repository folder.

  * *sshRSAPublicKey* - Your SSH public key
  * *spnClientId* - Your Azure service principal id
  * *spnClientSecret* - Your Azure service principal secret
  * *spnTenantId* - Your Azure tenant id
  * *windowsAdminUsername* - Client Windows VM Administrator name
  * *windowsAdminPassword* - Client Windows VM Password. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.
  * *myIpAddress* - Your local IP address. This is used to allow remote RDP and SSH connections to the sidecar Windows VM and K3s Rancher VM.
  * *logAnalyticsWorkspaceName* - Unique name for the deployment log analytics workspace.
  * *deploySQLMI* - Boolean that sets whether or not to deploy SQL Managed Instance, for this data controller and Azure SQL Managed Instance scenario, we will set it to _**true**_.
  * *deployPostgreSQL* - Boolean that sets whether or not to deploy PostgreSQL Hyperscale, for this data controller and Azure SQL Managed Instance scenario, we leave it set to _**false**_.

* To deploy the ARM template, navigate to the local cloned [deployment folder](https://github.com/microsoft/azure_arc/tree/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template) and run the below command:

    ```shell
    az group create --name <Name of the Azure resource group> --location <Azure Region>
    az deployment group create \
    --resource-group <Name of the Azure resource group> \
    --name <The name of this deployment> \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/azuredeploy.json \
    --parameters <The *azuredeploy.parameters.json* parameters file location>
    ```

    > **Note: Make sure that you are using the same Azure resource group name as the one you've just used in the _azuredeploy.parameters.json_ file**

    For example:

    ```shell
    az group create --name Arc-Data-CAPI --location "East US"
    az deployment group create \
    --resource-group Arc-Data-CAPI \
    --name arcdatademo \
    --template-uri https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/azuredeploy.json \
    --parameters azuredeploy.parameters.json
    ```

    > **Note: The deployment time for this scenario can take ~15-20min**

* Once Azure resources has been provisioned, you will be able to see it in Azure portal. At this point, the resource group should have **34 various Azure resources** deployed.

    ![ARM template deployment completed](./01.png)

    ![New Azure resource group with all resources](./02.png)

    ![New Azure resource group with all resources](./03.png)

## Windows Login & Post Deployment

* Now that first phase of the automation is completed, it is time to RDP to the sidecar VM using it's public IP.

    ![Client VM public IP](./04.png)

* At first login, as mentioned in the "Automation Flow" section above, the [_DataServicesLogonScript_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_data_jumpstart/cluster_api/capi_azure/arm_template/artifacts/DataServicesLogonScript.ps1) PowerShell logon script will start it's run.

* Let the script to run its course and **do not close** the PowerShell session, this will be done for you once completed. Once the script will finish it's run, the logon script PowerShell session will be closed, the Windows wallpaper will change and both the Azure Arc Data Controller and the SQL Managed Instance will be deployed on the cluster and be ready to use.

![PowerShell logon script run](./05.png)

![PowerShell logon script run](./06.png)

![PowerShell logon script run](./07.png)

![PowerShell logon script run](./08.png)

![PowerShell logon script run](./09.png)

![PowerShell logon script run](./10.png)

![PowerShell logon script run](./11.png)

![PowerShell logon script run](./12.png)

![PowerShell logon script run](./13.png)

![PowerShell logon script run](./14.png)

![PowerShell logon script run](./15.png)

![PowerShell logon script run](./16.png)

* Since this scenario is deploying the Azure Arc Data Controller and SQL Managed Instance, you will also notice additional newly deployed Azure resources in the resources group (at this point you should have **55 various Azure resources deployed**. The important ones to notice are:

  * Azure Arc-enabled Kubernetes cluster - Azure Arc-enabled data services deployed in directly connected are using this type of resource in order to deploy the data services [cluster extension](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-extensions) as well as for using Azure Arc [Custom locations](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-custom-locations).

  * Custom location - provides a way for tenant administrators to use their Azure Arc-enabled Kubernetes clusters as target locations for deploying Azure services instances.

  * Azure Arc Data Controller - The data controller that is now deployed on the Kubernetes cluster.

  * Azure Arc-enabled SQL Managed Instance - The SQL Managed Instance that is now deployed on the Kubernetes cluster.

![Additional Azure resources in the resource group](./17.png)

* Another tool automatically deployed is Azure Data Studio along with the *Azure Data CLI*, the *Azure Arc* and the *PostgreSQL* extensions. Using the Desktop shortcut created for you, open Azure Data Studio and click the Extensions settings to see both extensions.

  ![Azure Data Studio shortcut](./18.png)

* Additionally, the SQL Managed Instance connection will be configured as well as the sample [_AdventureWorks_](https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=ssms) database will restored automatically for you.

  ![Azure Data Studio connection](./19.png)

  ![Configured SQL Managed Instance connection](./20.png)

## Cluster extensions

In this scenario, three Azure Arc-enabled Kubernetes cluster extensions were deployed:

* _microsoft.azuredefender.kubernetes_ - The Azure Defender cluster extension. To learn more about it, you can check our Jumpstart ["Integrate Azure Defender with Cluster API as an Azure Arc Connected Cluster using Kubernetes extensions"](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/cluster_api/cluster_api_defender_extension/#create-azure-defender-extensions-instance) scenario.

* _azuremonitor-containers_ - The Azure monitor for containers cluster extension. To learn more about it, you can check our Jumpstart ["Integrate Azure Monitor for Containers with GKE as an Azure Arc Connected Cluster using Kubernetes extensions](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/day2/gke/gke_monitor_extension/) scenario.

* _arc-data-services_ - The Azure Arc-enabled data services cluster extension that was used throughout this scenario in order to deploy the data services infrastructure.

* In order to view these cluster extensions, click on the Azure Arc-enabled Kubernetes resource Extensions settings.

  ![Azure Arc-enabled Kubernetes resource](./21.png)

  ![Azure Arc-enabled Kubernetes cluster extensions settings](./22.png)

## Operations

### Azure Arc-enabled SQL Managed Instance Stress Simulation

Included in this scenario, is a dedicated SQL stress simulation tool named _SqlQueryStress_ automatically installed for you on the Client VM. _SqlQueryStress_ will allow you to generate load on the Azure Arc-enabled SQL Managed Instance that can be done used to showcase how the SQL database and services are performing as well to highlight operational practices described in the next section.

* To start with, open the _SqlQueryStress_ desktop shortcut and connect to the SQL Managed Instance **primary** endpoint IP address. This can be found in the _SQLMI Endpoints_ text file desktop shortcut that was also created for you alongside the username and password you used to deploy the environment.

  ![Open SqlQueryStress](./23.png)

  ![SQLMI Endpoints text file](./24.png)

> **Note: Secondary SQL Managed Instance endpoint will be available only when using the [HA deployment model ("Business Critical")](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/day2/cluster_api/capi_azure/capi_mssql_ha/).**

* To connect, use "SQL Server Authentication" and select the deployed sample _AdventureWorks_ database (you can use the "Test" button to check the connection).

  ![SqlQueryStress connected](./25.png)

* To generate some load, we will be running a simple stored procedure. Copy the below procedure and change the number of iterations you want it to run as well as the number of threads to generate even more load on the database. In addition, change the delay between queries to 1ms for allowing the stored procedure to run for a while.

    ```sql
    exec [dbo].[uspGetEmployeeManagers] @BusinessEntityID = 8
    ```

* As you can see from the example below, the configuration settings are 100,000 iterations, five threads per iteration, and a 1ms delay between queries. These configurations should allow you to have the stress test running for a while.

  ![SqlQueryStress settings](./26.png)

  ![SqlQueryStress running](./27.png)

### Azure Arc-enabled SQL Managed Instance monitoring using Grafana

When deploying Azure Arc-enabled data services, a [Grafana](https://grafana.com/) instance is also automatically deployed on the same Kubernetes cluster and include built-in dashboards for both Kubernetes infrastructure as well SQL Managed Instance monitoring (PostgreSQL dashboards are included as well but we will not be covering these in this section).

* Now that you have the _SqlQueryStress_ stored procedure running and generating load, we can look how this is shown in the the built-in Grafana dashboard. As part of the automation, a new URL desktop shortcut simply named "Grafana" was created.

  ![Grafana desktop shortcut](./28.png)

* [Optional] The IP address for this instance represents the Kubernetes _LoadBalancer_ external IP that was provision as part of Azure Arc-enabled data services. Use the _```kubectl get svc -n arc```_ command to view the _metricsui_ external service IP address.

  ![metricsui Kubernetes service](./29.png)

* To log in, use the same username and password that is in the _SQLMI Endpoints_ text file desktop shortcut.

  ![Grafana username and password](./30.png)

* Navigate to the built-in "SQL Managed Instance Metrics" dashboard.

  ![Grafana dashboards](./31.png)

  ![Grafana "SQL Managed Instance Metrics" dashboard](./32.png)

* Change the dashboard time range to "Last 5 minutes" and re-run the stress test using _SqlQueryStress_ (in case it was already finished).

  ![Last 5 minutes time range](./33.png)

* You can now see how the SQL graphs are starting to show increased activity and load on the database instance.

  ![Increased load activity](./34.png)

  ![Increased load activity](./35.png)

## Cleanup

* If you want to delete the entire environment, simply delete the deployment resource group from the Azure portal.

    ![Delete Azure resource group](./36.png)

<!-- ## Known Issues -->
