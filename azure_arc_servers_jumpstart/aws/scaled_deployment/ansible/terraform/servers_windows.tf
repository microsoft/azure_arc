locals {
  hostname_windows = "${var.hostname}-winsrv"
}

resource "aws_instance" "windows" {
  count                       = var.server_count
  ami                         = data.aws_ami.Windows_2022.image_id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-all.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id
  get_password_data           = "true"
  tags = {
    Name     = "${local.hostname_windows}-${count.index + 1}"
    AppGroup = "WindowsFarm"
  }

  user_data = element(data.template_file.user_data_win.*.rendered, count.index)
}

data "template_file" "user_data_win" {
  count = var.server_count
  template = templatefile("scripts/user_data.txt", {
    hostname = "${local.hostname_windows}-${count.index + 1}"
    }
  )
}
