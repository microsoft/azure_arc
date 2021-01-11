#!/bin/sh

# Change the following environment variables to your OCI details

export TF_VAR_tenancy_ocid=<Oracle tenanacy OCID>
export TF_VAR_user_ocid=<Oracle user OCID>
export TF_VAR_fingerprint=<Oracle API FingerPrint>
export TF_VAR_private_key_path=<path to pem key>
export TF_VAR_ssh_public_key=$(cat my_oci_key.pub) 
### OCI Region
export TF_VAR_region=<OCI region>
### Compartment
export TF_VAR_compartment_ocid=<Oracle compartment OCID>

# Change the following environment variables according to your Azure Service Principal

export TF_VAR_subscription_id=<Azure subscription ID>
export TF_VAR_client_id=<Azure service principal ID>
export TF_VAR_client_secret=<Azure service principal password>
export TF_VAR_tenant_id=<Azure tenant ID>
export TF_VAR_azure_location=<Azure region e.g. westus2>
