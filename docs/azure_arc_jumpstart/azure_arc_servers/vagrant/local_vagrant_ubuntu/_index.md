---
type: docs
title: "Ubuntu Vagrant box"
linkTitle: "Ubuntu Vagrant box"
weight: 1
description: >
---

## Deploy a local Ubuntu server hosted with Vagrant and connect it Azure Arc

The following README will guide you on how to deploy a local **Ubuntu** virtual machine using [Vagrant](https://www.vagrantup.com/) and connect it as an Azure Arc-enabled server resource.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.15.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* Vagrant relies on an underlying hypervisor. For the purpose of this guide, we will be using "Oracle VM VirtualBox".

  * Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

    * If you are an OSX user, simply run ```brew cask install virtualbox```
    * If you are a Windows user, you can use the [Chocolatey package](https://chocolatey.org/packages/virtualbox)
    * If you are a Linux user, all package installation methods can be found [here](https://www.virtualbox.org/wiki/Linux_Downloads)

  * Install [Vagrant](https://www.vagrantup.com/docs/installation/)

    * If you are an OSX user, simply run ```brew cask install vagrant```
    * If you are a Windows user, you can use the [Chocolatey package](https://chocolatey.org/packages/vagrant)
    * If you are a Linux user, look [here](https://www.vagrantup.com/downloads.html)

* Create Azure service principal (SP)

    To connect the Vagrant virtual machine to Azure Arc, an Azure service principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcServers",
    "name": "http://AzureArcServers",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)**

* Azure Arc-enabled servers depends on the following Azure resource providers in your subscription in order to use this service. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  * Microsoft.HybridCompute
  * Microsoft.GuestConfiguration

      ```shell
      az provider register --namespace 'Microsoft.HybridCompute'
      az provider register --namespace 'Microsoft.GuestConfiguration'
      ```

      You can monitor the registration process with the following commands:

      ```shell
      az provider show --namespace 'Microsoft.HybridCompute'
      az provider show --namespace 'Microsoft.GuestConfiguration'
      ```

* The Vagrantfile executes a script on the VM OS to install all the needed artifacts as well to inject environment variables. Edit the [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/local/vagrant/ubuntu/scripts/vars.sh) shell script to match the Azure service principal you've just created.

  * subscriptionId=Your Azure subscription ID
  * appId=Your Azure service principal name
  * password=Your Azure service principal password
  * tenantId=Your Azure tenant ID
  * resourceGroup=Azure resource group name
  * location=Azure region

## Deployment

Like any Vagrant deployment, a [*Vagrantfile*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/local/vagrant/ubuntu/Vagrantfile) and a [Vagrant Box](https://www.vagrantup.com/docs/boxes.html) is needed. At a high-level, the deployment will:

1. Download the Ubuntu 16.04 image file [Vagrant Box](https://app.vagrantup.com/ubuntu/boxes/xenial64)
2. Execute the installation script

After editing the ***scripts/vars.sh*** script to match your environment, from the *Vagrantfile* folder, run ```vagrant up```. As this is the first time you are creating the VM, the first run will be **much slower** than the ones to follow. This is because the deployment is downloading the Ubuntu box for the first time.

![Screenshot of vagrant up being run](./01.png)

Once the download is complete, the actual provisioning will start. As you can see in the screenshot below, the process takes no longer than 3 minutes.

![Screenshot of completed vagrant up](./02.png)

Upon completion, you will have a local Ubuntu VM deployed, connected as a new Azure Arc-enabled server inside a new resource group.

![Screenshot of Azure portal showing Azure Arc-enabled server](./03.png)

![Screenshot of Azure portal showing Azure Arc-enabled server detail](./04.png)

## Semi-Automated Deployment (Optional)

As you may noticed, the last step of the run is to register the VM as a new Azure Arc-enabled server resource.

![Screenshot of vagrant up being run](./05.png)

In a case you want to demo/control the actual registration process, to the following:

* In the [*install_arc_agent*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/local/vagrant/ubuntu/scripts/install_arc_agent.sh) shell script, comment out the "Run connect command" section and save the file. You can also comment out or change the creation of the resource group.

    ![Screenshot of the azcmagent connect command](./06.png)

    ![Screenshot of the az group create command](./07.png)

* SSH the VM using the ```vagrant ssh``` command.

    ![Screenshot of of SSH to the Vagrant machine](./08.png)

* Run the same *azcmagent connect* command you've just commented out using your environment variables.

    ![Screenshot of the azcmagent connect](./09.png)

## Delete the deployment

To delete the entire deployment, run the ```vagrant destroy -f``` command. The Vagrantfile includes a *before: destroy* Vagrant trigger which will run a script to delete the Azure resource group before destroying the actual VM. That way, you will be starting fresh next time.

![Screenshot of vagrant destroy being run](./10.png)
