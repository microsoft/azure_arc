---
type: docs
weight: 100
toc_hide: true
---

# Jumpstart HCIBox - Virtual machine provisioning with Azure Arc

Azure Stack HCI supports [VM provisioning the Azure portal](https://learn.microsoft.com/azure-stack/hci/manage/azure-arc-enabled-virtual-machines). HCIBox is pre-configured with [Arc resource bridge](https://learn.microsoft.com/azure-stack/hci/manage/azure-arc-enabled-virtual-machines#what-is-azure-arc-resource-bridge) to support this capability.

  > **NOTE: Resource bridge only supports deploying a guest VM with DHCP IP assignment. HCIBox runs a simple DHCP server that provides IP addresses to VMs created with resource bridge. The DHCP range is 192.168.200.210 - 192.168.200.249. Static assignment of IP from the Azure portal is not supported at this time.**

## Deploy a new Linux virtual machine

HCIBox includes a pre-configured Linux virtual machine image that you can use to deploy new guest virtual machines on the HCI cluster. Follow these steps to deploy one in your HCIBox.

- Navigate to the Azure Stack HCI cluster resource in your HCIBox resource group.

  ![Screenshot showing Azure Stack HCI cluster in RG](./hcicluster_rg.png)

- Click on "Virtual Machines" in the navigation menu, then click "Create VM"

  ![Screenshot showing Azure Stack HCI cluster resource blade](./hcicluster_create_vm.png)

  ![Screenshot showing Create VM blade](./hcicluster_create_vm_blade.png)

- Provide a name for the VM, select the _ubuntu20_ image, and set the virtual processor count to 1 and the memory count to 2.

  ![Screenshot showing select gallery image](./create_vm_detail_1.png)

- Click the Networking tab of the create wizard, then click Add network interface.

  ![Screenshot showing network tab of create vm wizard](./create_vm_detail_2.png)

- Give the new network interface a name and select _sdnswitch_ in the Network dropdown, then click Add.

  ![Screenshot showing create NIC tab of create vm wizard](./create_vm_detail_3.png)

  ![Screenshot showing NIC was created](./create_vm_detail_4.png)

- Click the Review + Create tab and then click Create.

  ![Screenshot showing Review and Create tab](./create_vm_detail_5.png)

- Download the private key and save it to your local computer.

  ![Screenshot showing download the private key](./create_vm_detail_6.png)

- Wait for the deployment to complete.

  ![Screenshot showing deployment in progress](./create_vm_detail_7.png)

  ![Screenshot showing deployment complete](./create_vm_detail_8.png)

- Navigate back to the HCI cluster Virtual machines tab to view your created VM.

  ![Screenshot showing created VM](./created_vm.png)

- Click on the VM to drill into the Azure Arc-enabled HCI machine detail.

  ![Screenshot showing created VM detail](./created_vm_detail.png)

### Next steps

Review the [Arc resource bridge](https://learn.microsoft.com/azure-stack/hci/manage/azure-arc-enabled-virtual-machines#what-is-azure-arc-resource-bridge) documentation for additional information.
