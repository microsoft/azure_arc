---
type: docs
weight: 100
toc_hide: true
---

## Contoso Supermarket Freezer Monitor Overview

### Overview

Contoso Supermarket is obsessed with achieving the highest levels of food safety. To support this obsession Contoso has invested in technology to let it know when any food in a store's freezers is potentially unsafe due to the freezer reaching temperatures that would allow the food to thaw and pathogens to grow.

Contoso has installed IoT sensors in each freezer in each store to detect both temperature and humidity. The IoT sensors send current measurements via Message Queuing Telemetry Transport (MQTT) to a broker service in each store. The broker forwards the data to [Azure IoT Hub](https://azure.microsoft.com/products/iot-hub/) and along to [Azure Data Explorer (ADX)](https://azure.microsoft.com/products/data-explorer/) for aggregation with data from all stores and analysis. In addition, the sensor data is also sent to a dashboard in each store for visualizing sensor history and to enable early warning notifications to the store manager when a safety issue is imminent.

Contoso Supermarket is researching a number of additional health and safety systems that will leverage the same IoT infrastructure. These include:

- Air quality sensors to detect the presence of smoke or other contaminants
- Water quality sensors to detect the presence of contaminants in the water supply
- Motion and presence sensors to lights should be turned on for personal safety

The local collection and visualization of sensor data uses the same infrastructure as the [Infrastructure Observability](..\k8s_infra_observability\_index.md) stack, namely Prometheus and Grafana. This provides the store manager with a single pane of glass for monitoring both the infrastructure and the sensors, and minimizes the number of new technologies that the manager needs to learn and that Contoso must to support.

[Prometheus](https://prometheus.io/) is a highly efficient open-source monitoring system that collects and stores metrics from various sources in real-time. It provides a flexible query language for analyzing the collected metrics and offers robust alerting capabilities. On the other hand, [Grafana](https://grafana.com/) is a powerful open-source data visualization and analytics platform. It allows users to create interactive and customizable dashboards to visualize the collected metrics in real-time and also offers its own alerting capabilities.

### Architecture

![Applications and technology stack architecture diagram](./img/architecture.png)

As mentioned above, the environmental observability architecture for _Staging_, _Dev_, and _Prod_ environments leverages the the same Kube Prometheus Stack as Infrastructure Observability, which includes Kubernetes manifests, Grafana dashboards, and Prometheus rules. Added to that are the IoT sensors (simulated in our scenario), [Mosquitto MQTT broker](https://mosquitto.org/), Azure IoT Hub, ADX, and a service that exposes IoT data to be scraped by Prometheus (MQTT2PROM).

Mosquitto MQTT was chosen because it is a popular, open-source MQTT broker that is lightweight and efficient, making it a good fit for the IoT sensors. Azure IoT Hub is a fully managed service that enables reliable and secure bi-directional communications between millions of IoT devices and a solution back end. It also provides a device registry that stores information about the devices and their capabilities.

The _Dev_ and _Staging_ environments are configured with individual Prometheus and Grafana instances, while the _Prod_ environment is configured with a central Grafana instance. This architecture allows for more granular monitoring and troubleshooting in the _Dev_ and _Staging_ environments, while still providing a centralized view of the infrastructure's health and performance in the _Prod_ environment.

## Freezer Monitoring dashboard

Contoso has an ADX dashboard for Freezer Monitoring analytics and monitoring. The dashboard is generated from live data sent from the IoT devices through the MQTT broker and IoT Hub to the ADX database using data integration.

## Manually import dashboard

> __NOTE: If you used the [Azure Developer CLI (azd) method](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md#deployment-via-azure-developer-cli-experimental) to deploy the Contoso Supermarket scenario, you may skip this section as the dashboard is automatically imported for you during the automated deployment.__

To view the Freezer Monitoring dashboard you will first need to import it into ADX.

- On the Client VM, open Windows Explorer and navigate to folder _C:\Ag\adx_dashboards_ folder. This folder contains two ADX dashboard JSON files (_adx-dashboard-iotsensor-payload.json_ and _adx-dashboard-orders-payload.json_) with the ADX name and URI updated when the deployment PowerShell logon script is completed.

  ![Locate dashboard template files](./img/adx_dashboard_report_files.png)

- Copy these ADX dashboard JSON files on your local machine in a temporary folder to import into ADX dashboards. Alternatively, you can log in to ADX Dashboards directly on the Client VM.

  > __NOTE: Depending on the account being used to log in to ADX portal, the Azure AD tenant of that account may have conditional access policies enabled and might prevent log in to ADX Dashboards from the Client VM as this VM is not managed by your organization.__

- On your local machine open the browser of your choice OR on the Client VM open the Edge browser and log in to [ADX Dashboards](https://dataexplorer.azure.com/). Use the same user account that you deployed Jumpstart Agora in your subscription. Failure to use the same account will prevent access to the ADX Orders database to generate dashboards.

- Once you are logged in to ADX dashboards, click on Dashboards in the left navigation to import the Freezer Monitoring dashboard.

  ![Navigate to ADX dashboard](./img/adx_view_dashboards.png)

- Select _Import dashboard from file_ to select previously copied file from the Client VM to your local machine or the _C:\Ag\adx_dashboards_ folder on the Client VM.

  ![Select import dashboard file](./img/adx_import_dashboard_file.png)

- Choose to import the _adx-dashboard-iotsensor-payload.json_ file.

  ![Choose dashboard JSON file to import](./img/adx_select_dashboard_file.png)

- Confirm the dashboard name, accept the suggested name (or choose your own), and click Create.

  ![Confirm dashboard name](./img/adx_confirm_dashboard_report_name.png)

- By default, the simulated IoT sensors are sending data to ADX so you will see at least a few minutes of data in the dashboard. Click Save to save the dashboard in ADX.

  ![Default freezer dashboard](./img/adx_freezer_dashboard_default.png)

## Scenarios

Here are a few scenarios that Contoso Supermarket might encounter, and how they can be addressed using the data collected by the IoT sensors.

### Scenario 1: Identifying the broken freezer

The manager of the Chicago store has reported that food in one of the freezers has not been staying frozen. She has moved the food to the second freezer and called for service, but the technician reported that the freezer seems to be operating within parameters. Your job as the data analyst is to determine if the temperature sensor in the freezer has observed the issue, and provide the data to the store manager.

#### Confirm the issue in Azure Data Explorer

- Open the _Freezer Monitoring_ dashboard in ADX: https://dataexplorer.azure.com/dashboards
   ![Dashboard showing all freezers](./img/adx_freezer_dashboard_default.png)

- The charts are quite busy so let's make it easier to see if there is a problem in Chicago by filtering the dashboard to show only data for the Chicago store.
   ![Dashboard showing filtering for Chicago](./img/adx_freezer_dashboard_select_chicago.png)

- The store manager didn't tell you which freezer was having problems, but if you look at the dashboard below it's obvious that Freezer-2 (aka device-id:Freezer-2-Chicago:Temperature_F) is regularly exceeding the safe threshold of 20°F as indicated by the green dashed line. You can send this information to the store manager via a screenshot, or you can show the manager how she can use the Grafana dashboard to see see the same data.
   ![Dashboard showing only Chicago freezers](./img/adx_freezer_dashboard_show_chicago.png)

- While you're viewing the dashboard, take a look at the Seattle store to see if there are any issues that should be reported to that store manager.

#### View the data in Grafana at the store

From the Client VM:

- Open the Edge browser, expand Grafana in the Favorites Bar, and select Grafana Prod
- Login with the username `admin` and the Windows Admin Password you provided when you created your deployment
- Click the Hamburger menu next to "Home" then click Dashboards
  ![Grafana showing the Dashboards menu](./img/grafana_click_dashboards.png)
- Click General to see the list of dashboards then click "Chicago - Freezer Monitoring" to open the dashboard for Chicago
  ![Grafana showing list of Dashboards](./img/grafana_click_chicago.png)
  - Notice that freezer2 is showing significant variability and frequently exceeding the safe threshold of 20°F.
  ![Grafana showing the Chicago dashboard](./img/grafana_chicago_dashboard.png)
- The manager can use this dashboard directly when talking to the technician about the freezer.

### Scenario 2: Send alert when freezer is too warm

As the manager of the Chicago store, you can use the Grafana dashboard to see the current temperature, but you're a busy person so you want to be notified when the temperature exceeds the safe threshold of 15°F so you can take action immediately.

__NOTE: This won't really send you email because the server is not configured to send smtp messages. However, it will help you understand the potential options available to a store manager.__

- In the Grafana dashboard, click the Hamburger menu > then Alerting
- Add a Contact point
  - Click 'Contact points' in the navigation menu on the left
  - Click the 'Add contact point' button
  - Enter 'Chicago Store Manager' as the Name and 'chicago@contoso.com' in the Address field
  - Click 'Save contact point'
- Add an Alert rule
  ![Add alert rule](./img/placeholder.png)
  - Click 'Alert rules' in the navigation menu
  - Click the 'Create alert rule' button
  - Section 1
    - Enter 'Freezer too warm - food at risk' as the Rule name
  - Section 2
    - Select 'Chicago' as the data source in query 'A'
    - Select 'Temperature' as the Metric in query 'A'
    - Enter '15' as the Threshold in expression 'C'
    - Click the 'Preview' button
    - It's difficult to determine which series is which, so let's fix the series names
      - Click options under 'Legend'
      - Select 'Custom'  enter '{{sensor}}'
      - Click away from the 'Legend' box, then back into it for the series names to update
    - Notice in the chart the times where freezer2 exceeds the threshold and would trigger an alert
  - Section 3
    - Under 'Folder' type 'Alerts' and press 'Enter'
    - Under 'Evaluation group' type 'Alert Group' and press 'Enter'
  - Scroll to the top of the page and click the 'Save and exit' button
- View your alert
  - Back on the 'Alert rules' page, type 'freezer' in the 'Search box' and press 'Enter'
  - Expand the 'Alerts > Alert Group' folder to see your 'Freezer too warm - food at risk' alert
  - Expand the alert to view Silence it, view the state history, or quickly edit or delete the alert

### Scenario 3: Follow the data from the freezer to the dashboards

There are a lot of moving parts so lets take a look at how the data flows from from a simulated freezer to the dashboards in Azure Data Explorer and Grafana.

#### MQTT Simulator

The first component, which generates the data for both dashboards is the MQTT Simulator. The simulator is a python script that runs in each AKS Edge Essentials cluster. It generates simulated temperature and humidity data for two freezers in each environment and sends the data via the MQTT protocol to the MQTT Broker.

To see data being produced by the MQTT Simulator

- Connect to the Client VM
- Open Visual Studio Code
- Click on the Kubernetes icon in the Activity Bar on the left
- Right-click on the 'chicago' cluster and select 'Set as Current Cluster'
- Expand Seattle > Namespaces, right-click on 'sensor-monitor' and select 'Use Namespace'
- Expand Seattle > Workloads > Pods
- Right-click on the 'sensor-monitor-simulator-xxx' pod and select 'Logs'
- In the Logs window that appears, select 'mqtt-simulator' from the Container dropdown, then click the 'Run' button
- This won't show you the values being produced, but it will show you that data is being published to the MQTT Broker

#### MQTT Broker

The MQTT Broker is a container running Mosquitto in each AKS Edge Essentials cluster like the simulator. It receives the data from the simulator and sends it to the Azure IoT Hub. It also makes the data available for a third service, MQTT2Prometheus, which we'll discuss in a moment.

To see data being received by the MQTT Broker
(you can skip steps 1-6 if you just finished inspecting the Simulator logs.)

- Connect to the Client VM
- Open Visual Studio Code
- Click the Kubernetes icon in the Activity Bar on the left
- Right-click on the 'chicago' cluster and select 'Set as Current Cluster'
- Expand Seattle > Namespaces, right-click on 'sensor-monitor' and select 'Use Namespace'
- Expand Seattle > Workloads > Pods
- Right-click on the 'sensor-monitor-broker-xxx' pod and select 'Logs'
- In the Logs window that appears, select 'mqtt-broker' from the Container dropdown, then click the 'Run' button
- This won't show you the values being produced, but it will show you the connections from the 2 simulated freezer devices to the broker, as well as the connections from the broker to Azure IoT Hub for each freezer device. Finally, shows the connection from 'sensor-monitor-mqtt2prom' which subscribes to the freezer data on the broker and makes it available to Prometheus, but more on that a bit later.

#### Azure IoT Hub

From the MQTT Broker the data is sent to Azure IoT Hub. IoT Hub is a managed service, hosted in the cloud, that acts as a central message hub for bi-directional communication between your IoT application and the devices it manages. You can use IoT Hub to build IoT solutions with reliable and secure communications between millions of IoT devices and a cloud-hosted solution backend. You can connect virtually any device to IoT Hub.

To see whether data is being received by Azure IoT Hub for your devices

- Open the Azure Portal - https://portal.azure.com
- Click the 'Resource groups' icon in the left navigation menu (expand the menu at the top if necessary)
- Click the new resource group that was created for you when you created the environment
- Click 'Ag-IotHub-xxxxx' to open the IoT Hub
- Click 'Queries' in the left navigation menu
- Click the 'Run query' button
- Scroll down to where you see "deviceId": "Freezer-1-Chicago"
- Review the "connectionState" and "lastActivityTime" values to see if the device is connected and sending data
- Repeat the last 2 steps above for "Freezer-2-Chicago"

#### Azure Data Explorer (ADX)

Azure Data Explorer (ADX) is a cloud service that ingests, stores, and analyzes diverse data from any data source. It is a fast, fully managed data analytics service for real-time analysis on large volumes of data streaming (i.e. log and telemetry data) from applications, websites, IoT devices, and more. ADX is a great choice for analyzing data from IoT devices because it can ingest data from a variety of sources, including IoT Hub, which is how we're getting the data from the MQTT Broker.

### Additional Scenarios

- "fix the freezer"

## Troubleshooting (if applicable)

- what if data is not flowing
- logs for simulator
- logs for broker
- metrics for broker
- prometheus view
- grafana view

## Next steps
