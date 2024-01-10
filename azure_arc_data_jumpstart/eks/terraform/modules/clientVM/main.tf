variable "awsAccessKeyId" {
  type = string
  description = "AWS Access key id"
}

variable "awsSecretAccessKey" {
  type = string
  description = "AWS Access Secret"
  sensitive = true
}

variable "awsDefaultRegion" {
  type = string
  description = "the location of all AWS resources"
}
variable "resourceGroup" {
  type        = string
  description = "Azure Resource Group"
}

variable "spnClientId" {
  type        = string
  description = "Client id of the service principal"
}

variable "spnClientSecret" {
  type        = string
  description = "Client secret of the service principal"
  sensitive = true
}

variable "spnAuthority" {
  type        = string
  description = "Authority for Service Principal authentication"
  default     = "https://login.microsoftonline.com"
}
variable "spnTenantId" {
  type        = string
  description = "Tenant id of the service principal"
}

variable "subscriptionId" {
  type        = string
  description = "Subscription ID"
}

variable "azdataUsername" {
  type        = string
  default = "arcdemo"
}

variable "azdataPassword" {
  type        = string
  default = "ArcPassword123!!"
  sensitive = true
}

variable "acceptEula" {
  type        = string
  default = "yes"
}

variable "arcDcName" {
  type        = string
  default = "arcdatactrl"
}

variable "azureLocation" {
  type        = string
  description = "Location for all resources"
}

variable "workspaceName" {
  type        = string
  description = "Name for the environment Azure Log Analytics workspace"
}

variable "deploySQLMI" {
  type        = bool
  default = false
  description = "SQL Managed Instance deployment"
}

variable "SQLMIHA" {
  type        = bool
  default = false
  description = "SQL Managed Instance high-availability deployment"
}

variable "deployPostgreSQL" {
  type        = bool
  default = false
  description = "PostgreSQL deployment"
}

variable "customLocationObjectId" {
  type   = string
  description = "Custom Location object Id"
}

variable "clusterName" {
  type        = string
  description = "The name of the Kubernetes cluster resource."
}

variable "templateBaseUrl" {
  type        = string
  description = "Base URL for ARM template"
}

variable "eks_instance_types" {
  description = "EKS node instance type"
  default     = "t3.xlarge"
  type        = string
}

variable "windows_instance_types" {
  description = "EC2 Client instance Windows type"
  default     = "t2.medium"
  type        = string
}

variable "key_name" {
  description = "Your AWS Key Pair name"
  type        = string
  default     = "terraform"
}
variable "key_pair_filename" {
  description = "Your AWS Key Pair *.pem filename"
  type        = string
  default     = "terraform.pem"
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
  //availability_zone = var.aws_availabilityzone
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
  tags = {
    "Name" = "Arc-Data-Demo"
  }

  user_data = file("artifacts/user_data.txt")

//provisioner "local-exec" {
//    command = "aws eks update-kubeconfig --region ${var.awsLocation} --name ${var.clusterName} --kubeconfig config"
//}
//  provisioner "local-exec" {
//    command = "terraform output -raw kubeconfig > config"
//  }


/*  provisioner "file" {
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
  }*/

  /*provisioner "file" {
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

provisioner "remote-exec" {
    inline = [
      "powershell.exe -c Invoke-WebRequest -Uri '${var.templateBaseUrl}artifacts/Bootstrap.ps1' -OutFile C:/Temp/Bootstrap.ps1",
      "powershell.exe -ExecutionPolicy Bypass -File C:/Temp/Bootstrap.ps1 -adminUsername Administrator -spnClientId ${var.spnClientId} -spnClientSecret ${var.spnClientSecret} -spnTenantId ${var.spnTenantId} -spnAuthority ${var.spnAuthority} -subscriptionId ${var.subscriptionId} -resourceGroup ${var.resourceGroup} -azdataUsername ${var.azdataUsername} -azdataPassword ${var.azdataPassword} -acceptEula ${var.acceptEula} -arcDcName ${var.arcDcName} -azureLocation ${var.azureLocation} -deploySQLMI ${var.deploySQLMI} -SQLMIHA ${var.SQLMIHA} -deployPostgreSQL  ${var.deployPostgreSQL } -customLocationObjectId ${var.customLocationObjectId} -workspaceName ${var.workspaceName} -templateBaseUrl ${var.templateBaseUrl} -awsAccessKeyId ${var.awsAccessKeyId} -awsSecretAccessKey ${var.awsSecretAccessKey} -awsDefaultRegion ${var.awsDefaultRegion}"
    ]

    connection {
      host     = self.public_ip
      https    = false
      insecure = true
      timeout  = "60m"
      type     = "winrm"
      user     = "Administrator"
      password = rsadecrypt(self.password_data, file(var.key_pair_filename))
    }
  }

/*provisioner "local-exec" {
  command = "terraform output -raw config_map_aws_auth > configmap.yml"
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
}*/

}

output "password_decrypted" {
  value = rsadecrypt(aws_instance.windows.password_data, file(var.key_pair_filename))
}
