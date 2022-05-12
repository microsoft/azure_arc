#!/bin/sh
terraformFolder=$1
resource_group_name=$2
azure_location=$3
spn_client_id=$4
spn_client_secret=$5
spn_tenant_id=$6
client_admin_ssh=$7
client_admin_username=$8
client_admin_password=${9}
deployment_flavor=${10}
workspace_name=${11}
github_repo=${12}
github_branch=${13}
deploy_bastion=${14}
spn_tenant_subcriptionid=${15}

cd "$terraformFolder" || exit

terraformVasrs=./terraform.tfvars

echo "$client_admin_ssh" >./rsa.pub
path=$(realpath ./rsa.pub)
echo "" >"$terraformVasrs"
echo "resource_group_name=\"$resource_group_name\"" >>"$terraformVasrs"
echo "azure_location=\"$azure_location\"" >>"$terraformVasrs"
echo "spn_client_id=\"$spn_client_id\"" >>"$terraformVasrs"
echo "spn_client_secret=\"$spn_client_secret\"" >>"$terraformVasrs"
echo "spn_tenant_id=\"$spn_tenant_id\"" >>"$terraformVasrs"
echo "client_admin_ssh=\"$path\"" >>"$terraformVasrs"
echo "client_admin_username=\"$client_admin_username\"" >>"$terraformVasrs"
echo "client_admin_password=\"$client_admin_password\"" >>"$terraformVasrs"
echo "deployment_flavor=\"$deployment_flavor\"" >>"$terraformVasrs"
echo "workspace_name=\"$workspace_name\"" >>"$terraformVasrs"
echo "github_repo=\"$github_repo\"" >>terraform.tfvars
echo "github_branch=\"$github_branch\"" >>"$terraformVasrs"
echo "deploy_bastion=\"$deploy_bastion\"" >>"$terraformVasrs"

export ARM_CLIENT_ID="$spn_client_id"
export ARM_CLIENT_SECRET="$spn_client_secret"
export ARM_SUBSCRIPTION_ID="$spn_tenant_subcriptionid"
export ARM_TENANT_ID="$spn_tenant_id"

terraform init -input=false
terraform plan -out=infra.out
terraform apply -input=false "infra.out"

#back to the root
cd ..
cd ..
