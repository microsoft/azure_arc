#Commons
variable "location" {
  description = "(Required) Location of the all services to be created"
  default="westeurope"
}

variable "resource_group_name" {
  description = "(Required) Resource group name of the all services to be created"
  default= "K8sEdgeJumpStart"
}

variable "tags" {
  description = "(Required) Tags to be applied to the all services to be created"
  default = { Project = "jumpstart_azure_arc_k8s" }
}

# Storage Account
variable "name-sta" {
  description = "(Required) Name of Storage Account"
  default="k8sedgeiotstorage"
}

variable "sku-sta" {
  description = "(Required) Sku Storage Account"
  default="Standard"
}

variable "replication-type-sta" {
  description = "(Required) Replication type on Storage Account"
  default="LRS"
}

variable "http-traffic-only-sta" {
  description = "(Required) HTTP traffic only enabled on Storage Account"
  default=true
}

variable "name-sta-container" {
  description = "(Required) Name of Storage Account Container"
  default="tfstate"
}

variable "access-type-sta-container" {
  description = "(Required) Access Type of Storage Account Container"
  default="private"
}

# Azure Event Hub
variable "name-evhns" {
  description = "(Required) Name of Azure Event Hub Namespaces"
  default="K8sEdge"
}

variable "sku-evhns" {
  description = "(Required) Sku Azure Event Hub Namepsaces"
  default="Basic"
}

variable "name-evh" {
  description = "(Required) Name of Azure Event Hub"
  default="K8sEdge"
}

variable "partition-count-evh" {
  description = "(Required) Event Hub Partition Count"
  default=2
}

variable "message-retention-evh" {
  description = "(Required) Event Hub message retention"
  default=1
}

variable "name-evhar" {
  description = "(Required) Event Hub Authorization Rule name"
  default="K8sEdgehubrule"
}

variable "send-evhar" {
  description = "(Required) Event Hub Authorization Rule send"
  default=true
}

# Log-analytics-workspace

variable "name-log_analytics" {
  description = "(Required) Log Analytics workspace name"
  default="K8sEdgeLogshub"
}

variable "solution_plan_map" {
  description = "(Optional) Map structure containing the list of solutions to be enabled."
  type        = map(any)
  default     = {}
}

variable "retention_in_days" {
  description = " (Optional) The workspace data retention in days. Possible values are either 7 (Free Tier only) or range between 30 and 730."
  type        = string
  default     = null
}

# Virtual Network
variable "name-vnet" {
  description = "(Required) Name of the Virtual Network."
  default = "Production"
}

variable "address_space" {
  description = "(Required) The Address Spaces of the Virtual Network."
  default = ["10.0.0.0/8"]
}

variable "dns_servers" {
  description = "(Optional) DNS Servers object."
  default     = null
}

variable "name_subnet_1" {
  description = "(Required) Name of subnets to create."
  default = "aks"
}

variable "address_space_subnet_1" {
  description = "(Required) Ip Address of subnets to create."
  default = ["10.240.0.0/16"]
}

variable "name_subnet_2" {
  description = "(Required) Name of subnets to create."
  default = "vms"
}

variable "address_space_subnet_2" {
  description = "(Required) Ip Address of subnets to create."
  default = ["10.241.0.0/24"]
}

variable "ddos_id" {
  description = "(Optional) ID of the DDoS protection plan if exists."
  default     = "ddospplan1"
}

variable "nsg_ids" {
  description = "A map of subnet name to Network Security Group IDs"
  type        = map(string)

  default = {
  }
}

variable "route_tables_ids" {
  description = "A map of subnet name to Route table ids"
  type        = map(string)
  default     = {}
}

#Kubernetes

variable "name" {
  description = "(Required) Name of the Kuberentes cluster"
  default="K8sEdgeVault"
}

variable "kubernetes_version" {
  type        = string
  description = "(Required) Version of Kubernetes specified when creating the AKS managed cluster. If not specified, the latest recommended version will be used at provisioning time (but won't auto-upgrade). NOTE: Upgrading your cluster may take up to 10 minutes per node."
  default     = "1.19.7"
}

