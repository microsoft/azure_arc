#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principal and GCP project details --->
export TF_VAR_subscription_id="28d8e88b-aee3-4342-8b17-95d5329f4ba9"
export TF_VAR_client_id="9b07c238-3283-4740-852b-a7ff97c7e5e3"
export TF_VAR_client_secret="066c81c6-243a-4eb0-928a-70e611250fb0"
export TF_VAR_tenant_id="72f988bf-86f1-41af-91ab-2d7cd011db47"
export TF_VAR_gcp_project_id="azure-arc-demo-277516"
export TF_VAR_gcp_credentials_filename="azure-arc-demo-277516-00250c7937f4.json"