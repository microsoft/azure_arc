---
type: docs
title: "Ubuntu Vagrant box"
linkTitle: "Ubuntu Vagrant box"
weight: 1
description: >
---

## Deploy a local Ubuntu server hosted with Vagrant and connect it to Azure Arc

The following doc will guide you through deploying a local **Ubuntu** virtual machine using [Vagrant](https://www.vagrantup.com/) and connecting it as an Azure Arc-enabled server resource.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* Enable subscription with the resource provider for Azure Arc-enabled Servers. Registration is an asynchronous process, and it could take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.HybridCompute
  ```

You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.HybridCompute -o table
  ```

* Vagrant relies on an underlying hypervisor. For this guide, we will be using "Oracle VM VirtualBox."

  * Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

    * On OSX, run ```brew cask install virtualbox```.
    * On Windows, you can use the [Chocolatey package](https://chocolatey.org/packages/virtualbox).
    * On Linux, you can find various installation methods [here](https://www.virtualbox.org/wiki/Linux_Downloads).

  * Install [Vagrant](https://www.vagrantup.com/docs/installation/).

    * On OSX, run ```brew cask install vagrant```.
    * On Windows, you can use the [Chocolatey package](https://chocolatey.org/packages/vagrant).
    * On Linux, look [here](https://www.vagrantup.com/downloads.html).

* Create Azure service principal (SP)

    An Azure service principal assigned with the "Contributor" role is needed to connect the Vagrant virtual machine to Azure Arc. To create it, log in to your Azure account run the below command (you could also do this in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
    ```

    For example:

    ```shell
    az ad sp create-for-rbac -n "http://AzureArcServers" --role contributor
    ```

    The output should look like this:

    ```json
    {
      "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
      "displayName": "AzureArcServers",
      "name": "http://AzureArcServers",
      "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
      "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **Note: The Jumpstart scenarios are designed with ease of use in mind and adhering to security-related best practices wherever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest). As well as consider using a [less privileged service principal account](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)**.

* The Vagrantfile executes a script on the VM OS to install all the needed artifacts. To inject environment variables, edit the [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/local/vagrant/ubuntu/scripts/vars.sh) shell script to match the Azure service principal you've just created.

  * subscriptionId=Your Azure subscription ID
  * appId=Your Azure service principal name
  * password=Your Azure service principal password
  * tenantId=Your Azure tenant ID
  * resourceGroup=Azure resource group name
  * location=Azure region

## Deployment

Like any Vagrant deployment, a [*Vagrantfile*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_servers_jumpstart/local/vagrant/ubuntu/Vagrantfile) and a [Vagrant Box](https://www.vagrantup.com/docs/boxes.html) are needed. At a high level, the deployment will:

1. Download the Ubuntu 16.04 image file [Vagrant Box](https://app.vagrantup.com/ubuntu/boxes/xenial64)
2. Execute the installation script

After editing the ***scripts/vars.sh*** script to match your environment, from the *Vagrantfile* folder, run ```vagrant up```. The first run could be **slower** because Vagrant downloads the Ubuntu box for the first time.

![Screenshot of vagrant up being run](./01.png)

Once the download is complete, the actual provisioning will start. As you can see in the screenshot below, the process takes no longer than 3 minutes.

![Screenshot of completed vagrant up](./02.png)

Upon completion, you will have a local Ubuntu VM deployed, connected as a new Azure Arc-enabled server inside a new resource group.

![Screenshot of Azure portal showing Azure Arc-enabled server](./03.png)

![Screenshot of Azure portal showing Azure Arc-enabled server detail](./04.png)

## Semi-Automated Deployment (Optional)

As you may notice, the last step of the run is to register the VM as a new Azure Arc-enabled server resource.

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

To delete the entire deployment, run the ```vagrant destroy -f``` command. The Vagrantfile includes a *before: destroy* Vagrant trigger, which will run a script to delete the Azure resource group before destroying the actual VM. That way, you will be starting fresh next time.

![Screenshot of vagrant destroy being run](./10.png)
