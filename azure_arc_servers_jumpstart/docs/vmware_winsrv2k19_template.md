# Overview

The following README will guide you on how to create a Windows Server 2019 VMware vSphere virtual machine template. 

# Prerequisites

**Note:** This guide assumes that you have some VMware vSphere familiarity and you have knowledge on how to install Windows Server. It is also does not designed to go over either VMware and/or Windows best-practices. 

* [Download the latest Windows Server ISO file](https://www.microsoft.com/en-us/windows-server/trial)

* VMware vSphere 6.5 and above

* Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library. 

# Creating Windows Server 2019 VM Template

## Deploying & Installing Ubuntu

![](../img/vmware_winsrv2k19_template/01.png)

![](../img/vmware_winsrv2k19_template/02.png)

![](../img/vmware_winsrv2k19_template/03.png)

![](../img/vmware_winsrv2k19_template/04.png)

![](../img/vmware_winsrv2k19_template/05.png)

![](../img/vmware_winsrv2k19_template/06.png)

Make sure to select *Microsoft Windows Server 2016 or later (64-bit)* as the Guest OS. 

![](../img/vmware_winsrv2k19_template/07.png)

Point to the Ubuntu Server ISO file location. 

![](../img/vmware_winsrv2k19_template/08.png)

![](../img/vmware_winsrv2k19_template/09.png)

Power-on the VM and start the Windows Server installation. 

![](../img/vmware_winsrv2k19_template/10.png)



## Post-installation 

Before converting the VM to a template, few actions needs to be taken.

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