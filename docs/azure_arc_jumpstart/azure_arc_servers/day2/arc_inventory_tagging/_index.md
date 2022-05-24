---
type: docs
title: "Inventory Tagging"
linkTitle: "Inventory Tagging"
weight: 1
description: >
---

## Azure Arc-enabled servers inventory using Resource Graph Explorer

This scenario will guide you on how to use Azure Arc-enabled servers to provide server inventory management capabilities across hybrid multi-cloud and on-premises environments.

Azure Arc-enabled servers allows you to manage your Windows and Linux machines hosted outside of Azure on your corporate network or other cloud provider, similarly to how you manage native Azure virtual machines. When a hybrid machine is connected to Azure, it becomes a connected machine and is treated as a resource in Azure. Each connected machine has a Resource ID, it is managed as part of a resource group inside a subscription, and benefits from standard Azure constructs such as Azure Policy and applying tags. The ability to easily organize and manage server inventory using Azure as a management engine greatly reduces administrative complexity and provides a consistent strategy for hybrid and multi-cloud environments.

In this guide, we will use [Resource Graph Explorer](https://docs.microsoft.com/en-us/azure/governance/resource-graph/overview) to demonstrate querying server inventory across multiple clouds from a single pane of glass in Azure.

> **Note: This guide assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion:**

* **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
* **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
* **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
* **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
* **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
* **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
* **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
* **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
* **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
* **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

## Prerequisites

* As mentioned before, this guide starts at the point where you already deployed and connected VMs or bare-metal servers to Azure Arc.

## Apply resource tags to Azure Arc-enabled servers

In this first step, we will assing Azure resource tags to your Azure Arc-enabled servers. This gives you the ability to easily organize and manage server inventory.

From the Azure Portal, go to **All Services**  and search for **Servers - Azure Arc**.

![Screenshot showing All Services Azure Arc-enabled servers in the portal](./15.png)

Click on any of your Azure Arc-enabled servers:

![Screenshot showing all Azure Arc-enabled servers](./16.png)

Click on **Tags**. Add a new tag with **Name="Scenario"** and **Value="jumpstart_azure_arc_servers_inventory"**. Click **Apply** when ready.

![Screenshot showing how to apply a tag to an Azure Arc-enabled server](./17.png)

Repeat the same process in other Azure Arc-enabled servers. This new Tag will be used later when working with Resource Graph Explorer queries.

## Using Resource Graph Explorer to Review Server Inventory

We will use Resource Graph Explorer to query our hybrid server inventory.

Enter **Resource Graph Explorer** in the top search bar in the Azure portal and select it.

![Screenshot showing Resource Graph Explorer in Azure Portal](./18.png)

![Screenshot showing Resource Graph Explorer main page](./19.png)

Scope Azure Resource Graph Explorer to the Directory, Management Group or Subscription where you have your Azure Arc-enabled servers. In this case, we will work at Directory level. Click **Apply** when finished.

![Screenshot showing Resource Graph Explorer scope](./20.png)

In the query window, run the following query, that will show you all Azure Arc-enabled servers in your subscription. Enter the query and then click **Run Query**:

```kusto
Resources
| where type =~ 'Microsoft.HybridCompute/machines'
```

![Screenshot showing Resource Graph Explorer first query](./21.png)

You should see your Azure Arc-enabled servers in the results pane. Toggle the **Formatted Results** switch for a cleaner table.

![Screenshot showing Resource Graph Explorer query results for Azure Arc-enabled servers](./22.png)

Still on the results pane, go to the right and click on the **See details** link of any of the results:

![Screenshot showing Resource Graph Explorer query results See details link](./26.png)

Here, you can see all the Azure Arc-enabled server metadata that you can query using Resource Graph explorer.

![Screenshot showing Resource Graph Explorer Azure Arc-enabled servers metadata](./27.png)

For example, by using that metadata, you could run the following query to get the number of Azure Arc-enabled servers hosted in Amazon Web Services (AWS) or in Google Cloud Platform (GCP):

```kusto
Resources
| where type =~ 'Microsoft.HybridCompute/machines'
| extend cloudProvider = tostring(properties.detectedProperties.cloudprovider)
| where  cloudProvider in ("AWS", "GCP")
| summarize serversCount = count() by cloudProvider
```

![Screenshot showing Resource Graph Explorer cloud providers query](./28.png)

Moreover, you could render these results using the available **Charts**:

![Screenshot showing Resource Graph Explorer cloud providers query chart](./29.png)

Let's now build a query that uses the Resource Tag we assigned to some of our Azure Arc-enabled servers. Modify the previous query to include a check for resources that have a value for the **Scenario** tag:

```kusto
Resources
| where type =~ 'Microsoft.HybridCompute/machines' and isnotempty(tags['Scenario'])
| extend Scenario = tags['Scenario']
| project name, tags
```

![Screenshot showing Resource Graph Explorer query results for tags](./23.png)

We can also use Resource Graph Explorer to list extensions installed on our Azure Arc-enabled servers.

```kusto
Resources
| where type == 'microsoft.hybridcompute/machines'
| project id, JoinID = toupper(id), ComputerName = tostring(properties.osProfile.computerName), OSName = tostring(properties.osName)
| join kind=leftouter(
    Resources
    | where type == 'microsoft.hybridcompute/machines/extensions'
    | project MachineId = toupper(substring(id, 0, indexof(id, '/extensions'))), ExtensionName = name
) on $left.JoinID == $right.MachineId
| summarize Extensions = make_list(ExtensionName) by id, ComputerName, OSName
| order by tolower(OSName) desc
```

![Screenshot showing Resource Graph Explorer query results for extensions](./24.png)

Azure Arc also provides additional properties on the Azure Arc-enabled server resource that we can query with Resource Graph Explorer. For example, you can get which Azure Arc Agent version is installed in your Azure Arc-enabled servers. Run another query using the following example:

```kusto
Resources
| where type =~ 'Microsoft.HybridCompute/machines'
| extend arcAgentVersion = tostring(properties.['agentVersion']), osName = tostring(properties.['osName']), osVersion = tostring(properties.['osVersion']), osSku = tostring(properties.['osSku']),
lastStatusChange = tostring(properties.['lastStatusChange'])
| project name, arcAgentVersion, osName, osVersion, osSku, lastStatusChange
```

![Screenshot showing Resource Graph Explorer query results for additional properties](./25.png)

## Clean up environment

Complete the following steps to clean up your environment.

* Remove the virtual machines from each environment by following the teardown instructions from each guide.

  * **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
  * **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
  * **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
  * **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
  * **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
  * **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
  * **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
  * **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
  * **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
  * **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**
