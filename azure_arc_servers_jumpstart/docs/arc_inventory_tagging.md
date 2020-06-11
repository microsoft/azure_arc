# Overview

The following README will guide you on how to use AZ CLI to create an Azure tag taxonomy and apply tags to servers projected into Azure from other public clouds.

# Prerequisites

* Clone this repo

* [Install or update Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). **Azure CLI should be running version 2.7** or later. Use ```az --version``` to check your current installed version.

* Resources projected into Azure via Azure Arc from AWS and/or GCP. Complete these guides if you have not already to meet this requirement:
    * [Deploy an AWS EC2, Ubuntu VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/aws_terraform_ubuntu.md)
    * [Deploy a GCP, Windows Server VM and connect it to Azure Arc using Terraform](azure_arc_servers_jumpstart/docs/gcp_terraform_windows.md)

# Create a basic Azure tag taxonomy

Open AZ CLI and run the following commands to create a basic taxonomy structure.

```bash
az tag create --name "Business Unit"
az tag add-value --name "Business Unit" --value "Marketing"
az tag add-value --name "Business Unit" --value "Finance"
az tag add-value --name "Business Unit" --value "Dev"
az tag create --name "Hosting Platform"
az tag add-value --name "Hosting Platform" --value "Azure"
az tag add-value --name "Hosting Platform" --value "AWS" 
az tag add-value --name "Hosting Platform" --value "GCP"
az tag add-value --name "Hosting Platform" --value "On-premises" 
```

# Tag Arc resources

