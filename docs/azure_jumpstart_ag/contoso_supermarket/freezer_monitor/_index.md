# Overview

---
type: docs
weight: 100
toc_hide: true
---

# 

## Overview + Diagram (if applicable)

![Applications and technology stack architecture diagram](./img/placeholder.png)

### Data flow

![Data flow diagram](./img/placeholder.png)
(not sure if separate dfd is needed with the Diagram above...
)

## Instructions

### Scenario 1: Identifying the broken freezer

The manager of the Chicago store has reported that food in one of the freezers has not been staying frozen. She has moved the food to the second freezer and called for service, but the technician reported that the freezer seems to be operating within parameters. Your job as the data analyst is to determine if the temperature sensor in the freezer has observed the issue, and provide the data to the store manager.

- Confirm the issue in Azure Data Explorer
    1. From your own computer (not the Client VM) Open the dashboard named "Freezer Monitoring" in Azure Data Explorer: https://dataexplorer.azure.com/dashboards
    ![Dashboard showing all freezers](./img/placeholder.png)

    2. The charts are quite busy so let's make it easier to see if there is a problem in Chicago by filtering the dashboard to show only data for the Chicago site.
        ![Dashboard showing Chicago freezers only](./img/placeholder.png)

    3. The store manager didn't tell you which freezer was having problems, but it's obvious that Freezer-2 is regularly exceeding the safe threshold of 20 degrees. You can send information to the store manager via a screenshot, or you can explain to the manager how she can use Grafana in the store to see the same data.

    4. While you're in the dashboard, take a look at the Seattle store to see if there are any issues that should be reported to the store manager.

- View the data in Grafana at the store
    1. Connect to the Client VM
    2. Open the Edge browser, expand Grafana in the Favorites Bar and select Grafana Prod
    3. Login using the username `admin` and the password you Windows Admin Password you provided when you created your deployment
    4. Click the Hamburger menu > then Dashboards
    5. Click General to see the dashboards
    6. Click "Chicago - Freezer Monitoring" to see the dashboard
    7. Notice that freezer2 is showing significant variability and frequently exceeding the safe threshold of 15 degrees.
    8. The manager can use this dashboard directly when talking to the technician about the freezer.

- TODO - fix series names to just show "Freezer-1-Chicago"

### Scenario 2: Send alert when freezer is too warm

As the manager of the Chicago store, you can use the Grafana dashboard to see the current temperature, but you're a busy person so you want to be notified when the temperature exceeds the safe threshold of 15 degrees so you can take action immediately.

