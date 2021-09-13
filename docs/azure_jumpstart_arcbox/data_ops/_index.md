---
type: docs
title: "Jumpstart ArcBox - Data Services Operations"
weight: 100
toc_hide: true
---

# Jumpstart ArcBox - Data Services Operations

## Azure Arc-enabled SQL Managed Instance Stress Simulation

Included in ArcBox, is a dedicated SQL stress simulation tool named _SqlQueryStress_ automatically installed for you on the Client VM. _SqlQueryStress_ will allow you to generate load on the Azure Arc-enabled SQL Managed Instance that can be done used to showcase how the SQL database and services are performing as well to highlight operational practices described in the next section.

* To start with, open the _SqlQueryStress_ desktop shortcut and connect to the SQL Managed Instance endpoint IP address. This can be found in the _SQLMI Endpoints_ text file desktop shortcut that was also created for you alongside the username and password you used to deploy the environment.

  ![Open SqlQueryStress](./SqlQueryStress.png)

  ![SQLMI Endpoints text file](./endpoints.png)

* To connect, use "SQL Server Authentication" and select the deployed sample _AdventureWorks_ database (you can use the "Test" button to check the connection).

  ![SqlQueryStress connected](./connected.png)

* To generate some load, we will be running a simple stored procedure. Copy the below procedure and change the number of iterations you want it to run as well as the number of threads to generate even more load on the database. In addition, change the delay between queries to 1ms for allowing the stored procedure to run for a while.

    ```sql
    exec [dbo].[uspGetEmployeeManagers] @BusinessEntityID = 8
    ```

* As you can see from the example below, the configuration settings are 100,000 iterations, five threads per iteration, and a 1ms delay between queries. These configurations should allow you to have the stress test running for a while.

  ![SqlQueryStress settings](./sqssettings.png)

  ![SqlQueryStress running](./sqsrunning.png)

## Azure Arc-enabled SQL Managed Instance monitoring using Grafana

When deploying Azure Arc-enabled data services, a [Grafana](https://grafana.com/) instance is also automatically deployed on the same Kubernetes cluster and include built-in dashboards for both Kubernetes infrastructure as well SQL Managed Instance monitoring (PostgreSQL dashboards are included as well but we will not be covering these in this section).

* Now that you have the _SqlQueryStress_ stored procedure running and generating load, we can look how this is shown in the the built-in Grafana dashboard. As part of the automation, a new URL desktop shortcut simply named "Grafana" was created.

  ![Grafana desktop shortcut](./grafanashortcut.png)

* [Optional] The IP address for this instance represents the Kubernetes _LoadBalancer_ external IP that was provision as part of Azure Arc-enabled data services. Use the _```kubectl get svc -n arc```_ command to view the _metricsui_ external service IP address.

  ![metricsui Kubernetes service](./metricsui.png)

* To log in, use the same username and password that is in the _SQLMI Endpoints_ text file desktop shortcut.

  ![Grafana username and password](./grananacreds.png)

* Navigate to the built-in "SQL Managed Instance Metrics" dashboard.

  ![Grafana dashboards](./grananadashboards.png)

  ![Grafana "SQL Managed Instance Metrics" dashboard](./grananasqldashboard.png)

* Change the dashboard time range to "Last 5 minutes" and re-run the stress test using _SqlQueryStress_ (in case it was already finished).

  ![Last 5 minutes time range](./fivemin.png)

* You can now see how the SQL graphs are starting to show increased activity and load on the database instance.

  ![Increased load activity](./activity1.png)

  ![Increased load activity](./activity2.png)
