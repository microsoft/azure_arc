module "managed-k8s" {
  source            = "terraform-alicloud-modules/managed-kubernetes/alicloud"

  k8s_name_prefix = "azure-arc-poc"
  new_vpc         = true
  vpc_cidr        = "192.168.0.0/16"
  vswitch_cidrs = [
    "192.168.1.0/24",
  ]
  worker_instance_types = ["ecs.g6.large"]
  new_sls_project = true

  kube_config_path = "~/.kube/config_alicloudArc"

  cluster_addons = [
   {
     name   = "flannel",
     config = "",
   },
   {
     name   = "flexvolume",
     config = "",
   },
   {
     name   = "alicloud-disk-controller",
     config = "",
   },
   {
     name   = "logtail-ds",
     config = "{\"IngressDashboardEnabled\":\"true\"}",
   },
   {
     name   = "nginx-ingress-controller",
     config = "{\"IngressSlbNetworkType\":\"internet\"}",
   },
 ]
}