(*Note - this won't really send you email because the server is not configured to send smtp messages. However, it will help you understand the potential options available to a store manager.*)

1. In the Grafana dashboard, click the Hamburger menu > then Alerting
2. Add a Contact point
   1. Click 'Contact points' in the navigation menu on the left
   2. Click the 'Add contact point' button
   3. Enter 'Chicago Store Manager' as the Name and 'chicago@contoso.com' in the Address field
   4. Click 'Save contact point'
3. Add an Alert rule
   ![Add alert rule](./img/placeholder.png)
   1. Click 'Alert rules' in the navigation menu
   2. Click the 'Create alert rule' button
   3. Section 1
      1. Enter 'Freezer too warm - food at risk' as the Rule name
   4. Section 2
      1. Select 'Chicago' as the data source in query 'A'
      2. Select 'Temperature' as the Metric in auery 'A'
      3. Enter '15' as the Threshold in expression 'C'
      4. Click the 'Preview' button
      5. It's difficult to determine which series is which, so let's fix the series names
         1. Click options under 'Legend'
         2. Select 'Custom'  enter '{{sensor}}'
         3. Click away from the 'Legend' box, then back into it for the series names to update
      6. Now, notice in the chart the times where freezer2 exceeds the threshold and would trigger an alert
   5. Section 3
      1. Under 'Folder' type 'Alerts' and press 'Enter'
      2. Under 'Evaluation group' type 'Alert Group' and press 'Enter'
   6. Scroll to the top of the page and click the 'Save and exit' button
4. View your alert
    1. Back on the 'Alert rules' page, type 'freezer' in the 'Search box' and press 'Enter'
    2. Expand the 'Alerts > Alert Group' folder to see your 'Freezer too warm - food at risk' alert
    3. Expand the alert to view Silence it, view the state history, or quickly edit or delete the alert

### Scenario 3: Follow the data from the freezer to the dashboards

There are a lot of moving parts so lets take a look at how the data flows from from a simulated freezer to the dashboards in Azure Data Explorer and Grafana.

#### MQTT Simulator

The first component, which generates the data for both dashboards is the MQTT Simulator. The simulator is a python script that runs in each AKS Edge Essentials cluster. It generates simulated temperature and humidity data for two freezers in each environment and sends the data via the MQTT protocol to the MQTT Broker.

To see data being produced by the MQTT Simulator

1. Connect to the Client VM
2. Open Visual Studio Code
3. Click on the Kubernetes icon in the Activity Bar on the left
4. Right-click on the 'chicago' cluster and select 'Set as Current Cluster'
5. Expand Seattle > Namespaces, right-click on 'sensor-monitor' and select 'Use Namespace'
6. Expand Seattle > Workloads > Pods
7. Right-click on the 'sensor-monitor-simulator-xxx' pod and select 'Logs'
8. In the Logs window that appears, select 'mqtt-simulator' from the Container dropdown, then click the 'Run' button
9. This won't show you the values being produced, but it will show you that data is being published to the MQTT Broker

#### MQTT Broker

The MQTT Broker is a container running Mosquitto in each AKS Edge Essentials cluster like the simulator. It receives the data from the simulator and sends it to the Azure IoT Hub. It also makes the data available for a third service, MQTT2Prometheus, which we'll discuss in a moment.

To see data being received by the MQTT Broker
(you can skip steps 1-6 if you just finished inspecting the Simulator logs.)

1. Connect to the Client VM
2. Open Visual Studio Code
3. Click the Kubernetes icon in the Activity Bar on the left
4. Right-click on the 'chicago' cluster and select 'Set as Current Cluster'
5. Expand Seattle > Namespaces, right-click on 'sensor-monitor' and select 'Use Namespace'
6. Expand Seattle > Workloads > Pods
7. Right-click on the 'sensor-monitor-broker-xxx' pod and select 'Logs'
8. In the Logs window that appears, select 'mqtt-broker' from the Container dropdown, then click the 'Run' button
9. This won't show you the values being produced, but it will show you the connections from the 2 simulated freezer devices to the broker, as well as the connections from the broker to Azure IoT Hub for each freezer device. Finally, shows the connection from 'sensor-monitor-mqtt2prom' which subscribes to the freezer data on the broker and makes it available to Prometheus, but more on that a bit later.

#### Azure IoT Hub

From the MQTT Broker the data is sent to Azure IoT Hub. IoT Hub is a managed service, hosted in the cloud, that acts as a central message hub for bi-directional communication between your IoT application and the devices it manages. You can use IoT Hub to build IoT solutions with reliable and secure communications between millions of IoT devices and a cloud-hosted solution backend. You can connect virtually any device to IoT Hub.

To see whether data is being received by Azure IoT Hub for your devices

1. Open the Azure Portal - https://portal.azure.com
2. Click the 'Resource groups' icon in the left navigation menu (expand the menu at the top if necessary)
3. Click the new resource group that was created for you when you created the environment
4. Click 'Ag-IotHub-xxxxx' to open the IoT Hub
5. Click 'Queries' in the left navigation menu
6. Click the 'Run query' button
7. Scroll down to where you see "deviceId": "Freezer-1-Chicago"
8. Review the "connectionState" and "lastActivityTime" values to see if the device is connected and sending data
9. Repeat steps 7 and 8 for "Freezer-2-Chicago"

#### Azure Data Explorer (ADX)

Azure Data Explorer (ADX) is a cloud service that ingests, stores, and analyzes diverse data from any data source. It is a fast, fully managed data analytics service for real-time analysis on large volumes of data streaming (i.e. log and telemetry data) from applications, websites, IoT devices, and more. ADX is a great choice for analyzing data from IoT devices because it can ingest data from a variety of sources, including IoT Hub, which is how we're getting the data from the MQTT Broker.

#### MQTT2Prometheus

#### Prometheus

#### Grafana


### Additional Scenarios

- "fix the freezer"

## Cleanup (if applicable)

## Troubleshooting (if applicable)

- what if data is not flowing
- logs for simulator
- logs for broker
- metrics for broker
- prometheus view
- grafana view

## Next steps

