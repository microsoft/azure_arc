#
# Providers Configuration
#

terraform {
  required_version = "~> 1.0"
  required_providers {
    alicloud  = {
      source = "aliyun/alicloud"
      version = "1.124.2"
    }
    random = "~> 3.1"
  }
}

provider "alicloud" {}
