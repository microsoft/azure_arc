---
title: "Create a VMware vSphere template for Ubuntu Server 18.04"
linkTitle: "Create a VMware vSphere template for Ubuntu Server 18.04"
weight: 1
description: >
---

# Create a VMware vSphere template for Ubuntu Server 18.04

The following README will guide you on how to create an Ubuntu Server 18.04 VMware vSphere virtual machine template. 

## Prerequisites

**Note:** This guide assumes that you have some VMware vSphere familiarity. It is also does not designed to go over either VMware and/or Ubuntu best-practices. 

* [Download the latest Ubuntu Server 18.04 ISO file](https://releases.ubuntu.com/18.04/)

* VMware vSphere 6.5 and above

* Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library. 

## Creating Ubuntu 18.04 VM Template

### Deploying & Installing Ubuntu

![](./01.png)

![](./02.png)

![](./03.png)

![](./04.png)

![](./05.png)

![](./06.png)

Make sure to select *Ubuntu Linux (64-bit)* as the Guest OS. 

![](./07.png)

Point to the Ubuntu Server ISO file location. 

![](./08.png)

![](./09.png)

Power-on the VM and start the Ubuntu installation. No specific instructions here but:
1. (Optional) Consider using static IP 
2. Install OpenSSH server

![](./10.png)

![](./11.png)

![](./12.png)

![](./13.png)

![](./14.png)

![](./15.png)

![](./16.png)

![](./17.png)

![](./18.png)

![](./19.png)

![](./20.png)

![](./21.png)

![](./22.png)

![](./23.png)

![](./24.png)

![](./25.png)

![](./26.png)

![](./27.png)

![](./28.png)

![](./29.png)

![](./30.png)

### Post-installation 

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

### Convert to Template

Reduce the CPU & Memory resources to the minimum and convert the VM to template.

![](./31.png)

![](./32.png)