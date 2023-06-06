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

### Scenario: Identifying the broken freezer

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

### Scenario: Send alert when freezer is too warm

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
      6.  Now, notice in the chart the times where freezer2 exceeds the threshold and would trigger an alert
   5.  Section 3
      1.  Under 'Folder' type 'Alerts' and press 'Enter'
      2.  Under 'Evaluation group' type 'Alert Group' and press 'Enter'
   6.  Scroll to the top of the page and click the 'Save and exit' button
4.  View your alert
    1.  Back on the 'Alert rules' page, type 'freezer' in the 'Search box' and press 'Enter'
    2.  Expand the 'Alerts > Alert Group' folder to see your 'Freezer too warm - food at risk' alert
    3.  Expand the alert to view Silence it, view the state history, or quickly edit or delete the alert

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

