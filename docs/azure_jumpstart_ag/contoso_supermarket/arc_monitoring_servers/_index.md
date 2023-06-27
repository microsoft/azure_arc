---
type: docs
weight: 100
toc_hide: true
---

# Infrastructure observability for Azure Arc-enabled servers using Azure Monitor

## Overview

Infrastructure observability is key for Contoso Supermarket to understand the performance and the health of their Azure Arc-enabled servers. This is where [Azure Monitor](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/hybrid/arc-enabled-servers/eslz-management-and-monitoring-arc-server) steps in, playing a crucial role in providing visibility into every aspect of their Azure Arc-enabled servers ecosystem.

Azure Monitor empowers Contoso with the ability to monitor and collect telemetry data from their Azure Arc-enabled servers. It acts as a central hub, delivering near real-time insights into server performance, health, and resource utilization. Azure Monitor provides a holistic view of the entire infrastructure, ensuring proactive identification and resolution of potential issues.

## Enable and configure Azure Monitor

Azure Monitor can collect data directly from your Arc-enabled servers into a Log Analytics workspace for detailed analysis and correlation. It requires installing both the Azure Monitor Agent (AMA) and the Dependency Agent VM extension in your Azure Arc-enabled servers, enabling VM insights to collect data from your machines.

As part of the automated deployment, an Azure Policy monitoring initiative and a Data Collection Rule (DCR) are deployed. They allow collecting monitoring data from your Azure Arc-enabled servers.

Follow these steps to verify that these required Azure Monitor artifacts have been successfully deployed:

- In the top bar of the Azure portal, search for __policy__ and click on __Policy__:

    ![Screenshot of searching Azure Policy](./img/search_policy.png)

- Click on __Assignments__. You will see the Azure Policy initiative "_(Ag) Enable Azure Monitor for Hybrid VMs with AMA_". This initiative enables Azure Monitor for the hybrid virtual machines with AMA. It takes a Log Analytics workspace as a parameter and asks for an option to enable Processes and Dependencies.

    ![Screenshot of Azure Monitor initiative assignment Azure Policy](./img/azure_monitor_initiative.png)

- The Azure Policy initiative mentioned above deploys a Data Collection Rule (DCR), which is in charge of collecting monitoring data from the Azure Arc-enabled servers. In the top bar, search for __Data collection rules__:

    ![Screenshot of searching Data Collection Rules](./img/search_dcr.png)

- You will find the DCR that has been created to collect insights from the Azure Arc-enabled servers:

    ![Screenshot of the Data Collection Rules](./img/dcr_vmi.png)

- Click on the DCR. You will see the data sources collected ant the Azure Arc-enabled servers associated with this DCR:

    ![Screenshot of the DCR - Data sources](./img/dcr_datasources.png)

    ![Screenshot of the DCR - Resources](./img/dcr_resources.png)

## Azure Arc-enabled servers and Azure Monitor VMInsights Integration

Now that we have checked that the required monitoring artifacts have been successfully enabled, it's time to leverage VMInsights. It monitors the performance and health of your Azure Arc-enabled servers by collecting data on their running processes and dependencies on other resources.

- Search for __Azure Arc__, go to __Servers__ and click in one of your __Azure Arc-enabled servers__:

    ![Screenshot of searching for an Azure Arc-enabled server](./img/search_arc_server.png)

- Click on __Insights__ and then on __Performance__. You will find a set of performance charts that target several key performance indicators to help you determine how well your Azure Arc-enabled server is performing. The charts show resource utilization over a period of time:

    ![Screenshot of VMInsights - Performance](./img/vminsights_performance.png)

- After you have explored all the available performance charts, click on __Map__. You will see the processes running in your Azure Arc-enabled servers, their connections and dependencies:

    ![Screenshot of VMInsights - Map](./img/vminsights_map.png)

## Next steps

Now that you have successfully learned how the integration of Azure Monitor for Azure Arc-enabled servers works, continue to the next step to learn how to [secure your Azure Arc-enabled servers with Microsoft Defender for Servers](../arc_defender_servers/_index.md).
