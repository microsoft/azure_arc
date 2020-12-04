---
title: "Create a VMware vSphere template for Windows Server 2019"
linkTitle: "Create a VMware vSphere template for Windows Server 2019"
weight: 1
description: >
---

# Create a VMware vSphere template for Windows Server 2019

The following README will guide you on how to create a Windows Server 2019 VMware vSphere virtual machine template. 

## Prerequisites

**Note:** This guide assumes that you have some VMware vSphere familiarity and you have knowledge on how to install Windows Server. It is also does not designed to go over either VMware and/or Windows best-practices. 

* [Download the latest Windows Server ISO file](https://www.microsoft.com/en-us/windows-server/trial)

* VMware vSphere 6.5 and above

* Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library. 

## Creating Windows Server 2019 VM Template

### Deploying & Installing Windows Server

![](./01.png)

![](./02.png)

![](./03.png)

![](./04.png)

![](./05.png)

![](./06.png)

Make sure to select *Microsoft Windows Server 2016 or later (64-bit)* as the Guest OS. 

![](./07.png)

Point to the Ubuntu Server ISO file location. 

![](./08.png)

![](./09.png)

Power-on the VM and start the Windows Server installation. 

![](./10.png)

![](./11.png)

![](./12.png)

![](./13.png)

![](./14.png)

![](./15.png)

![](./16.png)

### Post-installation 

Before converting the VM to a template, few actions needs to be taken.

* Install VMware Tools & Restart

![](./17.png)

![](./18.png)

![](./19.png)

![](./20.png)

![](./21.png)

![](./22.png)

![](./23.png)

![](./24.png)

![](./25.png)

* Perform Windows Updates

* Change Powershell Execution Policy to "bypass" by running the ```Set-ExecutionPolicy -ExecutionPolicy Bypass``` command in Powershell (can be later tuned on via Group Policy or a Powershell script).

* Allow WinRM communication to the OS buy running the [*allow_winrm*](https://github.com/microsoft/azure_arc/blob/master/azure_arc_servers_jumpstart/vmware/winsrv/terraform/scripts/allow_winrm.ps1) Powershell script. 

* None of the below are mandatory but should be considered for a Windows Template:

    - Disabling User Account Control (can be later tuned on via Group Policy or a Powershell script)
    - Turn off Windows Defender FW (can be later tuned on via Group Policy or a Powershell script)
    - Disabling Internet Explorer Enhanced Security Configuration (ESC) (can be later tuned on via Group Policy or a Powershell script)
    - Enable Remote Desktop
    - In Powershell, install [Chocolaty](https://chocolatey.org/install)

        ```powershell
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        ```

    - Install all baseline apps you may want to include in your template.

### Convert to Template

Reduce the CPU & Memory resources, switch the CD/DVD drive to client device as well disconnect it and convert the VM to template.

![](./26.png)

![](./27.png)