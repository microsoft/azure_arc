---
type: docs
weight: 100
toc_hide: true
---

# Contoso Supermarket data pipeline and reporting across cloud and edge - Store orders

One of Contoso's biggest objectives is how to use the data coming from their stores and visualize it for business intelligence by leveraging the power of the cloud.

In this scenario, Contoso wants to use their data pipeline so customer orders placed in the Point of Sale (PoS) application on the various supermarket stores, flow to [Azure Data Explorer (ADX)](https://learn.microsoft.com/azure/data-explorer/data-explorer-overview) database and generate near real-time reports. By doing so, Contoso management can leverage these reports to adjust their inventory and supply chain based on the product demand from customer orders across multiple filters - stores, day, week, month, and year. This helps optimize Contoso resources, stores supplies, saves significant costs and at the same time improves customer satisfaction and trust.

## Architecture

Below is an architecture diagram that shows how the data flows from the PoS application and into the ADX database to generate near real-time reports of orders received and processed across various supermarket store locations. This architecture includes a local PostgreSQL database running at the edge in the store, [Azure Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/introduction) and ADX cluster in Azure cloud, and a Cloud Sync service that moves orders data from edge location to Cosmos DB in the cloud.

![Data pipeline architecture diagram](./img/contoso_supermarket_pos_service_architecture.png)

## PoS dashboard reports

Contoso supports dashboard reports for the PoS application analytics and monitoring. These reports are created in ADX to allow users to view dashboards reports. These reports are generated based on live data received from the PoS application into the ADX database using data integration.

## Manually import dashboards

> **Note:** If you used the [Azure Developer CLI (azd) method](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md#deployment-via-azure-developer-cli-experimental) to deploy the Contoso Supermarket scenario, you may skip this section as these reports are automatically imported for you during the deployment.

Follow the below steps in order to view the PoS Orders dashboard reports you will need to import these into ADX.

- On the Client VM, open Windows Explorer and navigate to folder _C:\Ag\adx_dashboards_ folder. This folder contains two ADX dashboard report JSON files (_adx-dashboard-iotsensor-payload.json_ and _adx-dashboard-orders-payload.json_) with the ADX name and URI updated when the deployment PowerShell logon script is completed.

  ![Locate dashboard report template files](./img/adx_dashboard_report_files.png)

- Copy these ADX dashboards report JSON files on your local machine in a temporary folder to import into ADX dashboards. Alternatively, you can log in to ADX Dashboards directly on the Client VM.

  > **Note:** Depending the account being used to log in to ADX portal, Azure AD tenant of that account may have conditional access policies enabled and might prevent log in to ADX Dashboards from the Client VM as this VM is not managed by your organization.

- On your local machine open the browser of your choice OR on the Client VM open the Edge browser and log in to [ADX Dashboards](https://dataexplorer.azure.com/). Use the same user account that you deployed Jumpstart Agora in your subscription. Failure to use the same account will prevent access to the ADX Orders database to generate reports.

- Once you are logged in to ADX dashboards, click on Dashboards in the left navigation to import the PoS Orders dashboard report.

  ![Navigate to ADX dashboard reports](./img/adx_view_dashboards.png)

- Select _Import dashboard from file_ to select previously copied file from the Client VM to your local machine or the _C:\Ag\adx_dashboards_ folder on the Client VM.

  ![Select import dashboard file](./img/adx_import_dashboard_file.png)

- Choose to import the _adx-dashboard-orders-payload.json_ file.

  ![Choose dashboard report JSON file to import](./img/adx_select_dashboard_file.png)

- Confirm the dashboard report name, accept the suggested name (or choose your own), and click Create.

  ![Confirm dashboard report name](./img/adx_confirm_dashboard_report_name.png)

- By default, there is no data available in the ADX Orders database to display in the report after deployment. Click Save to save the dashboard report in ADX.

  ![Empty data in orders dashboard report](./img/adx_orders_report_empty_data.png)

## Generate sample data using Data Emulator

By default there is no data available in Cosmos DB database after the deployment is complete. There are two ways you can generate Orders data. One method is using PoS application and place orders. Another option is by using Data Emulator tool available on the Agora client VM. Use instructions below to generate sample data using the Data Emulator tool.

- On the Client VM, locate Data Emulator icon on the desktop.

  ![Locate Data Emulator on the desktop](./img/locate_data_emulator_desktop.png)

- Double click on the Data Emulator desktop icon to launch executable and generate sample data. Confirm by entering **Yes** or **Y** to start generating data, entering No or N will exit the tool. This tool generates data for the last 30 days. Say No or N to prevent regenerating sample data if it is generated earlier.

  > **Note**: You can still generate additional sample data by running this tool multiple times, but there might be duplicate key errors and fails to generate data in subsequent attempts.

  ![Confirm sample data generation](./img/confirm_sample_data_generation.png)

  ![Generating sample data](./img/sample_data_generation.png)

- From ADX open PoS Orders report to view simulated orders data. Allow some time to propagate data into the ADX database using an integrated data pipeline.

  ![PoS Orders with simulated data](./img/adx_posorders_with_simulated_data.png)

- PoS Orders dashboard report is configured to display data from the _"Last 1 hour"_ by default. To view all the simulated orders data, change report time range to _"Last 30 days"_ as shown in the picture below. Dashboard report will refresh data and display reports for the selected time range.

  ![PoS Orders select time range](./img/adx_orders_report_select_timerange.png)

  ![PoS Orders with simulated data for selected time range](./img/adx_posorders_with_simulated_data_selected_timerange.png)

### Generate orders from Contoso Supermarket store applications

- On the Agora client VM, open Edge browser. From the favorites bar review bookmarks created for PoS applications for different stores and environments.

  ![PoS app bookmarks](./img/pos_app_edge_bookmarks.png)

- From the bookmarks expand POS -> Chicago and select "POS Chicago - Customer".

  ![Select POS Chicago application](./img/pos_app_edge_select_pos_chicago_customer.png)

- Randomly add a few items to the cart.

  ![Select PoS Chicago application](./img/chicago_pos_app_customer.png)

- Click on Cart, review items, and click Place Order.

  ![Select PoS Chicago application](./img/pos_chicago_customer_place_order.png)

- Place additional orders from the same store by repeating the above steps. Try adding random items to each order to simulate orders from different customers of the store.

- In the ADX Portal, under Dashboards, open the PoS Orders report and set the time range for "_Last 30 minutes_", and refresh the report to see data.

> **NOTE:** As the Cloud Sync service performs the sync in the backend, it might take a few minutes for orders to show up in ADX.

  ![PoS Chicago dashboard report](./img/pos_chicago_customer_report.png)

- From Edge browser bookmarks, open the PoS application for other stores and repeat the order processing and see the PoS Orders dashboard for multiple stores and environments.

  ![PoS Orders multiple stores dashboard report](./img/pos_orders_multiplestores_report.png)

## Next steps

Use the following guides to explore different use cases of Contoso Supermarket in Jumpstart Agora.

- [PoS](https://placeholder)
- [Freezer Monitor](https://placeholder)
- [CI/CD](https://placeholder)
- [Basic GitOps](https://placeholder)
- [Analytics](https://analytics)
- [Troubleshooting](https://troubleshooting)
