provider "aws" {
  region = var.aws_region
}

resource "aws_spot_instance_request" "android_emulator" {
  instance_type = "c5.metal"
  ami           = data.aws_ami.ubuntu.id
  spot_type    = "persistent"
  
  wait_for_fulfillment = true
  spot_price           = var.spot_price

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = var.subnet_id
  key_name              = var.key_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y \
                android-sdk-platform-tools \
                android-sdk-build-tools \
                android-sdk-platforms \
                android-sdk-licenses \
                android-sdk-emulator \
                android-sdk-cmdline-tools-latest \
                android-sdk-extras-* \
                android-sdk-ndkinstall \
                qemu-kvm \
                libvirt-daemon-system \
                libvirt-clients \
                bridge-utils
              sdkmanager "platforms;android-33"
              usermod -aG kvm ubuntu
              usermod -aG libvirt ubuntu
              EOF

  tags = {
    Name = "android-emulator-spot"
    Environment = var.environment
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_android_emulator"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from specified CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_android_emulator"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}