#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principal & VMware vSphere environment--->

export TF_VAR_subscription_id=<Your Azure Subscription ID>
export TF_VAR_client_id=<Your Azure Service Principle name>
export TF_VAR_client_secret=<Your Azure Service Principle password>
export TF_VAR_tenant_id=<Your Azure tenant ID>
export TF_VAR_resourceGroup=<Azure Resource Group Name>
export TF_VAR_location=<Azure Region>
export TF_VAR_vsphere_user=<vCenter Admin Username>
export TF_VAR_vsphere_password=<vCenter Admin Password>
export TF_VAR_vsphere_server=<vCenter server FQDN/IP>
export TF_VAR_admin_user=<OS Admin Username>
export TF_VAR_admin_password=<OS Admin Password>