# Azure Arc enabled data services - Sample yaml files

This folder contains deployment related scripts for Azure Arc enabled data services. These scripts can be applied using kubectl command-line tool. If you are performing any operations on the services using the [Azure Data CLI](https://docs.microsoft.com/en-us/sql/azdata/install/deploy-install-azdata?toc=%2Fazure%2Fazure-arc%2Fdata%2Ftoc.json&bc=%2Fazure%2Fazure-arc%2Fdata%2Fbreadcrumb%2Ftoc.json&view=sql-server-ver15) tool then ensure that you have the latest version always.

## Deployment yaml files for kube-native operations

The following yaml files can be used to create Azure Arc enabled data services using kubectl CLI. The yaml files can be applied in the order specified below and modifying the parameters based on your Kubernetes environment.

1. [Create Deployer Service Account](../../arcdata-deployer.yaml)
This yaml file creates a deployer service account in a specified namespace with proper RBAC. This service account will be used in the next step to run a "bootstrap" job. Replace the placeholder `{{NAMESPACE}}` in the file before applying.

1. [Optional: Configure Installer User Account](./arcdata-installer.yaml)
This yaml file configures the permissions needed for a user account to install the bootstrapper and data controller. Replace the placeholder `{{INSTALLER_USERNAME}}` in the file before applying.

1. [Create Bootstrapper](./bootstrapper.yaml)
This yaml file creates "bootstrapper" job to install the bootstrapper along with related cluster-scope and namespaced objects, such as custom resource definitions (CRDs), the service account and bootstrapper role. This step can also be run by a low-privilege installer user account. The [unistall.yaml](./uninstall.yaml) is for uninstalling the bootstrapper and related Kubernetes objects, except the CRDs.

1. [Create data controller](./data-controller.yaml)
This yaml file creates the data controller resources. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings). This step can also be run by a low-privilege installer user account.

Alternatively, the bootstrapper and data controller can be created following these steps without configuring a low-privilege installer user account.

1. [Create Bootstrapper](./bootstrapper-unified.yaml)
This yaml file creates the a deployer service account and bootstrapper. Replace the placeholder `{{NAMESPACE}}` in the file before applying.

1. [Create data controller](./data-controller.yaml)
This yaml file creates the data controller resources.

For data services:

1. [Create Azure SQL Managed Instance](./sqlmi.yaml)
This yaml file creates the SQL Managed Instance resource(s). The administrator username and password for the Managed instance is specified using a secret. The secret should be named using the format *\<instance-name\>-login-secret*. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings).

1. [Create Azure PostgreSQL Server](./postgresql.yaml)
This yaml file creates the PostgreSQL server resource(s).The administrator username and password for the PostgreSQL instance is specified using a secret. The secret should be named using the format *\<instance-name\>-login-secret*. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings).

### Creating base64 encoded strings

The values of the username and password in secrets should be base64 encoded using UTF8 encoded string. On Windows, the following PowerShell snippet can be used to obtain the base64 encoded value:

```powershell
$PASSWORD = 'this is my password'
$ENCODED_PASSWORD = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PASSWORD))
Write-Output $ENCODED_PASSWORD
```

On Linux, the following bash shell command can be used to obtain the base64 encoded value:

```bash
echo -n this is my password|base64
```

The base64 encoded values can be decoded using similar steps. On Windows, the following PowerShell snippet can be used to decode the base64 encoded string:

```powershell
$ENCODED_PASSWORD = '<YourEncodedPasswordHere>'
$PASSWORD = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ENCODED_PASSWORD))
Write-Output $PASSWORD
```

On Linux, the following bash shell command can be used to decode a base64 encoded string:

```bash
echo -n <YourEncodedPasswordHere>|base64 -d
```

## Azure Arc-enabled data services extension with least privileges in direct connectivity mode

The following commands create the Azure Arc-enabled data services extension with least privileges in direct connectivity mode.

```ps
<# Inputs:
  $ENV:EXTENSION_NAMESPACE: the namespace to install arcdataservices k8s extension into
  $ENV:EXTENSION_NAME: the name of the arcdataservices k8s extension
  $ENV:INSTALLER_SERVICE_ACCOUNT: the name of the installer service account
  $ENV:RUNTIME_SERVICE_ACCOUNT: the name of the runtime service account
  $ENV:CLUSTER_NAME: the name of the Arc Kuberenetes cluster
  $ENV:RESOURCE_GROUP: the resource group of the Arc Kuberenetes cluster
#>

kubectl create namespace $ENV:EXTENSION_NAMESPACE

kubectl -n $ENV:EXTENSION_NAMESPACE create serviceaccount $ENV:INSTALLER_SERVICE_ACCOUNT
kubectl -n $ENV:EXTENSION_NAMESPACE create serviceaccount $ENV:RUNTIME_SERVICE_ACCOUNT

# To configure RBAC permissions for the installer and runtime service accounts created above,
# replace template placeholders {{NAMESPACE}}, {{INSTALLER_SERVICE_ACCOUNT}} and {{RUNTIME_SERVICE_ACCOUNT}} in the yaml files below with actual valus before applying
kubectl apply --namespace $ENV:EXTENSION_NAMESPACE -f ../../arcdata-installer.yaml
kubectl apply --namespace $ENV:EXTENSION_NAMESPACE -f ../../arcdata-runtime.yaml
kubectl apply -f ../../azure-arc-extension-identity.yaml

az k8s-extension create --cluster-name $ENV:CLUSTER_NAME --resource-group $ENV:RESOURCE_GROUP --name $ENV:EXTENSION_NAME --cluster-type connectedClusters --extension-type microsoft.arcdataservices --auto-upgrade false --scope cluster --release-namespace $ENV:EXTENSION_NAMESPACE --config service-account-extension-install="system:serviceaccount:arc:$ENV:INSTALLER_SERVICE_ACCOUNT" --config service-account-extension-runtime="system:serviceaccount:arc:$ENV:RUNTIME_SERVICE_ACCOUNT"
```

Similary, the RBAC permissions for the corresponding release must be applied before running `az k8s-extension update` to upgrade the Azure Arc-enabled data services extension to a specific release.

## [RBAC samples](./rbac)

This folder contains yaml files that provide cluster roles and roles to configure Kubernetes RBAC for Azure Arc enabled data services.
