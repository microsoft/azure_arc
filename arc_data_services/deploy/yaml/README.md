# Azure Arc enabled data services - Sample yaml files

## [Security Context Constraint for OpenShift deployments](./arc-data-scc.yaml)

This folder contains deployment related scripts for Azure Arc enabled data services.


## Deployment yaml files
The following yaml files can be used to create Azure Arc enabled data services using kubectl CLI. The yaml files can be applied in the order specified below and modifying the parameters based on your Kubernetes environment.

1. [Create Custom Resource Definitions](./custom-resource-definitions.yaml)
This yaml file creates custom resource definitions (CRDs) for data controller, SQL Managed Instance and PostgreSQL Hyperscale resources.

1. [Create Bootstrapper](./bootstrapper.yaml)
This yaml file creates bootstrapper pad in a specified namespace along with the service account and bootstrapper role.

1. [Create data controller login secret](./controller-login-secret.yaml)
This yaml file creates a secret containing the data controller administrator username and password. These credentials will be used to perform operations via the azdata CLI.

1. [Create data controller](./data-controller.yaml)
This yaml file creates the data controller resources.

1. [Create Azure SQL Managed Instance](./sqlmi.yaml)
This yaml file creates the SQL Managed Instance resource(s).

1. [Create Azure PostgreSQL Hyperscale](./postgresql.yaml)
This yaml file creates the PostgreSQL Hyperscale resource(s).

## [RBAC samples](./rbac)
This folder contains yaml files that provide cluster roles and roles to configure Kubernetes RBAC for Azure Arc enabled data services.
