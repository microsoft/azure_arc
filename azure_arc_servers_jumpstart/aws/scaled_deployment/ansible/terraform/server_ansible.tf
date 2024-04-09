resource "aws_instance" "ansible" {
  ami                         = data.aws_ami.centos.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-all.id]
  subnet_id                   = aws_subnet.subnet1.id
  tags = {
    Name = "aws-ansible-server"
  }

  connection {
    user        = "fedora"
    private_key = file("~/.ssh/id_rsa")
    agent       = false
    host        = aws_instance.ansible.public_ip
  }

  provisioner "file" {
    source      = "ansible_config"
    destination = "/home/fedora/ansible"
  }

  provisioner "file" {
    source      = "~/.ssh/id_rsa"
    destination = "/home/fedora/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install python3-pip ansible -y",
      "sudo python3 -m pip install --upgrade setuptools",
      "sudo python3 -m pip install wheel setuptools_rust",
      "sudo python3 -m pip install --upgrade pip",
      "sudo curl https://sh.rustup.rs -sSf | sh -s -- -y",
      "sudo python3 -m pip install botocore boto3 pywinrm",
      "sudo chmod 600 /home/fedora/.ssh/id_rsa"
    ]
  }

}

// A variable for extracting the external ip of the instance
output "ansible_ip" {
  value = aws_instance.ansible.public_ip
}
