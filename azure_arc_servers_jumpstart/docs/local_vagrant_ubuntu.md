# Overview

The following README will guide you on how to deploy a local "Ready to Go" Ubuntu virtual machine using [Vagrant](https://www.vagrantup.com/) and connect it as an Azure Arc server resource.

# Prerequisites

* Clone this repo

* Vagrant relies on an underline hypervisor. For the purpose of this guide, we will be using "Oracle VM VirtualBox".

    * Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads). 
    
        - If you are an OSX user, simply run ```brew cask install virtualbox```
        - If you are a Windows user, you can use a the [Chocolatey package](https://chocolatey.org/packages/virtualbox)
        - If you are a Linux user, all package installation methods can be found [here](https://www.virtualbox.org/wiki/Linux_Downloads)

    * Install [Vagrant](https://www.vagrantup.com/docs/installation/)

        - If you are an OSX user, simply run ```brew cask install vagrant``` 
        - If you are a Windows user, you can use a the [Chocolatey package](https://chocolatey.org/packages/vagrant)
        - If you are a Linux user, look [here](https://www.vagrantup.com/downloads.html)

* Create Azure Service Principal (SP)   

    To connect the VM to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

    ```az login```

    ```az ad sp create-for-rbac -n "http://AzureArc" --role contributor```

    Output should look like this:
    ```
    {
    "appId": "aedXXXXXXXXXXXXXXXXXXac661",
    "displayName": "AzureArcServer",
    "name": "http://AzureArcServer",
    "password": "b54XXXXXXXXXXXXXXXXXb2338e",
    "tenant": "72f98XXXXXXXXXXXXXXXXX11db47"
    }
    ```
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

* The Vagrantfile execute a script on the VM OS to install all the needed artifacts as well to inject environment variables. Edit the ***scripts/vars.sh*** to match the Azure Service Principle you've just created. 

    * subscriptionId=Your Azure Subscription ID
    * appId=Your Azure Service Principle name
    * password=Your Azure Service Principle password
    * tenantId=Your Azure tenant ID
    * resourceGroup=Azure Resource Group Name
    * location=Azure Region

# Deployment

Like any Vagrant deployment, a *Vagrantfile* and a [Vagrant Box](https://www.vagrantup.com/docs/boxes.html) is needed. At a high-level, the deployment will:

1. Download the Ubuntu 16.04 [Vagrant Box](https://app.vagrantup.com/ubuntu/boxes/xenial64)
2. Execute the Arc installation script

After editing the ***scripts/vars.sh*** to match your environment, from the *Vagrantfile* folder, run ```vagrant up```. As this is the first time you are creating the VM, the first run will be slower then the ones to follow. This is because the deployment is downloading the Ubuntu box for the first time.

![](../img/local_vagrant_ubuntu/01.png)

Once the download is complete, the actual provisioning will start. As you can see in the screenshot below, the process takes no longer then 3min!

![](../img/local_vagrant_ubuntu/02.png)

Upon completion, you will have a local Ubuntu VM deployed, connected as a new Azure Arc server inside a new Resource Group. 

![](../img/local_vagrant_ubuntu/03.png)

![](../img/local_vagrant_ubuntu/04.png)