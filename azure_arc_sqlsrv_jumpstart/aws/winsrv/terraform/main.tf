resource "azurerm_resource_group" "azure_rg" {
  name     = var.resourceGroup
  location = var.location
  tags = {
    project = "jumpstart_azure_arc_sql"
  }
}

resource "local_file" "sql_ps1" {
  content = templatefile("scripts/sql.ps1.tmpl", {
    admin_user               = var.admin_user
    admin_password           = var.admin_password
    resourceGroup            = var.resourceGroup
    location                 = var.location
    servicePrincipalAppId    = var.servicePrincipalAppId
    servicePrincipalSecret   = var.servicePrincipalSecret
    servicePrincipalTenantId = var.servicePrincipalTenantId
    }
  )
  filename = "scripts/sql.ps1"
}

resource "local_file" "install_arc_agent_ps1" {
  content = templatefile("scripts/install_arc_agent.ps1.tmpl", {
    resourceGroup            = var.resourceGroup
    location                 = var.location
    subId                    = var.subId
    servicePrincipalAppId    = var.servicePrincipalAppId
    servicePrincipalSecret   = var.servicePrincipalSecret
    servicePrincipalTenantId = var.servicePrincipalTenantId
    }
  )
  filename = "scripts/install_arc_agent.ps1"
}

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

data "aws_ami" "Windows_2019" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

locals {
  vars = {
    admin_user     = var.admin_user
    admin_password = var.admin_password
  }
}

data "template_file" "user_data" {
  template = "${file("scripts/user_data.tpl")}"
  vars = {
    admin_user     = var.admin_user
    admin_password = var.admin_password
    hostname = var.hostname
  }
}

resource "aws_instance" "windows" {
  ami                         = data.aws_ami.Windows_2019.image_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.allow_rdp_winrm.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id
  get_password_data           = "true"
  user_data                   = data.template_file.user_data.rendered

  provisioner "file" {
    source      = "scripts/install_arc_agent.ps1"
    destination = "C:/tmp/install_arc_agent.ps1"

    connection {
      type     = "winrm"
      host     = self.public_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/sql.ps1"
    destination = "C:/tmp/sql.ps1"

    connection {
      type     = "winrm"
      host     = self.public_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/restore_db.ps1"
    destination = "C:/tmp/restore_db.ps1"

    connection {
      type     = "winrm"
      host     = self.public_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "file" {
    source      = "scripts/mma.json"
    destination = "C:/tmp/mma.json"

    connection {
      type     = "winrm"
      host     = self.public_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp//sql.ps1"
    ]

    connection {
      type     = "winrm"
      host     = self.public_ip
      port     = 5985
      user     = var.admin_user
      password = var.admin_password
      https    = false
      insecure = true
      timeout  = "10m"
    }
  }
}

output "public_ip" {
  value = aws_instance.windows.*.public_ip
}
