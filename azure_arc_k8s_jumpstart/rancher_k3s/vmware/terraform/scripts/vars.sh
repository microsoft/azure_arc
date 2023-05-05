#!/bin/sh

# '<--- Change the following environment variables according to your Azure service principal & VMware vSphere environment--->'

export TF_VAR_subscription_id='<Your Azure subscription ID>'
export TF_VAR_client_id='<Your Azure service principal name>'
export TF_VAR_client_secret='<Your Azure service principal password>'
export TF_VAR_tenant_id='<Your Azure tenant ID>'
export TF_VAR_resourceGroup='<Azure resource group name>'
export TF_VAR_location='<Azure Region>'
export TF_VAR_arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export TF_VAR_vsphere_user='<vCenter Admin Username>'
export TF_VAR_vsphere_password='<vCenter Admin Password>'
export TF_VAR_vsphere_server='<vCenter server FQDN/IP>'
export TF_VAR_admin_user='<OS Admin Username>'
export TF_VAR_admin_password='<OS Admin Password>'
export K3S_VERSION="1.27.1+k3s1" # Do not change!
