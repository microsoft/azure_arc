# Jumpstart ArcBox - Azure Monitor Workbook

[ArcBox](https://azurearcjumpstart.io/azure_jumpstart_arcbox/) is a solution that provides an easy to deploy sandbox for all things Azure Arc. This document provides specific guidance on the included ArcBox [Azure Monitor Workbook](https://docs.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-overview). Please refer to the main [ArcBox documentation](https://azurearcjumpstart.io/azure_jumpstart_arcbox/) for information on deploying and using ArcBox.

As part of ArcBox, an Azure Monitor workbook is deployed to provide a single pane of glass for monitoring and reporting on ArcBox resources. Using Azure's management and operations tools in hybrid, multi-cloud and edge deployments provides the consistency needed to manage each environment through a common set of governance and operations management practices. The Azure Monitor workbook acts as a flexible canvas for data analysis and visualization in the Azure portal, gathering information from several data sources from across ArcBox and combining them into an integrated interactive experience.

    > **Note: you will have to allow a few hours for the workbook to be able to show data for metrics, logs and assessments.**

## Access the ArcBox workbook

The Jumpstart ArcBox workbook is automatically deployed for you as part of ArcBox's advanced automation. To access the Jumpstart ArcBox workbook use the Azure Portal to follow the next steps.

* Navigate to your ArcBox resource group and search for your Log Analytics workspace, you can do so by using the filter "Type" and searching for "Log Analytics workspace".

![Search Log Analytics workspace](./search_workspace.png)

* After you apply the filter in the ArcBox resource group you will get the Log Analytics workspace resource.

![Log Analytics workspace in resource group](./workspace_in_rg.png)

* Access the Log Analytics workspace by clicking on its name and under "General" select "Workbooks".

![General workbooks](./general_workbooks.png)

* In the Workbooks Gallery select the "ArcBox Workbook".

![Workbook Gallery](./workbooks_access.png)

* The Jumpstart ArcBox Workbook will be displayed.

![Arcbox workbook overview](./workbook_overview.png)

## ArcBox Workbook capabilities

The ArcBox Workbook is a single report that combines data from different sources and services, providing a unified view across resources, enabling richer data and insights for unified operations.

The Workbook is organized into several tabs that provide easier navigation and separation of concerns.

![Tab Menu](./tab_menu.png)

### Inventory

By using Azure Arc, your on-premises and multi-cloud resources become visible through Azure Resource Manager. Therefore, you can use tools such as Azure Resource Graph as a way to explore your inventory at scale. Your Azure Resource Graph queries can now include Azure Arc-enabled resources with filtering, using tags, or tracking changes.

The "Inventory" tab in the ArcBox Workbook has three sections:

* _parameters_ - use the drop-down menu to select your subscription and resource group, you also get the option to filter the report by resource type.

   ![Inventory Parameters](./inventory_parameters.png)

* *Resource Count by Type* - this visualization shows the number of resources by type within a resource group, these grouping will be automatically refreshed if the parameters section is changed.

   ![Inventory Resource by type](./inventory_count_by_type.png)

* *Resource List* - this table shows a list of resources in the resource group provided in the parameters section. This is an interactive list, therefore you can click on any resource or tag for additional information.

   ![Inventory Resource List](./inventory_resource_list.png)

### Monitoring

By enabling a resource in Azure Arc it gives you the ability to perform configuration management and monitoring tasks on those services as if they were first-class citizens in Azure. You are able to monitor your connected machine guest operating system performance and your Kubernetes clusters at the scope of the resource with VM and container Insights. In ArcBox the Azure Arc-enabled servers and Azure Arc-enabled Kubernetes clusters have been onboarded onto Azure Monitor.

The "Monitoring" tab of the Jumpstart Workbook shows metrics and alerts for ArcBox resources organized in three sections:

* *Alert Summary* - Shows an overview of alerts organized by severity and status. You can use the drop down menus to apply filters to the report. The following filters are available:
  * Subscription: select one or multiple subscriptions in your environment to show available alerts.
  * Resource Group: select one or more resource groups in your environment to show available alerts.
  * Resource Type: select one or multiple resources types to show its alerts.
  * Resources: select individual resources by name to visualize its alerts.
  * Time Range: provide a time range in which the alert has been created.
  * State: choose the alert type between New, Acknowledged or Closed.

   ![Monitoring Alert Summary](./monitoring_alert_summary.png)

* *Azure Arc-enabled Servers* - Shows metrics for CPU and memory usage on the Azure Arc-enabled servers. Use the parameters section to select the select the Azure Arc-enabled server as well as a time range to visualize the data.

   ![Monitoring Azure Arc enabled Server Metrics](./monitoring_arc_servers.png)

* *Azure Arc-enabled Kubernetes* - Shows information and metrics from ArcBox's Azure Arc-enabled Kubernetes clusters. Use the parameters section to filter data:
  * Time Range: provide a time range for the metrics and logs to be displayed.
  * Subscription: select your subscription where ArcBox is deployed.
  * Log Analytics Workspace: select ArcBox's Log Analytics workspace.
  * Azure Arcenabled K8s cluster: choose one of ArcBox's Azure Arc-enabled Kubernetes clusters.
  * Workload Type: choose one or multiple kubernetes deployment types.
  * Namespace: choose one or multiple namespaces in the Kubernetes cluster.
  * Workload Name: choose one of the deployments in your cluster.
  * Pod Status: filter by Pod status like Pending/Running/Failed etc.
  * Pod Name: filter by pod name in the namespace and workloadname selected.

  With this report you will get several visualizations:

  * *Pod and Container restart trend graphs.*

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_1.png)

  * *Pod count and status chart.*

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_2.png)

  * *A list of the container status for pods.*

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_3.png)

  * *The Kubernetes cluster's nodes CPU and memory working set percentage.*

     ![Monitoring Azure Arc enabled K8S Metrics](./monitoring_arc_kubernetes_4.png)

