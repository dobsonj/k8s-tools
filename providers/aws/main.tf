terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.64.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region
  default_tags {
    tags = {
      Name = var.tag_name
      "kubernetes.io/cluster/${var.tag_name}" = "owned"
    }
  }
}

resource "aws_key_pair" "dev_key01" {
  key_name = var.tag_name
  public_key = file(var.public_key_file)
}

resource "aws_vpc" "dev_vpc01" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "dev_sg01" {
  depends_on = [ aws_vpc.dev_vpc01 ]
  vpc_id = aws_vpc.dev_vpc01.id
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "dev_subnet01" {
  depends_on = [ aws_vpc.dev_vpc01 ]
  vpc_id = aws_vpc.dev_vpc01.id
  cidr_block = var.cidr_block
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "dev_gateway01" {
  vpc_id = aws_vpc.dev_vpc01.id
}
 
resource "aws_route_table" "dev_routetable01" {
  vpc_id = aws_vpc.dev_vpc01.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_gateway01.id
  }
}
 
resource "aws_route_table_association" "public_route_assoc" {
  subnet_id = aws_subnet.dev_subnet01.id
  route_table_id = aws_route_table.dev_routetable01.id
}

resource "aws_instance" "dev_vm01" {
  depends_on = [
    aws_security_group.dev_sg01,
    aws_subnet.dev_subnet01,
    aws_key_pair.dev_key01,
  ]
  ami = var.ami
  instance_type = var.instance_type
  associate_public_ip_address = true
  key_name = var.tag_name
  subnet_id = aws_subnet.dev_subnet01.id
  vpc_security_group_ids = [
    aws_security_group.dev_sg01.id
  ]
  root_block_device {
    delete_on_termination = true
    volume_size = 100
    volume_type = "gp3"
  }
  connection {
    type = "ssh"
    host = self.public_ip
    user = var.instance_user
    private_key = file(var.private_key_file)
    timeout = "10m"
  }

  # remote-exec to create /etc/cloud/aws.conf
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/cloud",
      "echo '[Global]' | sudo tee /etc/cloud/aws.conf",
      "echo 'Zone=${aws_subnet.dev_subnet01.availability_zone}' | sudo tee -a /etc/cloud/aws.conf",
      "echo 'KubernetesClusterID=${var.tag_name}' | sudo tee -a /etc/cloud/aws.conf",
    ]
  }

  # run ansible playbook for instance setup
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.instance_user} -i '${self.public_ip},' --private-key ${var.private_key_file} ../../ansible/ubuntu/setup.yml"
  }

  # print what to do next
  provisioner "local-exec" {
    command = <<EOT
      echo "Provisioning complete!"
      echo "To log into the VM, run:"
      echo "  ssh ${var.instance_user}@${aws_instance.dev_vm01.public_ip}"
      echo "To start kubernetes on the VM, run:"
      echo "  sudo su -"
      echo "  export AWS_ACCESS_KEY_ID=..."
      echo "  export AWS_SECRET_ACCESS_KEY=..."
      echo "  local-up-cluster"
    EOT
  }
}

output "public_ip" {
  value = aws_instance.dev_vm01.public_ip
}
