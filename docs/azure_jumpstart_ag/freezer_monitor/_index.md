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

## Instructions

### Scenario: Identifying the broken freezer
The manager of the Chicago store has reported that food in one of the freezers has not been staying frozen. She has moved the food to the second freezer and called for service, but the technician reported that the freezer seems to be operating within parameters. Your job as the data analyst is to determine if the temperature sensor in the freezer has observed the issue, and provide the data to the store manager.

- Confirm the issue in Azure Data Explorer
    1. From your own computer (not the Client VM) Open the dashboard named "Freezer Monitoring" in Azure Data Explorer: https://dataexplorer.azure.com/dashboards
    ![Dashboard showing all freezers](./img/placeholder.png)
    
    ```
    environmentSensor
| project site = tostring(split(['device-id'],"-")[2])
| distinct site

    ```
    ```
    environmentSensor
//| where ['iothub-enqueuedtime'] > now(-1h)
| where ['iothub-enqueuedtime'] between (['_startTime'] .. ['_endTime'])
| where ['device-id'] has ['site']
| project ['iothub-enqueuedtime'], ['device-id'], Temperature_F
    ```

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
    7. Notice that freezer2 is showing significant variability and frequently exceeding the safe threshold of 20 degrees.
    8. The manager can use this dashboard directly when talking to the technician about the freezer.



- TODO - fix series names to just show "Freezer-1-Chicago"

Additional Scenarios
- add a threshold
- send a notification
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

