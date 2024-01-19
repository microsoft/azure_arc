---
type: docs
weight: 99
toc_hide: true
---

# Jumpstart ArcBox for IT Pros - Azure Monitor Workbook

ArcBox for IT Pros is a special "flavor" of ArcBox that is intended for users who want to experience Azure Arc-enabled servers capabilities in a sandbox environment. This document provides specific guidance on the included ArcBox [Azure Monitor Workbook](https://docs.microsoft.com/azure/azure-monitor/visualize/workbooks-overview). Please refer to the main [ArcBox documentation](https://azurearcjumpstart.io/azure_jumpstart_arcbox/) for information on deploying and using ArcBox.

As part of ArcBox for IT Pros, an Azure Monitor workbook is deployed to provide a single pane of glass for monitoring and reporting on ArcBox resources. Using Azure's management and operations tools in hybrid, multi-cloud and edge deployments provides the consistency needed to manage each environment through a common set of governance and operations management practices. The Azure Monitor workbook acts as a flexible canvas for data analysis and visualization in the Azure portal, gathering information from several data sources from across ArcBox and combining them into an integrated interactive experience.

   > **Note: Due to the number of Azure resources included in a single ArcBox deployment and the data ingestion and analysis required, it is expected that metrics and telemetry for the workbook can take several hours to be fully available.**

## Access the ArcBox for IT Pros workbook

The Jumpstart ArcBox workbook is automatically deployed for you as part of ArcBox's advanced automation. To access the Jumpstart ArcBox workbook use the Azure portal to follow the next steps.

- From the ArcBox resource group, select the Azure Workbook, then click "Open Workbook"

   ![Workbook Gallery](./azure_workbook.png)

   ![Workbook Gallery](./open_workbook.png)

- The Jumpstart ArcBox for IT Pros Workbook will be displayed.

   ![Arcbox for IT Pros workbook overview](./workbook_overview.png)

## ArcBox for IT Pros Workbook capabilities

The ArcBox for IT Pros Workbook is a single report that combines data from different sources and services, providing a unified view across resources, enabling richer data and insights for unified operations.

The Workbook is organized into several tabs that provide easier navigation and separation of concerns.

![Tab Menu](./tab_menu.png)

### Inventory

By using Azure Arc, your on-premises and multi-cloud resources become visible through Azure Resource Manager. Therefore, you can use tools such as Azure Resource Graph as a way to explore your inventory at scale. Your Azure Resource Graph queries can now include Azure Arc-enabled resources with filtering, using tags, or tracking changes.

The "Inventory" tab in the ArcBox for IT Pros Workbook has three sections:

- _parameters_ - use the drop-down menu to select your subscription and resource group, you also get the option to filter the report by resource type.

   ![Inventory Parameters](./inventory_parameters.png)

- *Resource Count by Type* - this visualization shows the number of resources by type within a resource group, these grouping will be automatically refreshed if the parameters section is changed.

   ![Inventory Resource by type](./inventory_count_by_type.png)

- _Resource List_ - this table shows a list of resources in the resource group provided in the parameters section. This is an interactive list, therefore you can click on any resource or tag for additional information.

   ![Inventory Resource List](./inventory_resource_list.png)

### Monitoring

Enabling a resource in Azure Arc gives you the ability to perform configuration management and monitoring tasks on those services as if they were first-class citizens in Azure. You are able to monitor your connected machine guest operating system performance at the scope of the resource with VM insights. In ArcBox for IT Pros the Azure Arc-enabled servers have been onboarded onto Azure Monitor.

The "Monitoring" tab of the Jumpstart Workbook shows metrics and alerts for ArcBox for IT Pros resources organized in three sections:

- _Alert Summary_ - Shows an overview of alerts organized by severity and status. You can use the drop-down menus to apply filters to the report. The following filters are available:
  - Subscription: select one or multiple subscriptions in your environment to show available alerts.
  - Resource Group: select one or more resource groups in your environment to show available alerts.
  - Resource Type: select one or multiple resource types to show its alerts.
  - Resources: select individual resources by name to visualize their alerts.
  - Time Range: provide a time range in which the alert has been created.
  - State: choose the alert type between New, Acknowledged, or Closed.

   ![Monitoring Alert Summary](./monitoring_alert_summary.png)

- _Azure Arc-enabled servers_ - Shows metrics for CPU and memory usage on the Azure Arc-enabled servers. Use the parameters section to select the Azure Arc-enabled server as well as a time range to visualize the data.

   ![Monitoring Azure Arc-enabled server Metrics](./monitoring_arc_servers.png)

### Microsoft Defender for Cloud

Microsoft Defender for Cloud can monitor the security posture of your hybrid and multi-cloud deployments that have been onboarded onto Azure Arc. Once those deployments are registered in Azure, you can take care of the security baseline and audit, apply, or automate requirements from recommended security controls as well as identify and provide mitigation guidance for security-related business risks.

The "Security" tab of the Jumpstart Workbook shows insights from Microsoft Defender for Cloud assessments. To be able to use this report, you will need to configure "continuous export" capability to export Microsoft Defender for Cloud's data to ArcBox's Log Analytics workspace:

- From Microsoft Defender for Cloud's sidebar, select Environment Settings.

   ![Microsoft Defender for Cloud Configuration](./security_center_config_1.png)

- Select the specific subscription for which you want to configure the data export.

   ![Microsoft Defender for Cloud Configuration](./security_center_config_2.png)

- From the sidebar of the settings page for that subscription, select Continuous Export, set the export target to the Log Analytics workspace, and set the data types to Security recommendations and Secure Score (Preview) and leave the export frequency at the default values.

   ![Microsoft Defender for Cloud Configuration](./security_center_config_3.png)

- Make sure to select ArcBox's subscription, resource group, and Log Analytics workspace as the export target. Select Save.

   ![Microsoft Defender for Cloud Configuration](./security_center_config_4.png)

Once configured, the report will provide an overview of the secure score, you can filter information by using the parameters section:

- _Workspace_ -  Select one or multiple Log Analytics workspaces.

- _Time Range_ -  Filter the data of the report to one of the predefined time ranges.

   ![Security parameters](./security_parameters.png)

  With this report you will get several visualizations:

  - _Current score trends per subscription_

     ![Security workbook trends](./security_trends.png)

  - _Aggregated score for selected subscriptions over time_

     ![Security workbook aggregated score](./security_score.png)

  - _Top recommendations with the recent increase in unhealthy resources_
  
     ![Security tab top recommendations](./security_recommendations.png)

  - _Security controls scores over time (weekly)_

     ![Security controls scores overtime](./security_controls.png)

  - _Resources changed over time_ - To view changes over time on a specific recommendation, please select any from the list above.

     ![Resources changed overtime](./security_changes.png)

     ![Resources changed overtime selected resources](./security_changes_resource.png)

This part of the workbook also includes a section dedicated to agent monitoring. For Azure Defender to be able to monitor an Azure Arc-enabled-servers certain configurations have to be in place and the workbook will help visualize machines that may not be properly reporting to the Log Analytics workspace.

In the parameters section select the Log Analytics workspace used by ArcBox.

   ![Agent Management](./agentmgmt_parameters.png)

From within the Agent Monitoring section you will get several tabs:

- _Overview_ - with three visualizations:

  - _Azure Monitor Agent installation status_ shows the Azure Monitor Agent installation status as reported by Microsoft Defender for Cloud.

     ![Azure Monitor Agent installation status](./agentmgmt_overviewstatus.png)

  - _Azure Monitor Agent reporting status_ shows the current Azure Monitor Agent reporting status of the Azure Arc-enabled servers. Machines that are sending current heartbeat information within the last 15 minutes are considered as currently reporting.

     ![Azure Monitor Agent reporting status](./agentmgmt_overviewsreport.png)

  - _Azure Defender coverage_ shows the status of Azure Defender for Servers across all servers that are protected by Microsoft Defender for Cloud.

     ![Azure Defender coverage](./agentmgmt_overviewscoverage.png)

- _Machines not reporting to Log Analytics workspace_ - this has four lists of machines that are not sending heartbeats to the Log Analytics workspace in different periods of time: 15 minutes, 24 hours, 48 hours and 7 days. Please not that there are no machines listed on the image as all of them are properly sending heartbeats to the workspace.

   ![Machines not reporting](./agentmgmt_machinesnotreport.png)

- _Security status_ - has a full report of Azure VMs and Azure Arc-enabled-servers security configurations including its Log Analytics workspace and the agent status.

   ![Security Status](./agentmgmt_securitystatus.png)
