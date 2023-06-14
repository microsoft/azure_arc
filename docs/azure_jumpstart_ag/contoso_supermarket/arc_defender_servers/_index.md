---
type: docs
weight: 100
toc_hide: true
---

# Infrastructure security with Microsoft Defender for Servers

## Overview

Contoso Supermarket is aware that as they navigate the complex landscape of edge computing, it is essential to protect their servers against threats while maintaining a comprehensive view of their security posture. Microsoft Defender for Servers emerges as a vital component, playing a pivotal role in protecting servers from threats and providing unparalleled visibility into their security landscape.

Microsoft Defender for Servers ensures that Contoso Supermarket's Azure Arc-enabled servers remain resilient against a wide range of cyber threats. With advanced threat protection, machine learning algorithms, and real-time security intelligence, Microsoft Defender for Servers proactively detects and neutralizes potential risks.

On the other hand, maintaining visibility into the security posture of Azure Arc-enabled servers is crucial for Contoso Supermarket. Microsoft Defender for Servers offers comprehensive insights into the servers' security status, providing a centralized view of threats, vulnerabilities, and security events. By analyzing telemetry data, logs, and behavioral patterns, Contoso Supermarket gains a deep understanding of their security landscape, enabling proactive risk mitigation.

## Enable Microsoft Defender for Servers

To protect workloads with Microsoft Defender for Servers, you will need to enable its Servers plan at subscription level. Follow these steps, if it is not already enabled:

- Login to AZ CLI using the ```az login``` command.

- Ensure that you have selected the correct subscription by using the ```az account list --query "[?isDefault]"``` command. If you need to adjust the active subscription used by Az CLI, follow [this guidance](https://docs.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription).

- Run the following command to check whether Microsoft Defender for Servers is already enabled in your subscription or not:

    ```shell
    az security pricing show -n VirtualMachines
    ```

    ![Screenshot of checking microsoft defender for servers enabled at subscription level](./img/01.png)

    > **NOTE: Proceed with the next step if the value you have got for _pricingTier_ is equals to _Free_. If the value was _Standard_, Microsoft Defender for Servers is already enabled and no additional action is required.**

- Run the following command to enable Microsoft Defender for Servers in your subscription:

    ```shell
    az security pricing create -n VirtualMachines --tier 'standard'
    ```

    ![Screenshot of enabling microsoft defender for servers  at subscription level](./img/02.png)

    > **NOTE: Remember to follow the steps provided in the Cleanup section to disable Microsoft Defender for Servers.**

## Azure Arc-enabled servers and Microsoft Defender for Servers Integration

Now that you have successfully enabled Microsoft Defender for Servers, you will get recommendations to help you protect your resources, including your Azure Arc-enabled servers.

Microsoft Defender for Servers will collect data from your Arc-enabled servers to monitor for security vulnerabilities and threats. The data collection will allow greater visibility into missing updates, non-secure OS settings, endpoint protection status, health and threat protection.

>**NOTE: it may take up to 30 minutes for your Azure Arc-enabled server to be shown in Microsoft Defender for Cloud Dashboard**

- Navigate to Microsoft Defender for Cloud. In the **Inventory** section under **VM and Servers**, Defender will provide you with an overview of all the discovered security recommendations for your **Azure Arc-enabled servers**.

    ![Screenshot of Microsoft Defender for Cloud Inventory](./img/03.png)

- Select one of the Azure Arc-enabled servers. Microsoft Defender for Cloud will show the security recommendations:

    ![Screenshot of Microsoft Defender for Cloud Recommendations](./img/04.png)

- Select one of the recommendations. Each recommendation will include:
  - A short description of what is being recommended.
  - Related recommendations.
  - The remediation steps to carry out in order to implement the recommendation. For specific recommendations, you may also get a **_Quick Fix_** that enables you to quickly remediate a recommendation on multiple resources.

    ![Screenshot of Defender recommendation on Azure Arc-enabled server](./img/05.png)

- For this Azure Arc-enabled server the recommendation _Machines should be configured to periodically check for missing system updates_ provides a **_Quick Fix_**. It is using an ARM template to enable a periodic update assessment on the Azure Arc-enabled server.

    ![Screenshot of Defender recommendation Quick Fix ARM template](./img/06.png)

- You can trigger the remediation by clicking on the **_Fix_** button:  

    ![Screenshot of Defender recommendation Fix button](./img/07.png)

- After you apply the recommendation, it will be now marked as healthy. Note that It can take several minutes after remediation completes to see the resources in the 'healthy resources' tab

    ![Screenshot showing healthy Azure Arc-enabled server](./img/08.png)

## Cleanup

> **NOTE: Proceed with the next steps if Microsoft Defender for Servers in your subscription was set to _Free_.**

- Login to AZ CLI using the ```az login``` command.

- Ensure that you have selected the correct subscription by using the ```az account list --query "[?isDefault]"``` command. If you need to adjust the active subscription used by Az CLI, follow [this guidance](https://docs.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription).

- Run the following command to disable Microsoft Defender for Servers in your subscription:

    ```shell
    az security pricing create -n VirtualMachines --tier 'free'
    ```

    ![Disable microsoft defender for servers  at subscription level](./img/09.png)
