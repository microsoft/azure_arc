#
# Providers Configuration
#

terraform {
  required_version = "~> 1.0"
  required_providers {
    alicloud  = "~> 1.119"
    random = "~> 3.1"
  }
}

provider "alicloud" {}
