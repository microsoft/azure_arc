---
type: docs
title: "Azure ARC RUN command"
linkTitle: "Azure ARC RUN command"
weight: 20
description: >
---

## Run Powershell and Shell scripts on Azure Arc-enabled servers using the Run command

The Run command feature uses the Connected Machine agent to remotely run PowerShell scripts within an Azure Arc-connected Windows machine and Shell scripts within an Azure Arc-connected Linux machine. 

This capability is useful in all scenarios where you want to run a script within an Arc-connected machine. It's one of the only ways to troubleshoot and remediate a machine that doesn't have the RDP or SSH port open because of improper network or administrative user configuration.

The following Jumpstart scenario will guide you on how to use the Run command on within your Arc-connected machine. Use the Azure Cloud Shell Bash or Visual Studio Code Bash command terminal to follow the instructions in this scenario.

> **NOTE: This scenario assumes you already deployed VMs or servers that are running on-premises or other clouds and you have connected them to Azure Arc. If you haven't, this repository offers you a way to do so in an automated fashion:**

- **[GCP Ubuntu instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_ubuntu/)**
- **[GCP Windows instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/gcp/gcp_terraform_windows/)**
- **[AWS Ubuntu EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_ubuntu/)**
- **[AWS Amazon Linux 2 EC2 instance](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/aws/aws_terraform_al2/)**
- **[Azure Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_linux/)**
- **[Azure Windows VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/azure_arm_template_win/)**
- **[VMware vSphere Ubuntu VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_ubuntu/)**
- **[VMware vSphere Windows Server VM](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vmware/vmware_terraform_winsrv/)**
- **[Vagrant Ubuntu box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu/)**
- **[Vagrant Windows box](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_windows/)**

## Prerequisites

- As mentioned, this scenario starts at the point where you already deployed and connected VMs or servers to Azure Arc. In the screenshots below, you can see a Windows and a Linux server that have been connected with Azure Arc and are visible as resources in Azure.

    ![Screenshot Azure Arc-enabled servers on resource group](./01.png)

    ![Screenshot Linux Azure Arc-enabled server connected status](./02.png)

    ![Screenshot Windows Azure Arc-enabled server connected status](./03.png)

- [Install or update Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) on your client machine. Azure CLI should be running version 2.49.0 or later. Use ```az --version``` to check your current installed version.
- check the version of the Azure cli extension "connectedmachine" on your client machine using the following command
```shell
    az extension list --query "[?name=='connectedmachine'].version"
```
- If the version of the Azure cli extension is different than "0.5.1" then use the following commands to upgrade it (**while the Run command is in preview**)
```shell
    az extension remove --name connectedmachine
    az extension add --source https://hybridrpstorage1.blob.core.windows.net/preview/connectedmachine-0.5.1-py3-none-any.whl
```
- Check the version of the Connected Machine agent running on your Arc-connected machine using the following command

```shell
    az connectedmachine show --name <Machine Name> --resource-group <Resource Group Name> --query "properties.agentVersion"
```
- If the Connected Machine agent version is lower than 1.33 then upgrade the extension using [this guidance](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent).

## Use the Run command to execute a simple Powershell command within an Arc-connected Windows machine

- Run the following Azure cli command after adding the appropriate resource group, name of the Arc-connected machine, a name identifying the command and the location of you Arc-connected machine
```shell
    az connectedmachine run-command create --resource-group <Resource Group Name> --machine-name <Machine Name> --run-command-name <Identifying Name of command> --script "Write-Host 'Hello World'" --location <Location>

```
- It takes few minutes to run the command and return the results. If the execution is successful then you would see the following within the longer returned Json string:
    
```shell
    "executionState": "Succeeded",
    "exitCode": 0,
    "output": "Hello World",
```

## Use the Run command to execute a simple Shell command within an Arc-connected Linux machine

- On your client machine run the following Azure cli command after adding the appropriate parameters

```shell
    az connectedmachine run-command create --resource-group <Resource Group Name> --machine-name <Machine Name> --run-command-name <Identifying Name of command> --script "ifconfig" --location <Location>
```
- If the execution is successful then you should have an output which includes the result of the ifconfig command as a string which includes "\n" to indicate line breaks in the original output.
    ![Screenshot](./04.png)

## Examine the available options for the Run command

- On your client machine run the following command which returns the available options of the Run command such as "create", "delete", "list", "show", "update" and "wait".

```shell
    az connectedmachine run-command --help
```
- Investigate the different ways you can run the "create" option by running the following command on your client machine

```shell
    az connectedmachine run-command create --help
```
## Direct the output of a Run command to Azure storage blob

- Create a storage account (if you do not have one) using the following command after filling out the required parameters

```shell
    az storage account create --name <Storage account name> --resource-group <Resource Group Name> --location <Location> --sku Standard_LRS --kind storageV2 --allow-blob-public-access false
```
- Create a storage container to which you will direct the output of the run command

```shell
    az storage container create --name <container name> --account-name <Storage account name> --auth-mode login
```

- Create a blob SAS URI with the following permissions: Read, Write, Create, delete and append. We will need an end date for the validity of the SAS token, 24 hours from the current date in the following example. Also, to be able to use the SAS URI in our run command we will need to remove any double quotes from the beginning and the end.

```shell
    end=`date -u -d "24 hours" '+%Y-%m-%dT%H:%MZ'`
    sasuri=$(az storage blob generate-sas --account-name <storage account name> --container-name <storage container name> --name <name of blob for command output destination - it will be created if it doesn't exist> --permissions acdrw --expiry $end --full-uri | tr -d '"')
``````

- Execute the following run command which runs a Powershell script within the Arc-enabled Windows machine. The run command directs the output to the append blob.

```shell
    az connectedmachine run-command create --resource-group <Resource Group Name> --machine-name <Machine Name>  --run-command-name <Identifying Name of command> --script "Get-Process | Sort-Object CPU -desc | Select-Object -first 10" --location <Location> --output-blob-uri $sasuri
```
- Examine the storage container in the Azure portal or using the Azure storage explorer. Look for the output of the command in the blob specified by the SAS URI used in the run command. The output should be the top five processes for CPU usage in the machine.

    ![Screenshot run command output in storage blob](./06.png)