### Security

Azure Security Center can monitor the security posture of your hybrid and multicloud deployments that have been onboarded onto Azure Arc. Once those deployments are registered in Azure you can take care of the security baseline and audit, apply, or automate requirements from recommended security controls as well as identify and provide mitigation guidance for security-related business risks.

The "Security" tab of the Jumpstart Workbook shows insights from Azure Security Center assessments. To be able to use this report, you will need to configure continuous export to export Azure Security Center's data to ArcBox's Log Analytics workspace:

* From Security Center's sidebar, select Pricing & settings.

   ![Security Center Configuration](./security_center_config_1.png)

* Select the specific subscription for which you want to configure the data export.

   ![Security Center Configuration](./security_center_config_2.png)

* From the sidebar of the settings page for that subscription, select Continuous Export.

   ![Security Center Configuration](./security_center_config_3.png)

* Set the export target to Log Analytics workspace.

   ![Security Center Configuration](./security_center_config_4.png)

* Select the following data types: Security recommendations and Secure Score (Preview).

   ![Security Center Configuration](./security_center_config_5.png)

* From the export frequency options, select Streaming and Snapshots.

   ![Security Center Configuration](./security_center_config_6.png)

* Make sure to select ArcBox's subscription, resource group and Log Analytics workspace as the export target. Select Save.

   ![Security Center Configuration](./security_center_config_7.png)

Once configured, the report will provide an overview of the secure score, you can filter information by using the parameters section:

* *Workspace* -  select one or multiple Log Analytics workspaces.

* *Time Range* -  filter the data of the report to one of the predefined time ranges.

   ![Security parameters](./security_parameters.png)

  With this report you will get several visualizations:

  * *Current score trends per subscription*

     ![Security workbook trends](./security_trends.png)

  * *Aggregated score for selected subscriptions over time*

     ![Security workbook aggregated score](./security_score.png)

  * *Top recommendations with recent increase in unhealthy resources*
  
     ![Security tab top recommendations](./security_recommendations.png)

  * *Security controls scores over time (weekly)*

     ![Security controls scores overtime](./security_controls.png)

  * *Resources changed over time* - to view changes over time on a specific recommendation, please select any from the list above.

     ![Resources changed overtime](./security_changes.png)

     ![Resources changed overtime selected resources](./security_changes_resource.png)

### Change Tracking

Change Tracking in Azure Automation keeps track of the changes in virtual machines hosted in Azure, on-premises, and other cloud environments to help you pinpoint operational and environmental issues with software managed by the Distribution Package Manager.

In Jumpstart ArcBox all of the Azure Arc-enabled servers are onboarded on Change Tracking and Inventory. The "Change Tracking" tab of the Jumpstart Workbook shows insights from Azure Automation. To use this report you need to provide the ArcBox's subscription and Log Analytics workspace in the parameters section along with a time range.

   ![Change Tracking Parameters](./changetracking_parameters.png)

The tab has two different sections:

* *Software Inventory* - This section provides a distinct count od publishers and applications for the servers selected. You can filter data by computer, publisher or application.

   ![Change Tracking Software Inventory](./changetracking_software.png)

* *Windows Services* - This section shows a table of Windows services with  their state, account and path.

   ![Change Tracking Windows Services](./changetracking_services.png)

### Update Management

