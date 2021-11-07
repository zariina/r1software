resource "aws_key_pair" "class" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")
}


resource "aws_security_group" "allow_tls" {
  name        = var.sec_group_name
  description = "Allow TLS inbound traffic"

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "web" {
  ami                    = data.aws_ami.centos.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  key_name               = aws_key_pair.class.key_name
}


resource "null_resource" "commands" {
  depends_on = [aws_instance.web, aws_security_group.allow_tls]
  triggers = {
    always_run = timestamp()
  }
  # Push files to remote server
  provisioner "file" {
    connection {
      host        = aws_instance.web.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file("~/.ssh/id_rsa")
    }
    source      = "r1soft.repo"
    destination = "/tmp/r1soft.repo"
  }
  # Execute linux commands on remote machine
  provisioner "remote-exec" {
    connection {
      host        = aws_instance.web.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file("~/.ssh/id_rsa")
    }
    inline = [
      "sudo cp /tmp/r1soft.repo /etc/yum.repos.d/",
      "sudo yum install serverbackup-enterprise -y",
      "sudo serverbackup-setup --user admin --pass redhat",
      "sudo systemctl restart sbm-server",
      "sudo systemctl start sbm-server",
      "sudo r1soft-setup --user admin --pass redhat --http-port 80 --http-port 443",
    ]
  }
}
