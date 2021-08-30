// Instance_types data source for instance_type
data "alicloud_instance_types" "default" {
  //  kubernetes_node_role = "Worker"
  cpu_core_count = var.cpu_core_count
  memory_size    = var.memory_size
}

// Zones data source for availability_zone
data "alicloud_zones" "default" {
  available_instance_type = data.alicloud_instance_types.default.ids[0]
}

// If there is not specifying vpc_id, the module will launch a new vpc
resource "alicloud_vpc" "new" {
  count      = var.new_vpc == true ? 1 : 0
  cidr_block = var.vpc_cidr
  vpc_name   = local.new_vpc_name
  tags       = local.new_vpc_tags
}

// According to the vswitch cidr blocks to launch several vswitches
resource "alicloud_vswitch" "new" {
  count             = var.new_vpc == true ? length(var.vswitch_cidrs) : 0
  vpc_id            = concat(alicloud_vpc.new.*.id, [""])[0]
  cidr_block        = var.vswitch_cidrs[count.index]
  zone_id           = length(var.availability_zones) > 0 ? element(var.availability_zones, count.index) : element(data.alicloud_zones.default.ids.*, count.index)
  vswitch_name      = local.new_vpc_name
  tags              = local.new_vpc_tags
}

resource "alicloud_nat_gateway" "new" {
  count  = var.new_vpc == true ? 1 : 0
  vpc_id = concat(alicloud_vpc.new.*.id, [""])[0]
  name   = local.new_vpc_name
  //  tags   = local.new_vpc_tags
}

resource "alicloud_eip" "new" {
  count     = var.new_vpc == true ? 1 : 0
  bandwidth = var.new_eip_bandwidth
  name      = local.new_vpc_name
  tags      = local.new_vpc_tags
}

resource "alicloud_eip_association" "new" {
  count         = var.new_vpc == true ? 1 : 0
  allocation_id = concat(alicloud_eip.new.*.id, [""])[0]
  instance_id   = concat(alicloud_nat_gateway.new.*.id, [""])[0]
}

resource "alicloud_snat_entry" "new" {
  count             = var.new_vpc == true ? length(var.vswitch_cidrs) : 0
  snat_table_id     = concat(alicloud_nat_gateway.new.*.snat_table_ids, [""])[0]
  source_vswitch_id = alicloud_vswitch.new[count.index].id
  snat_ip           = concat(alicloud_eip.new.*.ip_address, [""])[0]
}
