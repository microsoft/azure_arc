# Azure Arc enabled data services - RBAC yaml files

Kubernetes RBAC can be used to control access to resources in the cluster. The cluster roles and roles provided allow you to leverage Kubernetes RBAC to grant permissions to users or set of users (groups) to perform read or write operations on resources. You can deploy either the cluster role(s) or role(s) depending on your requirements and use the corresponding rolebindings. The roles should be created in the namespace that contains the Azure Arc enabled data services.

The following types of cluster roles / roles are provided:

|Role Type|Description|
|---------|---------|
|Reader|Role that provides read access to data controller, SQL Managed Instance and PostgreSQL Hyperscale resources|
|Database instance reader|Role that provides read access to SQL Managed Instance and PostgreSQL Hyperscale resources|
|Data controller reader|Role that provides read access to data controller resource|
|SQL Managed Instance reader|Role that provides read access to SQL Managed Instance resource|
|PostgreSQL Hyperscale reader|Role that provides read access to PostgreSQL Hyperscale resources|
|Writer|Role that provides write access to data controller, SQL Managed Instance and PostgreSQL Hyperscale resources|
|Database instance writer|Role that provides write access to SQL Managed Instance and PostgreSQL Hyperscale resources|
|Data controller writer|Role that provides write access to data controller resource|
|SQL Managed Instance writer|Role that provides write access to SQL Managed Instance resource|
|PostgreSQL Hyperscale writer|Role that provides write access to PostgreSQL Hyperscale resources|

## Cluster Roles

1. [Writer Cluster Roles](./azure-arc-data-writer-cluster-roles.yaml)
This yaml file provides cluster roles for resources in Azure Arc enabled data services that provides write access. The write access implies that a particular resource can be fully managed i.e., listed, created, edited, or deleted.

1. [Reader Cluster Roles](./azure-arc-data-reader-cluster-roles.yaml)
This yaml file provides cluster roles for resources in Azure Arc enabled data services that provides read access. The read access implies that a particular resource can only be enumerated and properties can be viewed.

1. [Rolebindings for Cluster Roles](./azure-arc-data-cluster-rolebindings.yaml)
This yaml file provides rolebindings for the cluster roles that can be used to assign permissions to users or groups. The examples uses sample user names ***hr-admin*** and ***hr-user***.

## Roles
1. [Writer Roles](./azure-arc-data-writer-roles.yaml)
This yaml file provides roles for resources in Azure Arc enabled data services that provides write access. The write access implies that a particular resource can be fully managed i.e., listed, created, edited, or deleted.

1. [Reader Roles](./azure-arc-data-writer-roles.yaml)
This yaml file provides roles for resources in Azure Arc enabled data services that provides read access. The read access implies that a particular resource can only be enumerated and properties can be viewed.

1. [Rolebindings for Roles](./azure-arc-data-rolebindings.yaml)
This yaml file provides rolebindings for the cluster roles that can be used to assign permissions to users or groups. The examples uses sample user names ***hr-admin*** and ***hr-user***.

## Test Script

The [find-user-group-persmissions.sh](./find-user-group-permissions.sh) script contains sample kubectl auth can-i commands that can be used to see what actions a particular user can perform.