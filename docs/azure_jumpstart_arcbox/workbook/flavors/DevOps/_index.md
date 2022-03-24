---
type: docs
weight: 99
toc_hide: true
---

# Jumpstart ArcBox for DevOps - Azure Monitor Workbook

ArcBox for DevOps is a special "flavor" of ArcBox that is intended for users who want to experience Azure Arc-enabled Kubernetes capabilities in a sandbox environment. This document provides specific guidance on the included ArcBox [Azure Monitor Workbook](https://docs.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-overview). Please refer to the main [ArcBox documentation](https://azurearcjumpstart.io/azure_jumpstart_arcbox/) for information on deploying and using ArcBox.

As part of ArcBox for DevOps, an Azure Monitor workbook is deployed to provide a single pane of glass for monitoring and reporting on ArcBox resources. Using Azure's management and operations tools in hybrid, multi-cloud and edge deployments provides the consistency needed to manage each environment through a common set of governance and operations management practices. The Azure Monitor workbook acts as a flexible canvas for data analysis and visualization in the Azure portal, gathering information from several data sources from across ArcBox and combining them into an integrated interactive experience.

   > **NOTE: Due to the number of Azure resources included in a single ArcBox deployment and the data ingestion and analysis required, it is expected that metrics and telemetry for the workbook can take several hours to be fully available.**

## Access the ArcBox for DevOps workbook

The Jumpstart ArcBox workbook is automatically deployed for you as part of ArcBox's advanced automation. To access the Jumpstart ArcBox workbook use the Azure portal to follow the next steps.

- From the ArcBox resource group, select the Azure Workbook, then click "Open Workbook"

![Workbook Gallery](./azure_workbook.png)

![Workbook Gallery](./open_workbook.png)

- The Jumpstart ArcBox Workbook will be displayed.

![Arcbox workbook overview](./workbook_overview.png)

## ArcBox Workbook for DevOps capabilities

The ArcBox Workbook is a single report that combines data from different sources and services, providing a unified view across resources, enabling richer data and insights for unified operations.

The Workbook is organized into several tabs that provide easier navigation and separation of concerns.

![Tab Menu](./tab_menu.png)

### Inventory

By using Azure Arc, your on-premises and multi-cloud resources become visible through Azure Resource Manager. Therefore, you can use tools such as Azure Resource Graph as a way to explore your inventory at scale. Your Azure Resource Graph queries can now include Azure Arc-enabled resources with filtering, using tags, or tracking changes.

The "Inventory" tab in the ArcBox Workbook has three sections:

- _parameters_ - use the drop-down menu to select your subscription and resource group, you also get the option to filter the report by resource type.

   ![Inventory Parameters](./inventory_parameters.png)

- _Resource Count by Type_ - this visualization shows the number of resources by type within a resource group, these grouping will be automatically refreshed if the parameters section is changed.

   ![Inventory Resource by type](./inventory_count_by_type.png)

- _Resource List_ - this table shows a list of resources in the resource group provided in the parameters section. This is an interactive list, therefore you can click on any resource or tag for additional information.

   ![Inventory Resource List](./inventory_resource_list.png)

### Monitoring

Enabling a resource in Azure Arc gives you the ability to perform configuration management and monitoring tasks on those services as if they were first-class citizens in Azure. You are able to monitor your Kubernetes clusters at the scope of the resource with container Insights. In ArcBox for DevOps the Azure Arc-enabled Kubernetes clusters have been onboarded onto Azure Monitor.

The "Monitoring" tab of the Jumpstart Workbook shows metrics and alerts for ArcBox resources organized in three sections:

- _Alert Summary_ - Shows an overview of alerts organized by severity and status. You can use the drop-down menus to apply filters to the report. The following filters are available:
  - Subscription: select one or multiple subscriptions in your environment to show available alerts.
  - Resource Group: select one or more resource groups in your environment to show available alerts.
  - Resource Type: select one or multiple resource types to show its alerts.
  - Resources: select individual resources by name to visualize their alerts.
  - Time Range: provide a time range in which the alert has been created.
  - State: choose the alert type between New, Acknowledged, or Closed.

   ![Monitoring Alert Summary](./monitoring_alert_summary.png)

- _Azure Arc-enabled Kubernetes_ - Shows information and metrics from ArcBox's Azure Arc-enabled Kubernetes clusters. Use the parameters section to filter data:
  - Time Range: provide a time range for the metrics and logs to be displayed.
  - Subscription: select your subscription where ArcBox is deployed.
  - Log Analytics Workspace: select ArcBox's Log Analytics workspace.
  - Azure Arcenabled K8s cluster: choose one of ArcBox's Azure Arc-enabled Kubernetes clusters.
  - Workload Type: choose one or multiple kubernetes deployment types.
  - Namespace: choose one or multiple namespaces in the Kubernetes cluster.
  - Workload Name: choose one of the deployments in your cluster.
  - Pod Status: filter by Pod status like Pending/Running/Failed etc.
  - Pod Name: filter by pod name in the namespace and workload name selected.

  With this report you will get several visualizations:

  - _Pod and Container restart trend graphs._

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_1.png)

  - _Pod count and status chart._

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_2.png)

  - _A list of the container status for pods._

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_3.png)

  - _The Kubernetes cluster's nodes CPU and memory working set percentage._

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_4.png)

### Security

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
