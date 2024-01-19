---
type: docs
weight: 100
toc_hide: true
---

# Infrastructure observability for Kubernetes and Arc-enabled Kubernetes

## Overview

Infrastructure observability plays a crucial role in the success of Contoso Supermarket's cloud to edge strategy. By implementing infrastructure observability, Contoso gains comprehensive monitoring and visualization capabilities for their Kubernetes and Arc-enabled Kubernetes environments. This empowers them to proactively monitor the health and performance of their infrastructure, identify potential issues, and make data-driven decisions to optimize their operations. With infrastructure observability, Contoso can ensure that their cloud and edge infrastructure remain reliable, efficient, and resilient, enabling them to deliver exceptional customer experiences.

[Prometheus](https://prometheus.io/) is a highly efficient open-source monitoring system that collects and stores metrics from various sources in real-time. It provides a flexible query language for analyzing the collected metrics and offers robust alerting capabilities. On the other hand, [Grafana](https://grafana.com/) is a powerful open-source data visualization and analytics platform. It allows users to create interactive and customizable dashboards to visualize the collected metrics in real-time.

By leveraging Prometheus and Grafana for infrastructure observability, Contoso enjoys several advantages. Firstly, Prometheus's efficient data collection ensures that Contoso can monitor crucial performance indicators and resource utilization in real-time. Secondly, Grafana provides a user-friendly interface for visualizing the collected metrics, enabling Contoso to create interactive and customizable dashboards. These dashboards allow them to gain valuable insights into their infrastructure's health and performance, identify trends, and make informed decisions. Lastly, the combination of Prometheus and Grafana supports troubleshooting and root cause analysis.

## Architecture

The observability infrastructure stack architecture for Staging, Dev, and Prod environments leverages the [Kube Prometheus Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack). This stack is a collection of Kubernetes manifests, Grafana dashboards, and Prometheus rules that are used to set up and configure monitoring for Kubernetes clusters.

The Dev and Staging environments are configured with individual Prometheus and Grafana instances, while the Prod environment is configured with a central Grafana instance. This architecture allows for more granular monitoring and troubleshooting in the Dev and Staging environments, while still providing a centralized view of the infrastructure's health and performance in the Prod environment.

![Screenshot showing Observability infrastructure stack architecture](./img/technology_stack.png)

## Grafana dashboards

Grafana's dashboards in Contoso's implementation provide a visually appealing and customizable interface for monitoring their infrastructure. With Grafana, they can create intuitive and interactive dashboards that display key metrics and insights, empowering them to make data-driven decisions and quickly identify any issues or trends within their cloud to edge infrastructure. The following Grafana dashboards are automatically deployed as part of advanced automation to the Dev, Staging, and Prod environments:

- __Kubernetes / Views / Global__: The Kubernetes Global Dashboard in Grafana offers a concise overview of your Kubernetes cluster, allowing you to quickly assess its overall health and performance. The dashboard includes panels that highlight key metrics, such as total cluster CPU, RAM, and network utilization, as well as resource usage across namespaces and nodes. Additionally, it tracks the number of resource types used in the cluster and helps detect misconfigured application resources by comparing real usage with requested and limited resources.

- __Node Exporter Full__: The Kubernetes Nodes Dashboard in Grafana provides a detailed view of node-level metrics and resources in your Kubernetes cluster. It enables you to monitor CPU and RAM usage, track pods running on each node, and identify any resource anomalies or performance issues. The dashboard also offers system-level metrics such as system load, context switches, and file descriptors, allowing for troubleshooting and optimization. Additionally, it provides insights into storage capacity, volumes, and I/O operations on the nodes, aiding in the effective management of storage resources.

- __Freezer Monitoring__: The Freezer Monitoring dashboard in Grafana provides the current temperature of the freezers and the temperature history for the last 24 hours. You can also set up alerts to notify you when the temperature exceeds a certain threshold. This allows you to proactively monitor the freezer's health and performance and take corrective actions to prevent any issues. This would be covered in more detail in the ["Data pipeline and reporting across cloud and edge for sensor telemetry" guide.](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/freezer_monitor/)

> __Grafana Dashboard Credits:__
> The Kubernetes dashboards included in this guide are based on the work of publicly available dashboards. We would like to express our appreciation for Author's efforts in creating this insightful dashboard that enhances our monitoring capabilities for Kubernetes.
> The original dashboards can be found at:
> - [Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full)
> - [Grafana Dashboards Kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes)

## Access the dashboards

As an Operations team member at Contoso, you will have access to the Grafana dashboards for infrastructure observability. These dashboards provide a comprehensive view of the health, performance, and metrics of the cloud to edge infrastructure. To access the Grafana dashboards follow the below steps.

- Connect to the Client VM _Ag-VM-Client_ using the instructions in the [deployment guide](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/deployment/#connecting-to-the-agora-client-virtual-machine).

### Production stores

- Open the Edge browser, expand Grafana in the Favorites Bar and select `Grafana Prod`.

    ![Screenshot showing accessing Grafana Prod](./img/grafana_prod.png)

- Login using the Windows Admin Username and Password you provided when you created your deployment.

    ![Screenshot showing Login for Grafana Prod](./img/grafana_prod_login.png)

- Click `Chicago - Kubernetes / Views / Global` dashboard to review the overall health of the cluster.

    ![Screenshot showing Grafana Prod dashboards](./img/grafana_prod_dashboard_global.png)

    ![Screenshot showing Grafana Prod Cluster dashboard](./img/grafana_prod_db_global01.png)

- Review the different panels in the dashboard to see the metrics collected from the Kubernetes cluster.

    ![Screenshot showing Grafana Prod Cluster dashboard panels CPU](./img/grafana_prod_db_global02.png)

    ![Screenshot showing Grafana Prod Cluster dashboard panels Network](./img/grafana_prod_db_global03.png)

- Click `Home` to go back to the home page and review the other dashboards available.

    ![Screenshot showing Grafana Prod Home page](./img/grafana_prod_dashboard_home.png)

- Click `Chicago - Node Exporter Full` dashboard to review the Chicago store node metrics.

    ![Screenshot showing Grafana Prod Node Exporter dashboard](./img/grafana_prod_dashboard_node.png)

    ![Screenshot showing Grafana Prod Node Exporter dashboard overview](./img/grafana_prod_db_node01.png)

- Review the different panels in the dashboard to see the metrics collected from the Kubernetes cluster.

    ![Screenshot showing Grafana Prod Node Exporter dashboard panels CPU](./img/grafana_prod_db_node02.png)

    ![Screenshot showing Grafana Prod Node Exporter dashboard panels Memory](./img/grafana_prod_db_node03.png)

    ![Screenshot showing Grafana Prod Node Exporter dashboard panels Storage](./img/grafana_prod_db_node04.png)

- Repeat the same steps to access the `Seattle Store` dashboards and review the cluster and node metrics.

    ![Screenshot showing Grafana Prod Seattle Store Dashboards](./img/grafana_prod_dashboard_seattle.png)

### Staging store

- Open the Edge browser, expand Grafana in the Favorites Bar and select `Grafana Staging`.

    ![Screenshot showing accessing Grafana Staging](./img/grafana_staging.png)

- Login using the Windows Admin Username and Password you provided when you created your deployment. Review the available dashboards.

    ![Screenshot showing Login Grafana Staging](./img/grafana_staging_dashboard_home.png)

- Review `Staging - Kubernetes / Views / Global` dashboard to check the overall health of the cluster.

    ![Screenshot showing Grafana Staging Cluster dashboard](./img/grafana_staging_dashboard_global.png)

- Review `Staging - Node Exporter Full` dashboard to check the Chicago store node metrics.

    ![Screenshot showing Grafana Staging Node Exporter dashboard](./img/grafana_staging_dashboard_node.png)

### Dev store

- Open the Edge browser, expand Grafana in the Favorites Bar and select `Grafana Dev`.

    ![Screenshot showing accessing Grafana Dev](./img/grafana_dev.png)

- Login using the Windows Admin Username and Password you provided when you created your deployment. Review the available dashboards.

    ![Screenshot showing Login Grafana Dev](./img/grafana_dev_dashboard_home.png)

- Review `Dev - Kubernetes / Views / Global` dashboard to check the overall health of the cluster.

    ![Screenshot showing Grafana Dev Cluster dashboard](./img/grafana_dev_dashboard_global.png)

- Review `Dev - Node Exporter Full` dashboard to check the Dev store node metrics.

    ![Screenshot showing Grafana Dev Node Exporter dashboard](./img/grafana_dev_dashboard_node.png)

## Next steps

Continuing with the next Contoso Supermarket scenario, you can now proceed to the next guide to learn about [infrastructure observability for Azure Arc-enabled servers using Azure Monitor](https://azurearcjumpstart.io/azure_jumpstart_ag/contoso_supermarket/arc_monitoring_servers/).
