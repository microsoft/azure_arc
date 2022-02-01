# Azure Arc enabled data services - Sample yaml files

This folder contains deployment related scripts for Azure Arc enabled data services. These scripts can be applied using kubectl command-line tool. If you are performing any operations on the services using the [Azure Data CLI](https://docs.microsoft.com/en-us/sql/azdata/install/deploy-install-azdata?toc=%2Fazure%2Fazure-arc%2Fdata%2Ftoc.json&bc=%2Fazure%2Fazure-arc%2Fdata%2Fbreadcrumb%2Ftoc.json&view=sql-server-ver15) tool then ensure that you have the latest version always.

## Deployment yaml files for kube-native operations

The following yaml files can be used to create Azure Arc enabled data services using kubectl CLI. The yaml files can be applied in the order specified below and modifying the parameters based on your Kubernetes environment.

1. [Create Custom Resource Definitions](./custom-resource-definitions.yaml)
This yaml file creates custom resource definitions (CRDs) for data controller, SQL Managed Instance and PostgreSQL Hyperscale resources.

1. [Create Bootstrapper](./bootstrapper.yaml)
This yaml file creates bootstrapper pad in a specified namespace along with the service account and bootstrapper role.

1. [Create data controller login secret](./controller-login-secret.yaml)
This yaml file creates a secret containing the data controller administrator username and password. These credentials will be used to perform operations via the azdata CLI. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings).

1. [Create data controller](./data-controller.yaml)
This yaml file creates the data controller resources.

1. [Create Azure SQL Managed Instance](./sqlmi.yaml)
This yaml file creates the SQL Managed Instance resource(s). The administrator username and password for the Managed instance is specified using a secret. The secret should be named using the format *\<instance-name\>-login-secret*. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings).

1. [Create Azure PostgreSQL Hyperscale](./postgresql.yaml)
This yaml file creates the PostgreSQL Hyperscale resource(s).The administrator username and password for the PostgreSQL instance is specified using a secret. The secret should be named using the format *\<instance-name\>-login-secret*. The secret values should be base64 encoded strings. See instructions under [Creating base64 encoded strings](#creating-base64-encoded-strings).

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
$ENCODED_PASSWORD = 'dGhpcyBpcyBteSBwYXNzd29yZA=='
$PASSWORD = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ENCODED_PASSWORD))
Write-Output $PASSWORD
```

On Linux, the following bash shell command can be used to decode a base64 encoded string:

```bash
echo -n dGhpcyBpcyBteSBwYXNzd29yZA==|base64 -d
```

## [RBAC samples](./rbac)

This folder contains yaml files that provide cluster roles and roles to configure Kubernetes RBAC for Azure Arc enabled data services.
