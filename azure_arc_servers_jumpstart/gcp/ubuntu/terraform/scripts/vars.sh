#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal and GCP project details --->
export TF_VAR_subscription_id={subscription id}
export TF_VAR_client_id={client id}
export TF_VAR_client_secret={client secret}
export TF_VAR_tenant_id={tenant id}
export TF_VAR_gcp_project_id={gcp project id}
export TF_VAR_gcp_credentials_filename={gcp credentials path}