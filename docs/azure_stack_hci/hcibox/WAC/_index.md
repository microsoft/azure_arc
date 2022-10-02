---
type: docs
weight: 200
toc_hide: true
---

# Jumpstart HCIBox - Azure Kubernetes Service on Azure Stack HCI operations

## Accessing Windows Admin Center

HCIBox includes a deployment of [Windows Admin Center as a gateway server](https://learn.microsoft.com/windows-server/manage/windows-admin-center/plan/installation-options). A shortcut to the Windows Admin Center (WAC) gateway server is available on the _HCIBox-Client_ desktop.

- Open this shortcut and use the domain credential (username_supplied_at_deployment@jumpstart.local) to start an RDP session to the Windows Admin Center VM.

  [Screenshot showing WAC desktop shortcut]()

  [Screenshot showing the WAC desktop]()

- Now you can open the Windows Admin Center shortcut on the desktop. Once again you will use your domain account to access WAC.

  [Screenshot showing logging into WAC]()

  [Screenshot showing WAC]()

- Our first step is to add a connection to our HCI cluster. Click on "Add cluster" and supply the name "hciboxcluster" as seen in the screenshots below.

  [Screenshot showing adding the cluster #1]()

  [Screenshot showing adding the cluster #2]()

  [Screenshot showing adding the cluster #3]()

  [Screenshot showing adding the cluster #4]()

- Now that the cluster is added, we can explore management capabilities for the cluster inside of WAC. Click on "Virtual Machines"

  [Screenshot showing Virtual Machines inside WAC]()

- If you followed the previous steps to deploy a VM from Azure portal, you should see that VM here inside of Windows Admin Center. Click on it. 

  [Screenshot showing the VM we created earlier]()

- Windows Admin Center also provides the ability to connect directly to the VM. Click "Connect" and login with the credentials you supplied when creating the VM.

  [Screenshot showing connecting to the VM]()

  [Screenshot showing the console of the running VM]()

- We can also seamlessly move the VM from one cluster node to another using [live migration](https://learn.microsoft.com/windows-server/virtualization/hyper-v/manage/live-migration-overview). TEXT TO START LIVE MIGRATION.

  [Screenshot showing live migration step 1]()

  [Screenshot showing live migration step 2]()