variable "dns_prefix" {
  type        = string
  description = "(Optional) DNS prefix to append to the cluster. Default: name of the cluster"
  default     = null
}

variable "node_pool_name" {
  type        = string
  description = "(Optional) Node Pool name. Default: default"
  default     = "default"
}

variable "node_pool_count" {
  type        = number
  description = "(Optional) Number of pool virtual machines to create. Default: 3"
  default     = 3
}

variable "node_pool_vm_size" {
  type        = string
  description = "(Optional) VM Size to create in the default node pool. Default: Standard_DS3_v2"
  default     = "Standard_DS3_v2"
}

variable "node_pool_os_disk_size_gb" {
  type        = number
  description = "(Optional) The size of the OS Disk which should be used for each agent in the Node Pool. Changing this forces a new resource to be created. Default: 60"
  default     = 60
}

variable "node_pool_max_pods" {
  type        = number
  description = "(Optional) The maximum number of pods that can run on each agent. Changing this forces a new resource to be created."
  default     = 60
}

variable "auto_scaling_enable" {
  type        = bool
  description = "(Optional) Should the Kubernetes Auto Scaler be enabled for this Node Pool? Defaults to false."
  default     = false
}

variable "auto_scaling_min_count" {
  type        = number
  description = "(Optional) The minimum number of nodes which should exist in this Node Pool. If specified this must be between 1 and 100"
  default     = 0
}

variable "auto_scaling_max_count" {
  type        = number
  description = "(Optional) The maximum number of nodes which should exist in this Node Pool. If specified this must be between 1 and 100."
  default     = 0
}

variable "linux_admin_username" {
  type        = string
  description = "(Optional) The Admin Username for the Cluster. Changing this forces a new resource to be created. Defaults to cloudcommons"
  default     = "celz"
}

variable "linux_ssh_key" {
  type        = string
  description = "(OPtional) The Public SSH Key used to access the cluster. Changing this forces a new resource to be created."
  default     = null
}

variable "network_plugin" {
  type        = string
  description = "(Optional) Network plugin to use for networking. Currently supported values are azure and kubenet. Changing this forces a new resource to be created. Defaults to calico"
  default     = "azure"
}

variable "network_policy" {
  type        = string
  description = "(Optional) Sets up network policy to be used with Azure CNI. Network policy allows us to control the traffic flow between pods. This field can only be set when network_plugin is set to azure. Currently supported values are calico and azure. Changing this forces a new resource to be created. Defaults to calico"
  default     = "calico"
}

variable "network_load_balancer_sku" {
  type        = string
  description = "(Optional) Specifies the SKU of the Load Balancer used for this Kubernetes Cluster. Possible values are basic and standard. Defaults to basic."
  default     = "basic"
}

variable "rbac_enabled" {
  type        = bool
  description = "(Required) Is Role Based Access Control Enabled? Changing this forces a new resource to be created. Defaults to true"
  default     = true
}

variable "rbac_aad" {
  type        = bool
  description = "(Optional) Use Azure Active Directory as RBAC system. If not client_app_id is provided, this module will try creating an Azure Application for you"
  default     = false
}

variable "rbac_aad_client_app_id" {
  type        = string
  description = "(Optional) The Client ID of an Azure Active Directory Application. Changing this forces a new resource to be created."
  default     = null
}

variable "rbac_aad_server_app_id" {
  type        = string
  description = "(Optional) The Server ID of an Azure Active Directory Application. Changing this forces a new resource to be created."
  default     = null
}

variable "rbac_aad_server_app_secret" {
  type        = string
  description = "(Optional) The Server Secret of an Azure Active Directory Application. Changing this forces a new resource to be created."
  default     = null
}

variable "rbac_aad_tenant_id" {
  type        = string
  description = "(Optional) The Tenant ID used for Azure Active Directory Application. If this isn't specified the Tenant ID of the current Subscription is used. Changing this forces a new resource to be created."
  default     = null
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  description = "(Optional) The IP ranges to whitelist for incoming traffic to the masters."
  default     = null
}

