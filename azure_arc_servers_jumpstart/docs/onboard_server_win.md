# Onboard an existing Windows server with Azure Arc

The following README will guide you on how to connect an Windows machine to Azure Arc using a simple Powershell script.

# Prerequisites

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Create Azure Service Principal (SP)   

    To connect a server to Azure Arc, an Azure Service Principal assigned with the "Contributor" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)). 

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

* Create a new Azure Resource Group where you want your machine(s) to show up. 

![](../img/onboard_server_win/01.png)

* Download the [az_connect_win](../scripts/az_connect_win.ps1) Powershell script.

* Change the environment variables according to your environment and copy the script to the designated machine.

![](../img/onboard_server_win/02.png)

# Deployment

On the designated machine, Open Powershell ISE **as Administrator** and run the script. Note the script is using *$env:ProgramFiles* as the agent installation path so make sure **you are not using Powershell ISE (x86)**.

![](../img/onboard_server_win/03.png)

![](../img/onboard_server_win/04.png)

Upon completion, you will have your Linux server, connected as a new Azure Arc resource inside your Resource Group. 

![](../img/onboard_server_win/05.png)

![](../img/onboard_server_win/06.png)

![](../img/onboard_server_win/07.png)

# Delete the deployment

The most straightforward way is to delete the server via the Azure Portal, just select server and delete it. 

![](../img/onboard_server_win/08.png)

If you want to nuke the entire environment, just delete the Azure Resource Group.

![](../img/onboard_server_win/09.png)
