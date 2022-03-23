# Support GitHub Actions Deployment for EKS

Simplifly deployment using Gtihub Workflows and the verified [Terraform Action](https://github.com/hashicorp/setup-terraform) published on [GitHub Actions Marketplace](https://github.com/marketplace/actions/hashicorp-setup-terraform) 

### Files added:
- [tf-deploy-eks.yml](https://github.com/oaviles/azure_arc/blob/gh-action_deployment/azure_arc_k8s_jumpstart/eks/terraform/github/workflow/tf-deploy-eks.yml)
- [connect-eks-and-arc.yml](https://github.com/oaviles/azure_arc/blob/gh-action_deployment/azure_arc_k8s_jumpstart/eks/terraform/github/workflow/connect-eks-and-arc.yml)

### Files modified:
- [providers.tf](https://github.com/oaviles/azure_arc/blob/gh-action_deployment/azure_arc_k8s_jumpstart/eks/terraform/github/providers.tf)
- [variables.tf](https://github.com/oaviles/azure_arc/blob/gh-action_deployment/azure_arc_k8s_jumpstart/eks/terraform/github/variables.tf)

```
# This workflow installs the latest version of Terraform CLI and configures the Terraform CLI configuration file
# with an API token for Terraform Cloud (app.terraform.io). On manual trigger events, this workflow will run
# `terraform init`, `terraform fmt`, and `terraform plan` and `terraform apply` (speculative plan via Terraform Cloud). 
#
# Documentation for `hashicorp/setup-terraform` is located here: https://github.com/hashicorp/setup-terraform
#
# To use this workflow, you will need to complete the following setup steps.
#
# 1. Create a `main.tf` file in the root of this repository with the `remote` backend and one or more resources defined.
#   Example `main.tf`:
#     # The configuration for the `remote` backend.
#     terraform {
#       backend "remote" {
#         # The name of your Terraform Cloud organization.
#         organization = "example-organization"
#
#         # The name of the Terraform Cloud workspace to store Terraform state files in.
#         workspaces {
#           name = "example-workspace"
#         }
#       }
#     }
#
#     # An example resource that does nothing.
#     resource "null_resource" "example" {
#       triggers = {
#         value = "A example resource that does nothing!"
#       }
#     }
#
#
# 2. Generate a Terraform Cloud user API token and store it as a GitHub secret (e.g. TF_API_TOKEN) on this repository.
#   Documentation:
#     - https://www.terraform.io/docs/cloud/users-teams-organizations/api-tokens.html
#     - https://docs.github.com/en/actions/security-guides/encrypted-secrets
#
# 3. Reference the GitHub secret in step using the `hashicorp/setup-terraform` GitHub Action.
#   Example:
#     - name: Setup Terraform
#       uses: hashicorp/setup-terraform@v1
#       with:
#         cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
#
# 4. Create the following GitHub secrets, these secrets will be used by GitHub Workflow called "connect-eks-and-arc.yml".
#   Secrets:
#     - AZURE_RG = "Name of your Azure Resurce Group"
#     - CLIENTID = "Service Principal appId"
#     - CLIENTSECRET = "Service Principal password"
#     - TENANTID = "Service Principal tenant"
#     - EKSCLUSTER_NAME = "Your EKS Cluster Name"
#   Documentation:
#     - https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository
#
# 5. Create the following Terraform Cloud Workspace Variables, these variables will be used by GitHub Workflow called "tf-deploy-eks.yml".
#   Workspace Variables:
#     - AWS_SECRET_ACCESS_KEY  = "your aws secret key"
#     - AWS_ACCESS_KEY_ID = "your aws access key"
#   Documentation:
#     - https://www.terraform.io/cloud-docs/workspaces/variables#precedence

```

## Legal Notices

Microsoft and any contributors grant you a license to the Microsoft documentation and other content
in this repository under the [Creative Commons Attribution 4.0 International Public License](https://creativecommons.org/licenses/by/4.0/legalcode),
see the [LICENSE](LICENSE) file, and grant you a license to any code in the repository under the [MIT License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products and services referenced in the documentation
may be either trademarks or registered trademarks of Microsoft in the United States and/or other countries.
The licenses for this project do not grant you rights to use any Microsoft names, logos, or trademarks.
Microsoft's general trademark guidelines can be found at http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/

Microsoft and any contributors reserve all other rights, whether under their respective copyrights, patents,
or trademarks, whether by implication, estoppel or otherwise.
