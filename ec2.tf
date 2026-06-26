
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


/*terraform {
  backend "s3" {
    region = "eu-west-3"
    access_key = "on met sa valeur"
    secret_key = "on met sa valeur"
    bucket = "on met le nom de notre bucket qui se trouve sur AWS"
    key = "terraform.tfstate"
    
  }
  ce bloque (s3) permet de stocker des données sensibles sur aws.
}*/



provider "aws" {
  region = "eu-west-3"
}



############################
# data
############################

data "aws_ami" "app_ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    #values = ["amzn2-ami-hvm*"]
    values = ["al2023-ami-*-x86_64"]

  }
  
}




############################
# Réseau : VPC + Subnet + IGW
############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "kamar-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "kamar-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-3a"

  tags = {
    Name = "kamar-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "kamar-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################
# Sécurité : Security Group
############################

resource "aws_security_group" "allow_http_https_ssh" {
  name        = "kamar-security-group"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kamar-security-group"
  }

  /*dynamic "ingress" {
      for_each = "var.sg_ports"
      iterator = port
      content {
        from_port   = port.value
        to_port     = port.value
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      
    }
    
  }
  
  /*dynamic "egress" {
      for_each = "var.sg_ports"
      iterator = port
      content {
        from_port   = port.value
        to_port     = port.value
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  
      }
    
  }*/


}



############################
# EC2 + EIP + cloud-init + remote-exec + local-exec
############################

locals {
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF
}

resource "aws_instance" "vm" {
  ami                    = data.aws_ami.app_ami.id        #Amazon Linux 2023
  instance_type          = var.instance_type
  #instance_type          = var.instance_type[0 ou 1 ...], 
  key_name               = "chak-key"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.allow_http_https_ssh.id]

  associate_public_ip_address = true
  user_data                   = local.user_data

  # --- Remote exec ---
  provisioner "remote-exec" {
    inline = [
      "sudo dnf install -y tree",
      "echo 'REMOTE EXEC OK' | sudo tee /tmp/remote_exec.txt"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("chak-key.pem")
      host        = self.public_ip
    }
  }

  tags = {
    Name = var.name
    #Name = var.name["dev" ou "prod"]
  }
}

resource "aws_eip" "ip" {
  instance = aws_instance.vm.id
  domain   = "vpc"

  # --- Local exec ---
  provisioner "local-exec" {
    command = "echo 'PUBLIC IP: ${aws_eip.ip.public_ip} | ID: ${aws_instance.vm.id} | AZ: ${aws_instance.vm.availability_zone}' >> infos_ec2.txt"
  }

  tags = {
    Name = "kamar-eip"
  }
}

output "myip" {
  value = aws_eip.ip.public_ip
}

