//Autoscaling group
variable "region" {
  description = "The region ID used to launch this module resources. If not set, it will be sourced from followed by ALICLOUD_REGION environment variable and profile."
  type        = string
  default     = ""
}

variable "profile" {
  description = "The profile name as set in the shared credentials file. If not set, it will be sourced from the ALICLOUD_PROFILE environment variable."
  type        = string
  default     = ""
}
variable "shared_credentials_file" {
  description = "This is the path to the shared credentials file. If this is not set and a profile is specified, $HOME/.aliyun/config.json will be used."
  type        = string
  default     = ""
}

variable "skip_region_validation" {
  description = "Skip static validation of region ID. Used by users of alternative AlibabaCloud-like APIs or users w/ access to regions that are not public (yet)."
  type        = bool
  default     = false
}

# VPC variables
variable "new_vpc" {
  description = "Create a new vpc for this module."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "The cidr block used to launch a new vpc."
  type        = string
  default     = "192.168.0.0/16"
}

# VSwitch variables
variable "vswitch_ids" {
  description = "List Ids of existing vswitch."
  type        = list(string)
  default     = []
}

variable "vswitch_cidrs" {
  description = "List cidr blocks used to create several new vswitches when 'new_vpc' is true."
  type        = list(string)
  default     = ["192.168.1.0/24"]
}

variable "availability_zones" {
  description = "List available zone ids used to create several new vswitches when 'vswitch_ids' is not specified. If not set, data source `alicloud_zones` will return one automatically."
  type        = list(string)
  default     = []
}

variable "new_eip_bandwidth" {
  description = "The bandwidth used to create a new EIP when 'new_vpc' is true."
  type        = number
  default     = 50
}
variable "new_nat_gateway" {
  description = "Seting it to true can create a new nat gateway automatically in a existing VPC. If 'new_vpc' is true, it will be ignored."
  type        = bool
  default     = false
}
# Cluster nodes variables
variable "cpu_core_count" {
  description = "CPU core count is used to fetch instance types."
  type        = number
  default     = 1
}

variable "memory_size" {
  description = "Memory size used to fetch instance types."
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Desired Kubernetes version"
  type        = string
  default     = ""
}

variable "worker_instance_types" {
  description = "The ecs instance type used to launch worker nodes. If not set, data source `alicloud_instance_types` will return one based on `cpu_core_count` and `memory_size`."
  type        = list(string)
  default     = ["ecs.n4.xlarge"]
}

variable "cluster_addons" {
  description = "Addon components in kubernetes cluster"
  type = list(object({
    name   = string
    config = string
  }))
  default = []
}

variable "worker_disk_category" {
  description = "The system disk category used to launch one or more worker nodes."
  type        = string
  default     = "cloud_efficiency"
}

variable "worker_disk_size" {
  description = "The system disk size used to launch one or more worker nodes."
  type        = number
  default     = 40
}

variable "ecs_password" {
  description = "The password of worker nodes."
  type        = string
  default     = "Abc12345"
}

variable "worker_number" {
  description = "The number of kubernetes cluster work nodes."
  type        = number
  default     = 2
}

variable "k8s_name_prefix" {
  description = "The name prefix used to create managed kubernetes cluster."
  type        = string
  default     = "terraform-alicloud-managed-kubernetes"
}

variable "k8s_pod_cidr" {
  description = "The kubernetes pod cidr block. It cannot be equals to vpc's or vswitch's and cannot be in them. If vpc's cidr block is `172.16.XX.XX/XX`, it had better to `192.168.XX.XX/XX` or `10.XX.XX.XX/XX`."
  type        = string
  default     = "172.20.0.0/16"
}

variable "k8s_service_cidr" {
  description = "The kubernetes service cidr block. It cannot be equals to vpc's or vswitch's or pod's and cannot be in them. Its setting rule is same as `k8s_pod_cidr`."
  type        = string
  default     = "172.21.0.0/20"
}

variable "cluster_network_type" {
  description = "(Deprecated from v1.3.0, use 'cluster_addons' instead)Network type, valid options are `flannel` and `terway`."
  type        = string
  default     = "flannel"
}

variable "new_sls_project" {
  description = "(Deprecated from v1.3.0, use 'cluster_addons' instead)Create a new sls project for this module."
  type        = bool
  default     = false
}
variable "sls_project_name" {
  description = "(Deprecated from v1.3.0, use 'cluster_addons' instead)Specify a existing sls project for this module."
  type        = string
  default     = ""
}

variable "kube_config_path" {
  description = "The path of kube config, like ~/.kube/config"
  type        = string
  default     = ""
}
variable "client_cert_path" {
  description = "The path of client certificate, like ~/.kube/client-cert.pem"
  type        = string
  default     = ""
}
variable "client_key_path" {
  description = "The path of client key, like ~/.kube/client-key.pem"
  type        = string
  default     = ""
}
variable "cluster_ca_cert_path" {
  description = "The path of cluster ca certificate, like ~/.kube/cluster-ca-cert.pem"
  type        = string
  default     = ""
}