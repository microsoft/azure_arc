// An Azure Resource Group
resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
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

resource "aws_security_group" "ingress-all" {
  name   = "allow-all-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
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

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_key_pair" "keypair" {
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "default" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-all.id]
  subnet_id                   = aws_subnet.subnet1.id
  user_data                   = data.template_file.user_data.rendered
  tags = {
    Name = var.hostname
  }

  connection {
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    agent       = false
    host        = aws_instance.default.public_ip
  }

  provisioner "file" {
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"
  }
  provisioner "file" {
    source      = "scripts/install_arc_agent.sh"
    destination = "/tmp/install_arc_agent.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_arc_agent.sh",
      "/tmp/install_arc_agent.sh",
    ]
  }
}

resource "local_file" "install_arc_agent_sh" {
  content = templatefile("scripts/install_arc_agent.sh.tmpl", {
    resourceGroup = var.azure_resource_group
    location      = var.azure_location
    }
  )
  filename = "scripts/install_arc_agent.sh"
}

data "template_file" "user_data" {
  template = templatefile("scripts/user_data.tmpl", {
    hostname = var.hostname
    }
  )
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = aws_instance.default.public_ip
}