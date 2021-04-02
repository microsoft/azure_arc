---
type: docs
title: "Alibaba Cloud Container Service for Kubernetes Terraform plan"
linkTitle: "Alibaba Cloud Container Service for Kubernetes Terraform plan"
weight: 1
description: >
---

## Deploy Alibaba Container Service for Kubernetes cluster and connect it to Azure Arc using Terraform

The following README will guide you on how to use the provided [Terraform](https://www.terraform.io/) plan to deploy an Alibaba Cloud [Container Service for Kubernetes](https://www.alibabacloud.com/product/kubernetes) and connect it as an Azure Arc cluster resource.

## Prerequisites

* Clone the Azure Arc Jumpstart repository

    ```shell
    git clone https://github.com/microsoft/azure_arc.git
    ```

* [Install or update Azure CLI to version 2.21.0 and above](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

  ```shell
  az --version
  ```

* [Install or update Helm to version 3.5.3 and above](https://helm.sh/docs/intro/install/). Use the below command to check your current installed version.

  ```shell
  helm version
  ```

* optional: [Install or update Aliyun CLI to latest version 3.0.73 and above](https://github.com/aliyun/aliyun-cli). Use the below command to check your current installed version.

  > Ālǐyún or Aliyun is actually the chinese name for Alibaba Cloud

  ```shell
  aliyun --version
  ```

* [Install Terraform >=0.12](https://learn.hashicorp.com/terraform/getting-started/install.html). Use the below command to check your current installed version.

  ```shell
  terraform -v
  ```

* [Enable Azure subscription with](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) the two resource providers for Azure Arc enabled Kubernetes. Registration is an asynchronous process, and registration may take approximately 10 minutes. Login with an identity with sufficient authorizations.

  ```shell
  az login
  az provider register --namespace Microsoft.Kubernetes
  az provider register --namespace Microsoft.KubernetesConfiguration
  ```

  You can monitor the registration process with the following commands:

  ```shell
  az provider show -n Microsoft.Kubernetes -o table
  az provider show -n Microsoft.KubernetesConfiguration -o table
  ```

* Install the Azure Arc for Kubernetes CLI extensions ***connectedk8s*** and ***k8s-configuration***:

  ```shell
  az extension add --name connectedk8s
  az extension add --name k8s-configuration
  ```

  > **Note: If you already used this guide before and/or have the extensions installed, use the bellow commands:**

  ```shell
  az extension update --name connectedk8s
  az extension update --name k8s-configuration
  ```

### Create a new Alibaba Cloud access key

* [Sign up to or have an Alibaba Cloud account](https://www.alibabacloud.com/) - domestic or international

  > **Note: The screenshots and sample outputs shown here are based on a domestic account.**

* Browse to <https://console.aliyun.com/> and login with your Alibaba Cloud account. Once logged in, create a new access key from your profile. After creating it, be sure to copy down the access and secret key.

  ![Alibaba Cloud new access key](./01.png)

  ![Alibaba Cloud new access key](./02.png)

  ![Alibaba Cloud new access key](./03.png)

* Navigate to product *Container Service - Kubernetes*, activate this service and if demanded **Confirm Cloud Resource Access Authorization**

  ![Cloud Resource Access Authorization](./04.png)

## Deployment

The only thing you need to do before executing the Terraform plan is to export the environment variables which will be used by the plan. This is based on the Azure service principal you've just created and your subscription.  

* Export the environment variables needed for the Terraform plan.

  ```shell
  export ALICLOUD_ACCESS_KEY="<Your Alibaba Cloud access key>"
  export ALICLOUD_SECRET_KEY="<Your Alibaba Cloud secret key>"
  export ALICLOUD_REGION="<Alibaba Cloud region>"
  export ALICLOUD_PROFILE="<Aliyun CLI profile>"
  export AZURE_SUBSCRIPTION_ID="<Your Azure subscription id>"
  export AZURE_LOCATION="<Azure location>"
  export AZURE_RESOURCE_GROUP="<Azure resource group>"
  export AZURE_CLUSTER_NAME="<Azure Arc cluster name>"
  ```

  For example:

  ```shell
  export ALICLOUD_ACCESS_KEY="aBcDeFgHiJkLmNo"
  export ALICLOUD_SECRET_KEY="aBcDeFgHiJkLmNoPqRtUvWxYz"
  export ALICLOUD_REGION="cn-shanghai"
  export ALICLOUD_PROFILE="akProfile"
  export AZURE_SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
  export AZURE_LOCATION="southeastasia"
  export AZURE_RESOURCE_GROUP="Azure-Arc-Aliyun-K8S"
  export AZURE_CLUSTER_NAME="azure-arc-aliyun"
  ```

  > **Note: If you are running in a PowerShell environment, to set the Terraform environment variables, use the _$env:variable-name=variable-value_ (see example below)**

  ```powershell
  $env:ALICLOUD_ACCESS_KEY="aBcDeFgHiJkLmNo"
  ```

* From folder `azure_arc_k8s_jumpstart/alibaba/terraform` run the ```terraform init``` command which will download the required terraform providers.

  ![terraform init output](./05.png)

* Deploy cluster by running the ```terraform apply --auto-approve``` command. Wait for the plan to finish.

  ![terraform deploy output](./06.png)
  ...
  ![terraform deploy output](./07.png)

  sample cluster in Alibaba Cloud Resource Management view:

  ![Alibaba Cloud Resource Management](./08.png)

* The plan will drop the created clusters configuration in users home directory `~/.kube/config` to be used with `kubectl` or `helm`. But to make it usable with `helm`, file permissions need to be reduced:

   ```shell
   chmod go-r ~/.kube/config
   ```

## Connecting to Azure Arc

* Now that you have running cluster, based on the environment variables set and Azure environment prepared above, you can connect the Alibaba Cloud cluster to Azure Arc:

   ```shell
   az login
   az account set -s $AZURE_SUBSCRIPTION_ID
   az group create --location $AZURE_LOCATION --name $AZURE_RESOURCE_GROUP
   ```

   output should look like this:

   ```json
   {
     "id": "/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/resourceGroups/Azure-Arc-Aliyun-K8S",
     "location": "southeastasia",
     "managedBy": null,
     "name": "Azure-Arc-Aliyun-K8S",
     "properties": {
       "provisioningState": "Succeeded"
     },
     "type": "Microsoft.Resources/resourceGroups"
   }
   ```

   connect the cluster:

   ```shell
   az connectedk8s connect --name $AZURE_CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION
   ```

   sample output

   ![Connect Alibaba cluster to Azure Arc](./09.png)

   sample cluster in Azure Portal

   ![Connect Alibaba cluster to Azure Arc](./10.png)

## Delete the deployment

To delete the environment in Azure, the use *`az group delete --resource-group $AZURE_RESOURCE_GROUP -y`* command.

To delete the environment in Alibaba Cloud, use the *`terraform refresh`* and *`terraform destroy --auto-approve`* commands.

output:

```text
Destroy complete! Resources: 8 destroyed.
```

> **Note: `terraform refresh` will update the local state to that `terraform destroy` also handles automatically generated resources like _Elastic IP Address_ and/or _NAT Gateway_.**
