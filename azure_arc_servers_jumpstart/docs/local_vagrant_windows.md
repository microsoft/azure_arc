# Onboard a local Windows server hosted with Vagrant into Azure Arc

The following README will guide you on how to deploy a local "Ready to Go" **Windows 10** virtual machine using [Vagrant](https://www.vagrantup.com/) and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

    ```terminal
    git clone https://github.com/microsoft/azure_arc.git
    ```
    
* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Vagrant relies on an underlying hypervisor. For the purpose of this guide, we will be using "Oracle VM VirtualBox".

    * Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads). 
    
        - If you are an OSX user, simply run ```brew cask install virtualbox```
        - If you are a Windows user, you can use the [Chocolatey package](https://chocolatey.org/packages/virtualbox)
        - If you are a Linux user, all package installation methods can be found [here](https://www.virtualbox.org/wiki/Linux_Downloads)

    * Install [Vagrant](https://www.vagrantup.com/docs/installation/)

        - If you are an OSX user, simply run ```brew cask install vagrant``` 
        - If you are a Windows user, you can use the [Chocolatey package](https://chocolatey.org/packages/vagrant)
        - If you are a Linux user, look [here](https://www.vagrantup.com/downloads.html)

* Create Azure Service Principal (SP)   

    To connect the Vagrant virtual machine to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

    ```bash
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor```

    Output should look like this:

    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

* The Vagrantfile executes a script on the VM OS to install all the needed artifacts as well to inject environment variables. Edit the [*scripts/vars.ps1*](../local/vagrant/windows/scripts/vars.ps1) Powershell script to match the Azure Service Principle you've just created. 

    * subscriptionId=Your Azure Subscription ID
    * appId=Your Azure Service Principle name
    * password=Your Azure Service Principle password
    * tenantId=Your Azure tenant ID
    * resourceGroup=Azure Resource Group Name
    * location=Azure Region

# Deployment

Like any Vagrant deployment, a [*Vagrantfile*](../local/vagrant/windows/Vagrantfile) and a [Vagrant Box](https://www.vagrantup.com/docs/boxes.html) is needed. At a high-level, the deployment will:

1. Download the Windows 10 image file [Vagrant Box](https://app.vagrantup.com/StefanScherer/boxes/windows_10)
2. Execute the Arc installation script

After editing the ***scripts/vars.ps1*** script to match your environment, from the *Vagrantfile* folder, run ```vagrant up```. As this is the first time you are creating the VM, the first run will be **much slower** than the ones to follow. This is because the deployment is downloading the Windows 10 box for the first time.

![](../img/local_vagrant_windows/01.png)

Once the download is complete, the actual provisioning will start. As you can see in the screenshot below, the process takes can take somewhere between 7 to 10 minutes. 

![](../img/local_vagrant_windows/02.png)

Upon completion, you will have a local Windows 10 VM deployed, connected as a new Azure Arc server inside a new Resource Group. 

![](../img/local_vagrant_windows/03.png)

![](../img/local_vagrant_windows/04.png)

# Semi-Automated Deployment (Optional)

As you may noticed, the last step of the run is to register the VM as a new Arc server resource. 

![](../img/local_vagrant_windows/05.png)

In a case you want to demo/control the actual registration process, to the following: 

1. In the [*install_arc_agent*](../local/vagrant/windows/scripts/install_arc_agent.ps1) Powershell script, comment out the "Run connect command" section and save the file. You can also comment out or change the creation of the Resource Group. 

![](../img/local_vagrant_windows/06.png)

![](../img/local_vagrant_windows/07.png)

2. RDP the VM using the ```vagrant rdp``` command. Use *vagrant/vagrant* as the username/password. 

![](../img/local_vagrant_windows/08.png)

3. Open Powershell ISE **as Administrator** and edit the *C:\runtime\vars.ps1* with your environment variables. 

![](../img/local_vagrant_windows/09.png)

4. Paste the ```Invoke-Expression "C:\runtime\vars.ps1"``` commmand, the ```az group create --location $env:location --name $env:resourceGroup --subscription $env:subscriptionId``` command and the same *azcmagent connect* command you've just commented and execute the script. 

![](../img/local_vagrant_windows/10.png)

# Delete the deployment

To delete the entire deployment, run the ```vagrant destroy -f``` command. The Vagrantfile includes a *before: destroy* Vagrant trigger which will run the command to delete the Azure Resource Group before destroying the actual VM. That way, you will be starting fresh next time. 

![](../img/local_vagrant_windows/11.png)