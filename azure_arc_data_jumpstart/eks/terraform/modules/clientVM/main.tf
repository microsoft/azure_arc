variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "admin_username" {
  type        = string
  description = "Username for the Windows client virtual machine."
}

variable "admin_password" {
  type        = string
  description = "Password for Windows admin account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long."
  sensitive   = true
  default = rsadecrypt(self.password_data, file(var.key_pair_filename))
}

variable "template_base_url" {
  type        = string
  description = "Base URL for the GitHub repo where the ArcBox artifacts are located."
}

variable "data_controller_username" {
  type        = string
  description = "Arc Data Controller user name."
  default     = "arcdemo"
}

variable "data_controller_password" {
  type        = string
  description = "Arc Data Controller password"
  default     = "ArcPassword123!!"
  sensitive   = true
}

variable "accept_eula" {
  type        = string
  description = "Accept EULA for all ArcBox scripts."
  default     = "yes"
}

variable "storage_account_name" {
  type        = string
  description = "Name for the staging storage account used to hold kubeconfig."
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "spn_client_id" {
  type        = string
  description = "Arc Service Principal clientID."
}

variable "spn_client_secret" {
  type        = string
  description = "Arc Service Principal client secret."
  sensitive   = true
}

variable "spn_tenant_id" {
  type        = string
  description = "Arc Service Principal tenantID."
}

variable "github_username" {
  type        = string
  description = "Specify a GitHub username for ArcBox DevOps"
  default     = "microsoft"
}

variable "github_repo" {
  type        = string
  description = "Specify a GitHub repo (used for testing purposes)"
}

variable "github_branch" {
  type        = string
  description = "Specify a GitHub branch (used for testing purposes)"
}

variable "trigger_at_logon" {
  type        = bool
  description = "Whether or not the automation scripts will trigger at log on, or at startup. True for AtLogon, False for AtStartup."
  default     = true
}

### THESE ARE LEGACY VARIABLES FOR BACKWARDS COMPATIBILITY WITH LEGACY SCRIPT FUNCTIONS ###

variable "spn_authority" {
  type        = string
  description = "Authority for Service Principal authentication"
  default     = "https://login.microsoftonline.com"
}

variable "registry_username" {
  type        = string
  description = "Registry username"
  default     = "registryUser"
}

variable "registry_password" {
  type        = string
  description = "Registry password"
  default     = "registrySecret"
}

variable "data_controller_name" {
  type        = string
  description = "Arc Data Controller name."
  default     = "arcdatactrl"
}

variable "sql_mi_name" {
  type        = string
  description = "Arc Data Controller name."
  default     = "arcdatactrl"
}

variable "postgres_name" {
  type        = string
  description = "Name of PostgreSQL server group."
  default     = "arcpg"
}

variable "postgres_worker_node_count" {
  type        = number
  description = "Number of PostgreSQL worker nodes."
  default     = 3
}

variable "postgres_data_size" {
  type        = number
  description = "Size of data volumes in MB."
  default     = 1024
}

variable "postgres_service_type" {
  type        = string
  description = "How PostgreSQL service is accessed through Kubernetes CNI."
  default     = "LoadBalancer"
}
###########################################################################################

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_security_group" "allow_rdp_winrm" {
  name        = "allow_rdp_winrm"
  description = "Allow RDP and WinRM traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 3389 #  By default, the windows server listens on TCP port 3389 for RDP
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5985 #  By default, this is the WinRM port
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "subnet1" {
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 3, 1)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.aws_availabilityzone
}

data "aws_ami" "Windows_2022" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

resource "aws_instance" "windows" {
  ami                         = data.aws_ami.Windows_2022.image_id
  instance_type               = var.windows_instance_types
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.allow_rdp_winrm.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id
  get_password_data           = "true"

  //user_data = file("artifacts/user_data.txt")

  /*provisioner "local-exec" {
    command = "terraform output -raw kubeconfig > config"
  }

  provisioner "local-exec" {
    command = "terraform output -raw config_map_aws_auth > configmap.yml"
  }

  provisioner "file" {
    source      = "config"
    destination = "C:/Users/Administrator/.kube/config"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

  provisioner "file" {
    source      = "configmap.yml"
    destination = "C:/Temp/configmap.yml"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

  provisioner "file" {
    source      = "artifacts/azure_arc.ps1"
    destination = "C:/Temp/azure_arc.ps1"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }*/

  provisioner "file" {
    source      = "${var.template_base_url}artifacts/Bootstrap.ps1"
    destination = "C:/Temp/Bootstrap.ps1"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

  /*provisioner "file" {
    source      = "artifacts/DataServicesLogonScript.ps1"
    destination = "C:/Temp/DataServicesLogonScript.ps1"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://Temp/azure_arc.ps1"
    ]

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }
*/
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C://Temp/Bootstrap.ps1 -adminUsername 'Administrator' -spnClientId ${var.spn_client_id} -spnClientSecret ${var.spn_client_secret} -spnTenantId ${var.spn_tenant_id} -spnAuthority ${var.spn_authority} -subscriptionId ${data.azurerm_subscription.primary.subscription_id} -resourceGroup ${data.azurerm_resource_group.rg.name} -azdataUsername ${var.data_controller_username} -azdataPassword ${var.data_controller_password} -acceptEula ${var.accept_eula} -registryUsername ${var.registry_username} -registryPassword ${var.registry_password} -arcDcName ${var.data_controller_name} -azureLocation ${data.azurerm_resource_group.rg.location} -mssqlmiName ${var.sql_mi_name} -POSTGRES_NAME ${var.postgres_name} -POSTGRES_WORKER_NODE_COUNT ${var.postgres_worker_node_count} -POSTGRES_DATASIZE ${var.postgres_data_size} -POSTGRES_SERVICE_TYPE ${var.postgres_service_type} -stagingStorageAccountName ${var.storage_account_name} -workspaceName ${var.workspace_name} -templateBaseUrl ${var.template_base_url} -flavor ${var.deployment_flavor} -automationTriggerAtLogon ${var.trigger_at_logon} -capiArcDataClusterName ${var.capi_arc_data_cluster_name} -k3sArcClusterName ${var.k3s_arc_cluster_name} -githubUser ${var.github_username}"
    ]

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "10m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

  //depends_on = [aws_eks_node_group.arcdemo]

}

/*resource "local_file" "azure_arc" {
  content = templatefile("artifacts/azure_arc.ps1.tmpl", {
    AWS_ACCESS_KEY_ID      = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY  = var.AWS_SECRET_ACCESS_KEY
    spnClientId            = var.SPN_CLIENT_ID
    spnClientSecret        = var.SPN_CLIENT_SECRET
    spnTenantId            = var.SPN_TENANT_ID
    customLocationOid      = var.CUSTOM_LOCATION_OID
    spnAuthority           = var.SPN_AUTHORITY
    AZDATA_USERNAME        = var.AZDATA_USERNAME
    AZDATA_PASSWORD        = var.AZDATA_PASSWORD
    ACCEPT_EULA            = var.ACCEPT_EULA
    arcDcName              = var.ARC_DC_NAME
    subscriptionId         = var.ARC_DC_SUBSCRIPTION
    resourceGroup          = var.ARC_DC_RG
    azureLocation          = var.ARC_DC_REGION
    deploySQLMI            = var.deploy_SQLMI
    deployPostgreSQL       = var.deploy_PostgreSQL
    templateBaseUrl        = var.templateBaseUrl
    }
  )
  filename = "artifacts/azure_arc.ps1"
}*/

output "password_decrypted" {
  value = rsadecrypt(aws_instance.windows.password_data, file(var.key_pair_filename))
}
