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

  user_data = file("artifacts/user_data.txt")

  provisioner "local-exec" {
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
  }

  provisioner "file" {
    source      = "artifacts/Bootstrap.ps1"
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

  provisioner "file" {
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

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C://Temp/Bootstrap.ps1"
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

  depends_on = [aws_eks_node_group.arcdemo]

}

resource "local_file" "azure_arc" {
  content = templatefile("artifacts/azure_arc.ps1.tmpl", {
    spnClientId            = var.SPN_CLIENT_ID
    spnClientSecret        = var.SPN_CLIENT_SECRET
    spnTenantId            = var.SPN_TENANT_ID
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
}

output "password_decrypted" {
  value = rsadecrypt(aws_instance.windows.password_data, file(var.key_pair_filename))
}
