# Scale Onboarding VMware Windows Server VMs to Azure Arc

The following README will guide you on how to use the provided [VMware PowerCLI](https://code.vmware.com/web/dp/tool/vmware-powercli/) script so you can perform an automated scaled deployment of the "Azure Arc Connected Machine Agent" in multiple VMware vSphere virtual machines and as a result, onboarding these VMs as an Azure Arc enabled Servers.

This guide assumes you already have an exiting inventory of VMware Virtual Machines and will leverage the PowerCLI PowerShell module for automating the onboarding process of the VMs to Azure Arc. 

# Prerequisites

* Clone this repo

    ```console
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Install VMware PowerCLI

    - **Note: This guide was tested with the latest version of PowerCLI as of date (12.0.0) but earlier versions are expected to work as well**

    - Supported PowerShell Versions - VMware PowerCLI 12.0.0 is compatible with the following PowerShell versions:
        - Windows PowerShell 5.1
        - PowerShell 7

    - Detailed installation instructions can be found [here](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html) but the easiest way is to use the VMware.PowerCLI module from the PowerShell Gallery using the below command.

        ```powershell
        Install-Module -Name VMware.PowerCLI
        ```

* To be able to read the VM inventory from vCenter as well as invoke a script on the VM OS-level, the following permissions are needed:
    
    - [VirtualMachine.GuestOperations](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.security.doc/GUID-6A952214-0E5E-4CCF-9D2A-90948FF643EC.html) user account

    - VMware vCenter Server user assigned with a ["Read Only Role"](https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.security.doc/GUID-93B962A7-93FA-4E96-B68F-AE66D3D6C663.html)

* Create Azure Service Principal (SP)   

    To connect the VMware vSphere virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```console
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```console
    az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor
    ```

    Output should look like this:

    ```console
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Automation Flow

Below you can find the automation flow for this scenario:

1. User edit the *vars.ps1* PowerCLI script

2. The script execution will initiate authentication against vCenter and will scan the targeted VM folder where Azure Arc candidate VMs are located and will copy both the *vars.ps1* and the *install_arc_agent.ps1* PowerCLI scripts to VM Windows OS located in [this folder](../vmware/scale_deploy/powercli/windows) to each VM in that folder.

3. The *install_arc_agent.ps1* PowerCLI script will run on the VM guest OS and will install the "Azure Arc Connected Machine Agent" in order to onboard the VM to Azure Arc

# Post Deployment

The demonstrate the before & after for this scenario, the below screenshots shows a dedicated, empty Azure Resources Group, a vCenter VM folder with candidate VMs and the "Apps & features" view in Windows showing no agent is installed.

![](../img/vmware_scale_powercli_win/01.png)

![](../img/vmware_scale_powercli_win/02.png)

![](../img/vmware_scale_powercli_win/03.png)

# Deployment

Before running the PowerCLI script, you must set the [environment variables](../vmware/scale_deploy/powercli/windows/vars.ps1) which will be used by the *install_arc_agent.ps1* script. These variables are based on the Azure Service Principal you've just created, your Azure subscription and tenant, and your VMware vSphere credentials and data.

* Retrieve your Azure Subscription ID and tenant ID using the ```az account list``` command

* Use the Azure Service Principal ID and password created in the prerequisites section

![](../img/vmware_scale_powercli_win/04.png)

* From the [*azure_arc_servers_jumpstart\vmware\scale_deploy\powercli\windows*](../vmware/scale_deploy/powercli/windows) folder, open PowerShell session as an Administrator and run the *scale_deploy.ps1* script.

![](../img/vmware_scale_powercli_win/05.png)

![](../img/vmware_scale_powercli_win/06.png)

![](../img/vmware_scale_powercli_win/07.png)

* Upon completion, the VM will have the "Azure Arc Connected Machine Agent" installed as well as the Azure Resource Group populated with the new Azure Arc enabled Servers.

![](../img/vmware_scale_powercli_win/08.png)

![](../img/vmware_scale_powercli_win/09.png)

![](../img/vmware_scale_powercli_win/10.png)
