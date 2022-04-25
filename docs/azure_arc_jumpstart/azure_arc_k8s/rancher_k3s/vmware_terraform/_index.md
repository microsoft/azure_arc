---
type: docs
title: "k3s on VMware Terraform plan"
linkTitle: "k3s on VMware Terraform plan"
weight: 3
description: >
---

## Deploy Rancher k3s on a VMware vSphere VM and connect it to Azure Arc using Terraform

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy a "Ready to Go" VMware vSphere Ubuntu Server virtual machine installed with a single-master Rancher K3s Kubernetes cluster and connected it as an Azure Arc cluster resource.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.25.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html)

* A VMware vCenter Server user with [permissions to deploy](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-4D0F8E63-2961-4B71-B365-BBFA24673FDB.html) a Virtual Machine from a Template in the vSphere Web Client.

* Create Azure service principal (SP)

    To be able to complete the scenario and its related automation, Azure service principal assigned with the “Contributor” role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "<Unique SP Name>" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    For example:

    ```shell
    az login
    subscriptionId=$(az account show --query id --output tsv)
    az ad sp create-for-rbac -n "JumpstartArcK8s" --role "Contributor" --scopes /subscriptions/$subscriptionId
    ```

    Output should look like this:

    ```json
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "JumpstartArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```

    > **NOTE: If you create multiple subsequent role assignments on the same service principal, your client secret (password) will be destroyed and recreated each time. Therefore, make sure you grab the correct password**.

    > **NOTE: The Jumpstart scenarios are designed with as much ease of use in-mind and adhering to security-related best practices whenever possible. It is optional but highly recommended to scope the service principal to a specific [Azure subscription and resource group](https://docs.microsoft.com/cli/azure/ad/sp?view=azure-cli-latest) as well considering using a [less privileged service principal account](https://docs.microsoft.com/azure/role-based-access-control/best-practices)**

* [Enable subscription with](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) the two resource providers for Azure Arc-enabled Kubernetes. Registration is an asynchronous process, and registration may take approximately 10 minutes.

  ```shell
  az provider register --namespace Microsoft.Kubernetes
  az provider register --namespace Microsoft.KubernetesConfiguration
  az provider register --namespace Microsoft.ExtendedLocation
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.Kubernetes -o table
  az provider show -n Microsoft.KubernetesConfiguration -o table
  az provider show -n Microsoft.ExtendedLocation -o table
  ```

### Preparing an Ubuntu Server VMware vSphere VM Template

Before using the below guide to deploy an Ubuntu Server VM and connect it to Azure Arc, a VMware vSphere Template is required. [The following README](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/vmware_ubuntu_template/) will instruct you how to easily create such a template using VMware vSphere 6.5 and above.

> **Note: If you already have an Ubuntu Server VM template it is still recommended to use the guide as a reference.**

## Deployment

Before executing the Terraform plan, you must set the environment variables which will be used by the plan. These variables are based on the Azure service principal you've just created, your Azure subscription and tenant, and your VMware vSphere credentials.

* Retrieve your Azure subscription ID and tenant ID using the ```az account list``` command.

* The Terraform plan creates resources in both Microsoft Azure and VMware vSphere. It then executes a script on the virtual machine to install the Azure Arc agent and all necessary artifacts. This script requires certain information about your VMware vSphere and Azure environments.

* Edit [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform/scripts/vars.sh) and update each of the variables with the appropriate values.

  * TF_VAR_subscription_id=Your Azure subscription ID
  * TF_VAR_client_id=Your Azure service principal name
  * TF_VAR_client_secret=Your Azure service principal password
  * TF_VAR_tenant_id=Your Azure tenant ID
  * TF_VAR_resourceGroup=Azure resource group name
  * TF_VAR_location=Azure Region
  * TF_VAR_arcClusterName=The name of your k8s cluster as it will be shown in Azure Arc
  * TF_VAR_vsphere_user=vCenter Admin Username
  * TF_VAR_vsphere_password=vCenter Admin Password
  * TF_VAR_vsphere_server=vCenter server FQDN/IP
  * TF_VAR_admin_user=OS Admin Username
  * TF_VAR_admin_password=OS Admin Password

* From CLI, navigate to the [*azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform*](https://github.com/microsoft/azure_arc/tree/main/azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform) directory of the cloned repo.

* Export the environment variables you edited by running [*scripts/vars.sh*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform/scripts/vars.sh) with the source command as shown below. Terraform requires these to be set for the plan to execute properly. Note that this script will also be automatically executed remotely on the virtual machine as part of the Terraform deployment.

    ```shell
    source ./scripts/vars.sh
    ```

* In addition to the *TF_VAR* environment variables you've just exported, edit the Terraform variables in the [*terraform.tfvars*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform/terraform.tfvars) to match your VMware vSphere environment.

    ![TF_VAR environment variables](./01.png)

* Run the ```terraform init``` command which will download the Terraform AzureRM, Local and vSphere providers.

    ![terraform init](./02.png)

* Run the ```terraform apply --auto-approve``` command and wait for the plan to finish.

    ![terraform apply](./03.png)

* Once the Terraform deployment is completed, a new Ubuntu Server VM will be up & running, installed with a single-master Rancher K3s Kubernetes cluster and will be projected as an Azure Arc Kubernetes cluster in a newly created Azure resource group.

    ![VMware vSphere Ubuntu Server VM](./04.png)

    ![Azure Arc-enabled Kubernetes cluster](./05.png)

    ![Azure Arc-enabled Kubernetes cluster](./06.png)

## Delete the deployment

* The most straightforward way is to delete the cluster is via the Azure Portal, just select cluster and delete it.

    ![Delete Azure Arc-enabled Kubernetes cluster](./07.png)

* If you want to nuke the entire environment, just delete the Azure resource group and the newly generated *az_connect_k3s* shell script in the [*scripts*](https://github.com/microsoft/azure_arc/blob/main/azure_arc_k8s_jumpstart/rancher_k3s/vmware/terraform/scripts) folder.

    ![Delete Azure resource group](./08.png)

* Alternatively, you can use the ```terraform destroy --auto-approve``` command.

    ![terraform destroy](./09.png)
