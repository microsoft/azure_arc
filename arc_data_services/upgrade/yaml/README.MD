# Azure Arc-enabled data services - Sample yaml files

This folder contains upgrade related scripts for Azure Arc-enabled data services. These scripts can be applied using kubectl command-line tool. If you are performing any operations on the services using the [Azure Data CLI](https://docs.microsoft.com/sql/azdata/install/deploy-install-azdata?toc=%2Fazure%2Fazure-arc%2Fdata%2Ftoc.json&bc=%2Fazure%2Fazure-arc%2Fdata%2Fbreadcrumb%2Ftoc.json&view=sql-server-ver15) tool then ensure that you have the latest version always.

## Upgrade yaml files for kube-native operations

The following yaml files can be used to upgrade an existing Azure Arc-enabled data services deployment using kubectl CLI. The yaml files can be applied in the order specified below and modifying the parameters based on your Kubernetes environment.

1. [Service account](./service-account.yaml)
This yaml file describes a service account named `sa-arc-upgrade-worker` to run the upgrade.

1. [Cluster role](./cluster-role.yaml)
This yaml file describes a cluster role for the upgrade named `cr-upgrade-worker`.

1. [Cluster role binding](./cluster-role-binding.yaml)
This yaml file creates a cluster role binding named ` arc:crb-upgrade-worker`.

1. [Job](./job.yaml)
This yaml file creates the data controller resources.

For deployment resources, see [Deploy](../../deploy/readme.md).
