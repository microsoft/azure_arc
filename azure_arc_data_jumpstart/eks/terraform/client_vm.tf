resource "local_file" "azure_arc" {
  content = templatefile("scripts/azure_arc.ps1.tmpl", {
    AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
    client_id             = var.client_id
    client_secret         = var.client_secret
    tenant_id             = var.tenant_id
    AZDATA_USERNAME       = var.AZDATA_USERNAME
    AZDATA_PASSWORD       = var.AZDATA_PASSWORD
    ACCEPT_EULA           = var.ACCEPT_EULA
    REGISTRY_USERNAME     = var.REGISTRY_USERNAME
    REGISTRY_PASSWORD     = var.REGISTRY_PASSWORD
    AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
    ARC_DC_NAME           = var.ARC_DC_NAME
    ARC_DC_SUBSCRIPTION   = var.ARC_DC_SUBSCRIPTION
    ARC_DC_RG             = var.ARC_DC_RG
    ARC_DC_REGION         = var.ARC_DC_REGION
    }
  )
  filename = "scripts/azure_arc.ps1"
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

resource "aws_instance" "windows" {
  ami                         = data.aws_ami.Windows_2019.image_id
  instance_type               = var.windows_instance_types
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.allow_rdp_winrm.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id
  get_password_data           = "true"

  user_data = file("scripts/user_data.txt")

  provisioner "local-exec" {
    command = "terraform output kubeconfig > config"
  }

  provisioner "local-exec" {
    command = "terraform output config_map_aws_auth > configmap.yml"
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
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  provisioner "file" {
    source      = "configmap.yml"
    destination = "C:/tmp/configmap.yml"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  provisioner "file" {
    source      = "scripts/azure_arc.ps1"
    destination = "C:/tmp/azure_arc.ps1"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  provisioner "file" {
    source      = "scripts/ClientTools.ps1"
    destination = "C:/tmp/ClientTools.ps1"

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp/azure_arc.ps1"
    ]

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://tmp/ClientTools.ps1"
    ]

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "5m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file("terraform.pem"))
    }
  }

  depends_on = [aws_eks_node_group.arcdemo]

}

output "password_decrypted" {
  value = rsadecrypt(aws_instance.windows.password_data, file(var.key_pair_filename))
}
