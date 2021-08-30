resource "alicloud_cs_managed_kubernetes" "this" {
  count                 = length(local.vswitch_ids) > 0 ? 1 : 0 
  name                  = local.k8s_name
  worker_vswitch_ids    = local.vswitch_ids
  new_nat_gateway       = var.new_vpc == true ? false : var.new_nat_gateway
  worker_disk_category  = var.worker_disk_category
  password              = var.ecs_password
  pod_cidr              = var.k8s_pod_cidr
  service_cidr          = var.k8s_service_cidr
  slb_internet_enabled  = true
  install_cloud_monitor = true
  version               = var.kubernetes_version
  worker_instance_types = var.worker_instance_types
  worker_number         = var.worker_number
  dynamic "addons" {
    for_each = var.cluster_addons
    content {
      name   = lookup(addons.value, "name", var.cluster_addons)
      config = lookup(addons.value, "config", var.cluster_addons)
    }   
  }
  kube_config     = var.kube_config_path
  client_cert     = var.client_cert_path
  client_key      = var.client_key_path
  cluster_ca_cert = var.cluster_ca_cert_path
  image_id        = "aliyun_2_1903_x64_20G_alibase_20210325.vhd"

  depends_on = [alicloud_snat_entry.new]
}
