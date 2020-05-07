# Overview

The following README will guide you on how to use the provided Azure ARM template to deploy a "Ready to Go" virtual machine installed with single-master Rancher K3s Kubernetes cluster and connected it as an Azure Arc cluster resource.

# Prerequisites

* Clone or fork this repo.

* To deploy the ARM template, Azure CLI is required. To install it, follow the official Azure [document](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

### Create Azure Service Principal (SP)   
To connect the K3s cluster installed on the VM to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

```az login``

```az ad sp create-for-rbac -n "http://AzureArc" --role contributor```

Output should look like this:

```
{
  "appId": "aedfb806-53fc-4dff-8d7c-67f4526ac661",
  "displayName": "AzureArcK8s",
  "name": "http://AzureArcK8s",
  "password": "b5453b1a-d066-4fba-90dd-ebd89ab2338e",
  "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
}
```

**Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest)

# Deployment 

The deployment is using the template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](../azure/arm_template/azuredeploy.parameters.json) file to include the OS username and password as well as the appId, password and tenant generated from the service principal creation.  

## If you cloned this repo

If you cloned this repository and made these changes locally, run the below command:

```az group create --name <Name of the Azure Resource Group> --location <Azure Region>```   
```az deployment group create \```   
```--resource-group <Name of the Azure Resource Group> \```   
```--name <The name of this deployment> \```   
```--template-file <The *azuredeploy.json* template file location> \```   
```--parameters <The *azuredeploy.parameters.json* parameters file location>```

For example and to make it easy for you, ```cd``` to the directory of the ARM template json files and run the command and wait for it to finish.. 

```az group create --name Arc-K3s-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-K3s-Demo \```   
```--name arck3sdemo01 \```   
```--template-file azuredeploy.json \```   
```--parameters azuredeploy.parameters.json```

## If you forked this repo

If you forked this repository and you are pushing the changes to the forked repo, run the below command and wait for it to finish.

```az group create --name Arc-K3s-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-K3s-Demo \```   
```--name arck3sdemo01 \```   
```--template-uri <The *azuredeploy.json* template file location in your GitHub repo> \```   
```--parameters <The *azuredeploy.parameters.json* template file location in your GitHub repo>```

For example:

```az group create --name Arc-K3s-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-K3s-Demo \```   
```--name arck3sdemo01 \```   
```--template-uri https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_k8s_jumpstart/azure/arm_template/azuredeploy.json \```   
```--parameters https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_k8s_jumpstart/azure/arm_template/azuredeploy.parameters.json```

![](../img/azure_arm_template/01.png)

# Connecting to Azure Arc

**Note:** The VM bootstrap includes the log in process to Azure as well deploying the needed Azure Arc CLI extensions - no action items on you there!

* SSH to the VM using the created Azure Public IP and your username/password.

![]()

* Using the Azure Service Principle you've created, run the below command to connect the cluster to Azure Arc.

    ```az connectedk8s connect --name <Name of your cluster as it will be shown in Azure> --resource-group <Azure Resource Group Name> --onboarding-spn-id 40bc3876-dfe9-46fa-8210-7ecf757e127f --onboarding-spn-secret e15fa6e6-f453-42e9-b024-746f1379ce59```

    For example:

    ```az connectedk8s connect --name arck3sdemo --resource-group Arc-K3s-Demo --onboarding-spn-id 40bc3876-dfe9-46fa-8210-7ecf757e127f --onboarding-spn-secret e15fa6e6-f453-42e9-b024-746f1379ce59```

<Command output PIC>

<Arc in Azure PIC>

# Delete the deployment

The most straightforward to delete the cluster is via the Azure Portal, just select cluster and delete it. 

![](../img/azure_arm_template/03.png)

If you want to nuke the entire environment, just delete the Azure Resource Group. 

![](../img/azure_arm_template/04.png)