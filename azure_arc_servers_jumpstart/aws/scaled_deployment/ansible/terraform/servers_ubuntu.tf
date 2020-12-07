locals {
  hostname_ubuntu = "${var.hostname}-ubuntu"
}

resource "aws_instance" "ubuntu" {
  count                       = var.server_count
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-all.id]
  subnet_id                   = aws_subnet.subnet1.id
  user_data                   = element(data.template_file.user_data.*.rendered, count.index)
  tags = {
    Name     = "${local.hostname_ubuntu}-${count.index + 1}"
    AppGroup = "LinuxFarm"
  }
}

data "template_file" "user_data" {
  count = var.server_count
  template = templatefile("scripts/user_data.tmpl", {
    hostname = "${local.hostname_ubuntu}-${count.index + 1}"
    }
  )
}
