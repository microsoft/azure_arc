# Create a VMWare vSphere template for Ubuntu Server 18.04

The following README will guide you on how to create an Ubuntu Server 18.04 VMware vSphere virtual machine template. 

# Prerequisites

**Note:** This guide assumes that you have some VMware vSphere familiarity. It is also does not designed to go over either VMware and/or Ubuntu best-practices. 

* [Download the latest Ubuntu Server 18.04 ISO file](https://releases.ubuntu.com/18.04/)

* VMware vSphere 6.5 and above

* Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library. 

# Creating Ubuntu 18.04 VM Template

## Deploying & Installing Ubuntu

![](../img/vmware_ubuntu_template/01.png)

![](../img/vmware_ubuntu_template/02.png)

![](../img/vmware_ubuntu_template/03.png)

![](../img/vmware_ubuntu_template/04.png)

![](../img/vmware_ubuntu_template/05.png)

![](../img/vmware_ubuntu_template/06.png)

Make sure to select *Ubuntu Linux (64-bit)* as the Guest OS. 

![](../img/vmware_ubuntu_template/07.png)

Point to the Ubuntu Server ISO file location. 

![](../img/vmware_ubuntu_template/08.png)

![](../img/vmware_ubuntu_template/09.png)

Power-on the VM and start the Ubuntu installation. No specific instructions here but:
1. (Optional) Consider using static IP 
2. Install OpenSSH server

![](../img/vmware_ubuntu_template/10.png)

![](../img/vmware_ubuntu_template/11.png)

![](../img/vmware_ubuntu_template/12.png)

![](../img/vmware_ubuntu_template/13.png)

![](../img/vmware_ubuntu_template/14.png)

![](../img/vmware_ubuntu_template/15.png)

![](../img/vmware_ubuntu_template/16.png)

![](../img/vmware_ubuntu_template/17.png)

![](../img/vmware_ubuntu_template/18.png)

![](../img/vmware_ubuntu_template/19.png)

![](../img/vmware_ubuntu_template/20.png)

![](../img/vmware_ubuntu_template/21.png)

![](../img/vmware_ubuntu_template/22.png)

![](../img/vmware_ubuntu_template/23.png)

![](../img/vmware_ubuntu_template/24.png)

![](../img/vmware_ubuntu_template/25.png)

![](../img/vmware_ubuntu_template/26.png)

![](../img/vmware_ubuntu_template/27.png)

![](../img/vmware_ubuntu_template/28.png)

![](../img/vmware_ubuntu_template/29.png)

![](../img/vmware_ubuntu_template/30.png)

## Post-installation 

Before converting the VM to a template, few actions are needed.

* It's better to have your OS packages up-to-date

    ```bash
    sudo apt-get update
    sudo apt-get upgrade -y
    ```

* Prevent cloudconfig from preserving the original hostname and reset the hostname

    ```bash
    sudo sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
    sudo truncate -s0 /etc/hostname
    sudo hostnamectl set-hostname localhost
    ```

* Remove the current network configuration

    ```bash
    sudo rm /etc/netplan/50-cloud-init.yaml
    ```

* Clean shell history and shutdown the VM

    ```bash
    cat /dev/null > ~/.bash_history && history -c
    sudo shutdown now
    ```

## Convert to Template

Reduce the CPU & Memory resources to the minimum and convert the VM to template.

![](../img/vmware_ubuntu_template/31.png)

![](../img/vmware_ubuntu_template/32.png)