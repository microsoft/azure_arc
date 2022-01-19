---
type: docs
title: "Create Windows vSphere template"
linkTitle: "Create Windows vSphere template"
weight: 1
description: >
---

## Create a VMware vSphere template for Windows Server 2019

The following README will guide you on how to create a Windows Server 2019 VMware vSphere virtual machine template.

## Prerequisites

> **Note: This guide assumes that you have some VMware vSphere familiarity and you have knowledge on how to install Windows Server. It is also does not designed to go over either VMware and/or Windows best-practices.**

- [Download the latest Windows Server ISO file](https://www.microsoft.com/en-us/windows-server/trial)

- VMware vSphere 6.5 and above

- Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library.

## Creating Windows Server 2019 VM Template

### Deploying & Installing Windows Server

- Deploy new virtual machine

    ![Create new VMware vSphere VM](./01.png)

    ![Create new VMware vSphere VM](./02.png)

    ![Create new VMware vSphere VM](./03.png)

    ![Create new VMware vSphere VM](./04.png)

    ![Create new VMware vSphere VM](./05.png)

    ![Create new VMware vSphere VM](./06.png)

- Make sure to select _Microsoft Windows Server 2016 or later (64-bit)_ as the Guest OS.

    ![Windows Server Guest OS](./07.png)

- Point to the Windows Server ISO file location.

    ![Create new VMware vSphere VM](./08.png)

    ![Create new VMware vSphere VM](./09.png)

- Power-on the VM and start the Windows Server installation.

    ![Power-on the VM](./10.png)

    ![Windows Server installation](./11.png)

    ![Windows Server installation](./12.png)

    ![Windows Server installation](./13.png)

    ![Windows Server installation](./14.png)

    ![Windows Server installation](./15.png)

    ![Windows Server installation](./16.png)

### Post-installation

Before converting the VM to a template, few actions needs to be taken.

- Install VMware Tools & Restart

    ![Install VMware Tools](./17.png)

    ![Install VMware Tools](./18.png)

    ![Install VMware Tools](./19.png)

    ![Install VMware Tools](./20.png)

    ![Install VMware Tools](./21.png)

    ![Install VMware Tools](./22.png)

    ![Install VMware Tools](./23.png)

    ![Install VMware Tools](./24.png)

    ![Install VMware Tools](./25.png)

- Perform Windows Updates

- Change PowerShell Execution Policy to "bypass" by running the ```Set-ExecutionPolicy -ExecutionPolicy Bypass``` command in PowerShell (can be later tuned on via Group Policy or a PowerShell script).

- Allow WinRM communication to the OS buy running the [_allow_winrm_](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/vmware/winsrv/terraform/scripts/allow_winrm.ps1) PowerShell script.

- None of the below are mandatory but should be considered for a Windows Template:

  - Disabling User Account Control (can be later tuned on via Group Policy or a PowerShell script)
  - Turn off Windows Defender FW (can be later tuned on via Group Policy or a PowerShell script)
  - Disabling Internet Explorer Enhanced Security Configuration (ESC) (can be later tuned on via Group Policy or a PowerShell script)
  - Enable Remote Desktop
  - In PowerShell, install [Chocolaty](https://chocolatey.org/install)

    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    ```

  - Install all baseline apps you may want to include in your template.

### Convert to Template

Reduce the VM CPU count & memory resources to the minimum and convert the VM to template, switch the CD/DVD drive to client device as well disconnect it and convert the VM to template.

![Reduce the VM CPU count & Memory](./26.png)

![Convert the VM to template](./27.png)
