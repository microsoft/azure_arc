# Overview

The following README will guide you on how to use the provided [Azure ARM Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview) to deploy an [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) cluster and connected it as an Azure Arc cluster resource.

# Prerequisites

* Clone this repo

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). Azure CLI should be running version 2.6.0 or later. Use ```az --version``` to check your current installed version.

* [Generate SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed) (or use existing ssh key).

* Create Azure Service Principal (SP)   

    To connect the AKS cluster installed on the VM to Azure Arc, Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the following command:

    ```az login```

    ```az ad sp create-for-rbac -n "http://AzureArcK8s" --role contributor```

    Output should look like this:
    ```
    {
    "appId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "displayName": "AzureArcK8s",
    "name": "http://AzureArcK8s",
    "password": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "tenant": "XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    ```
    **Note**: It is optional but highly recommended to scope the SP to a specific [Azure subscription and Resource Group](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest) 

# Deployment 

The deployment is using the template parameters file. Before initiating the deployment, edit the [*azuredeploy.parameters.json*](../aks/arm_template/azuredeploy.parameters.json) file to match your environment. 

![](../img/aks_arm_template/01.png)

## If you cloned this repo

If you cloned this repository and made these changes locally, run the below command:

```az group create --name <Name of the Azure Resource Group> --location <Azure Region>```   
```az deployment group create \```   
```--resource-group <Name of the Azure Resource Group> \```   
```--name <The name of this deployment> \```   
```--template-file <The *azuredeploy.json* template file location> \```   
```--parameters <The *azuredeploy.parameters.json* parameters file location>```

For example and to make it easy for you, from the directory where the ARM template JSON files are, run the below command and wait for it to finish.. 

```az group create --name Arc-AKS-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-AKS-Demo \```   
```--name arcaksdemo01 \```   
```--template-file azuredeploy.json \```   
```--parameters azuredeploy.parameters.json```

## If you forked this repo

If you forked this repository and you are pushing the changes to the forked repo, run the below command and wait for it to finish.

**Note: As a best practice, don't push (and keep it local) the edited *azuredeploy.parameters.json* file which contains sensitive data to your GitHub account.**

```az group create --name Arc-AKS-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-AKS-Demo \```   
```--name arcaksdemo01 \```   
```--template-uri <The *azuredeploy.json* template file location in your GitHub repo> \```   
```--parameters <The *azuredeploy.parameters.json* template file location>```

For example:

```az group create --name Arc-AKS-Demo --location "East US"```   
```az deployment group create \```   
```--resource-group Arc-AKS-Demo \```   
```--name arcaksdemo01 \```   
```--template-uri https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_k8s_jumpstart/aks/arm_template/azuredeploy.json \```   
```--parameters azuredeploy.parameters.json```

Once the ARM template deployment is completed, a new AKS cluster in a new Azure Resource Group is created. 

![](../img/aks_arm_template/02.png)

![](../img/aks_arm_template/03.png)

# Connecting to Azure Arc

* Now that you have a running AKS cluster, edit the environment variables section in the included [az_connect_aks](../aks/arm_template/scripts/az_connect_aks.sh) shell script.

![](../img/aks_arm_template/04.png)

* In order to keep your local environment clean and untouched, we will use [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) (located in the top-right corner in the Azure portal) to run the *az_connect_aks* shell script against the AKS cluster. 

![](../img/aks_arm_template/05.png)

* Upload the *az_connect_aks* shell script and run it using the ```. ./az_connect_aks``` command.

**Note**: The extra dot is due to the script has an *export* function and needs to have the vars exported in the same shell session as the rest of the commands. 

![](../img/aks_arm_template/06.png)

![](../img/aks_arm_template/07.png)

![](../img/aks_arm_template/08.png)

* Once the script run has finished, the AKS cluster will be projected as a new Azure Arc cluster resource.

![](../img/aks_arm_template/09.png)

![](../img/aks_arm_template/10.png)

![](../img/aks_arm_template/11.png)

# Delete the deployment

The most straightforward way is to delete the Azure Arc cluster resource via the Azure Portal, just select the cluster and delete it. 

![](../img/aks_arm_template/12.png)

If you want to nuke the entire environment, run the below commands.

```az deployment group delete --name <Deployment name> --resource-group <Azure Resource Group Name>```

```az group delete --name <Azure Resource Group Name> --yes```

For example:

```az deployment group delete --name arcaksdemo01 --resource-group Arc-AKS-Demo```

```az group delete --name Arc-AKS-Demo --yes```