variable "http_application_routing_enabled" {
  type        = bool
  description = "(Optional) Enables http application routing"
  default     = false
}

# Azure IoT Hub
variable "name-iot" {
  description = "(Required) Name of IoT Hub"
  default="k8sedgejumpstart"
}

variable "sku-iot" {
  description = "(Required) Sku of IoT Hub"
  default="S1"
}

variable "sku-capacity-iot" {
  description = "(Required) Sku capacity of IoT Hub"
  default="1"
}

variable "endpoint-type-iot" {
  description = "(Required) Endpoint Type of IoT Hub"
  default="AzureIotHub.StorageContainer"
}

variable "endpoint-name-iot" {
  description = "(Required) Endpoint name of IoT Hub"
  default="export"
}

variable "endpoint-batch-frequency-iot" {
  description = "(Required) Endpoint batch frequency in seconds of IoT Hub"
  default=60
}

variable "endpoint-chunk-iot" {
  description = "(Required) Endpoint max chunk size in bytes of IoT Hub"
  default=10485760
}

variable "endpoint-encoding-iot" {
  description = "(Required) Endpoint encoding of IoT Hub"
  default="Avro"
}

variable "endpoint-file-name-format-iot" {
  description = "(Required) Endpoint file name format of IoT Hub"
  default="{iothub}/{partition}_{YYYY}_{MM}_{DD}_{HH}_{mm}"
}

variable "route-name-iot" {
  description = "(Required) Route name of IoT Hub"
  default="export"
}
variable "route-source-iot" {
  description = "(Required) Route source of IoT Hub"
  default="DeviceMessages"
}
variable "route-condition-iot" {
  description = "(Required) Route condition of IoT Hub"
  default="true"
}
variable "route-endpoint-names-iot" {
  description = "(Required) Route endpoint names of IoT Hub"
  default=["export"]
}
variable "route-enabled-names-iot" {
  description = "(Required) Route enabled names of IoT Hub"
  default=true
}

# Virtual Machine

variable "name-vm" {
  description = "(Required) Name of Virtual Machine"
  default="EdgeDeviceSim"
}

variable "sku-vm" {
  description = "(Required) Name of Virtual Machine"
  default="Standard_DS1_v2"
}

variable "name-disk-vm" {
  description = "(Required) Name of disk - Virtual Machine"
  default="EdgeDeviceDisk"
}

variable "caching-disk-vm" {
  description = "(Required) Caching of disk - Virtual Machine"
  default="ReadWrite"
}

variable "sta-disk-vm" {
  description = "(Required) Storage Account Type of disl - Virtual Machine"
  default="Premium_LRS"
}

variable "image-publisher-vm" {
  description = "(Required) Image Publisher SO of Virtual Machine"
  default="Canonical"
}

variable "image-offer-vm" {
  description = "(Required) Image Publisher SO of Virtual Machine"
  default="UbuntuServer"
}

variable "image-sku-vm" {
  description = "(Required) Image Publisher SO of Virtual Machine"
  default="18.04-LTS"
}

variable "image-version-vm" {
  description = "(Required) Image Publisher SO of Virtual Machine"
  default="latest"
}

variable "user-name-vm" {
  description = "(Required) User of Virtual Machine"
  default="azureuser"
}

variable "user-password-vm" {
  description = "(Required) Password of Virtual Machine"
  default="Password1234!"
}

variable "password_authentication-vm" {
  description = "(Required) Password Authentication of Virtual Machine"
  default=false
}

# Network Interface
variable "name-nic" {
  description = "(Required) Name of Network Interface"
  default="edgedevicesim-nic"
}

variable "name-ipconfig-nic" {
  description = "(Required) Ip Configuration of Network Interface"
  default="testconfiguration1"
}

variable "private-ip-allocation-nic" {
  description = "(Required) Private Ip Address Allocation of Network Interface"
  default="Dynamic"
}

# Public IP
variable "name-publicip" {
  description = "(Required) Name of Public IP"
  default="myPublicIP"
}

variable "allocation-method-publicip" {
  description = "(Required) Allocation Method of Public IP"
  default="Dynamic"
}