Azure Automation provides Update Management to take care of the operating system updates for Windows and Linux  Azure VMs or Azure Arc-enabled servers. The solution assesses the status of available updates and manages the process of installing required updates for your machines reporting to Update Management. In ArcBox all of the Azure Arc-enabled servers are onboarded on Update Management. The "Update Management" tab of the Jumpstart Workbook shows insights from Azure Automation. To use this report you need to provide the ArcBox's subscription, resource group and Log Analytics workspace in the parameters section along with a time range.

   ![Update Management parameters](./update_parameters.png)

The tab has two different sections, one for Windows and one for Linux machines:

* *Windows VM Updates* - This section provides serveral reports:

  * *Types of Windows Updates* - this donut chart shows the number of Windows Updates grouped by type.

   ![Update Windows Updates](./update_windows.png)

  * *Top Windows VMs with Updates* - shows the top Windows machines with updates available and the number of updates per machine.

   ![ Update Windows Top](./uptade_windows_top.png)

  * *Update Summary* - shows a table with the updates available for each of the Windows VM and its severity. By selecting one of the resources names you will get additional information on the available updates.

   ![ Update Windows Summary](./update_windows_summary.png)

* *Linux VM Updates* - This section provides serveral reports:

  * *Types of Linux Updates* - this donut chart shows the number of Windows Updates grouped by type.

   ![Update Linux Updates](./update_linux.png)

  * *Top Linux VMs with Updates* - shows the top Linux machines with updates available and the number of updates per machine.

   ![ Update Linux Top](./uptade_linux_top.png)

  * *Update Summary* - shows a table with the updates available for each of the Linux VM and its severity. By selecting one of the resources names you will get additional information on the available updates.

   ![ Update Linux Summary](./update_linux_summary.png)

### SQL Healthcheck

The Azure Monitor SQL Health Check solution asesses the risk and health of your Windows-based SQL Server instance that is connected to Azure Arc. The solution provides a prioritized list of recommendations specific to your deployed server infrastructure. Each recommendation provides guidance based on best practices and how to implement the suggested changes.

ArcBox has one Windows VM running SQL Server that is onboarded as Azure Arc-enabled SQL Server (as well as Azure Arc-enabled server) where the SQL Assessment has been run. To use the "SQL Healthcheck" tab of the ArcBox workbooks you need to provide the ArcBox's subscription, resource group and Log Analytics workspace as parameters.

   ![SQL Healthcheck parameters](./sql_healthcheck_parameters.png)

The report will display the results of the assessment in four sections:

* *Security and compliance* - this section has three different reports for all security and compliance recommendations. The first one shows the results for all the checks grouped by status: passed, failed or inconclusive. The second report shows a donut chart with the recommendations grouped by priority low, medium or high. Finally, there is a list with all of the security and compliance recommendations.

   ![SQL Healthcheck security and compliance status](./sql_healthcheck_security_status.png)

   ![SQL Healthcheck security and compliance priority](./sql_healthcheck_security_priority.png)

   ![SQL Healthcheck security and compliance status recommendations](./sql_healthcheck_security_recommendations.png)

* *High availability and business continuity* - this section has three different reports for all high availability and business continuity recommendations. The first one shows the results for all the checks grouped by status: passed, failed or inconclusive. The second report shows a donut chart with the recommendations grouped by priority low, medium or high. Finally, there is a list with all of the high availability and business continuity recommendations.

   ![SQL Healthcheck HA status](./sql_healthcheck_ha_status.png)

   ![SQL Healthcheck HA priority](./sql_healthcheck_ha_priority.png)

   ![SQL Healthcheck HA status recommendations](./sql_healthcheck_ha_recommendations.png)

* *Performance and scalability* - this section has three different reports for all performance and scalability recommendations. The first one shows the results for all the checks grouped by status: passed, failed or inconclusive. The second report shows a donut chart with the recommendations grouped by priority low, medium or high. Finally, there is a list with all of the performance and scalability recommendations.

   ![SQL Healthcheck performance status](./sql_healthcheck_performance_status.png)

   ![SQL Healthcheck performance priority](./sql_healthcheck_performance_priority.png)

   ![SQL Healthcheck performance status recommendations](./sql_healthcheck_performance_recommendations.png)

* *Upgrade, migration and deployment* - this section has three different reports for all upgrade, migration and deployment recommendations. The first one shows the results for all the checks grouped by status: passed, failed or inconclusive. The second report shows a donut chart with the recommendations grouped by priority low, medium or high. Finally, there is a list with all of the upgrade, migration and deployment recommendations.

   ![SQL Healthcheck upgrade status](./sql_healthcheck_upgrade_status.png)

   ![SQL Healthcheck upgrade priority](./sql_healthcheck_upgrade_priority.png)

   ![SQL Healthcheck upgrade recommendations](./sql_healthcheck_upgrade_recommendations.png)
