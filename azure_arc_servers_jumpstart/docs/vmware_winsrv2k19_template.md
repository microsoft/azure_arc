# Create a VMWare vSphere template for Windows Server 2019

The following README will guide you on how to create a Windows Server 2019 VMware vSphere virtual machine template. 

# Prerequisites

**Note:** This guide assumes that you have some VMware vSphere familiarity and you have knowledge on how to install Windows Server. It is also does not designed to go over either VMware and/or Windows best-practices. 

* [Download the latest Windows Server ISO file](https://www.microsoft.com/en-us/windows-server/trial)

* VMware vSphere 6.5 and above

* Although it can be used locally, for faster deployment, it is recommended to upload the file to a vSphere datastore or to vCenter Content Library. 

# Creating Windows Server 2019 VM Template

## Deploying & Installing Windows Server

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

![](../img/vmware_winsrv2k19_template/11.png)

![](../img/vmware_winsrv2k19_template/12.png)

![](../img/vmware_winsrv2k19_template/13.png)

![](../img/vmware_winsrv2k19_template/14.png)

![](../img/vmware_winsrv2k19_template/15.png)

![](../img/vmware_winsrv2k19_template/16.png)

## Post-installation 

Before converting the VM to a template, few actions needs to be taken.

* Install VMware Tools & Restart

![](../img/vmware_winsrv2k19_template/17.png)

![](../img/vmware_winsrv2k19_template/18.png)

![](../img/vmware_winsrv2k19_template/19.png)

![](../img/vmware_winsrv2k19_template/20.png)

![](../img/vmware_winsrv2k19_template/21.png)

![](../img/vmware_winsrv2k19_template/22.png)

![](../img/vmware_winsrv2k19_template/23.png)

![](../img/vmware_winsrv2k19_template/24.png)

![](../img/vmware_winsrv2k19_template/25.png)

* Perform Windows Updates

* Change Powershell Execution Policy to "bypass" by running the ```Set-ExecutionPolicy -ExecutionPolicy Bypass``` command in Powershell (can be later tuned on via Group Policy or a Powershell script).

* Allow WinRM communication to the OS buy running the [*allow_winrm*](../vmware/winsrv/terraform/scripts/allow_winrm.ps1) Powershell script. 

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

## Convert to Template

Reduce the CPU & Memory resources, switch the CD/DVD drive to client device as well disconnect it and convert the VM to template.

![](../img/vmware_winsrv2k19_template/26.png)

![](../img/vmware_winsrv2k19_template/27.png)