# Azure Arc-enabled data services - Sample yaml files

This folder contains upgrade related scripts for Azure Arc-enabled data services. These scripts can be applied using kubectl command-line tool. If you are performing any operations on the services using the [Azure Data CLI](https://docs.microsoft.com/sql/azdata/install/deploy-install-azdata?toc=%2Fazure%2Fazure-arc%2Fdata%2Ftoc.json&bc=%2Fazure%2Fazure-arc%2Fdata%2Fbreadcrumb%2Ftoc.json&view=sql-server-ver15) tool then ensure that you have the latest version always.

## Upgrade yaml files for kube-native operations

The following yaml files can be used to upgrade an existing Azure Arc-enabled data services deployment using kubectl CLI. The yaml files can be applied in the order specified below and modifying the parameters based on your Kubernetes environment.

1. [Service Account](../../arcdata-deployer.yaml)
This yaml file defines a service account named `sa-arcdata-deployer` and related RBAC permission for running the upgrade. Replace the placeholder `{{NAMESPACE}}` in the file before applying.

   Example command:

   ```kubectl
   kubectl apply -n arc -f ../../arcdata-deployer.yaml
   ```

1. [Optional: Configure Upgrader User Account](./arcdata-upgrader.yaml)
This yaml file configures the permissions needed for a user account to upgrade the bootstrapper and data controller. Replace the placeholder `{{UPGRADER_USERNAME}}` in the file before applying. The following steps can also be run by a low-privilege upgrader user account.

1. [Bootstrapper Upgrade Job](./bootstrapper-upgrade-job.yaml)
This yaml file creates a job for upgrading the bootstrapper and related Kubernetes objects.

   Example command:

   ```kubectl
   kubectl apply -n arc -f bootstrapper-upgrade-job.yaml
   ```

1. [Upgrade Data Controller](./data-controller-upgrade.yaml)
This yaml file defines patch of the data controller image tag for upgrading the data controller.

   Example command:

   ```kubectl
   kubectl apply -n arc -f data-controller-upgrade.yaml
   ```

For deployment resources, see [Deploy](../../deploy/readme.md).
