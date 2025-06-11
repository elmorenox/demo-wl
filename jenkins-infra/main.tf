provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# VPC and Network Resources
resource "aws_vpc" "jenkins_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Jenkins-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id

  tags = {
    Name = "Jenkins-IGW"
  }
}

# Public Subnet for Jenkins
resource "aws_subnet" "jenkins_subnet" {
  vpc_id                  = aws_vpc.jenkins_vpc.id
  cidr_block              = var.jenkins_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = {
    Name = "Jenkins-Subnet"
  }
}

# Route Table for Jenkins
resource "aws_route_table" "jenkins_rt" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }

  tags = {
    Name = "Jenkins-Route-Table"
  }
}

# Route Table Association
resource "aws_route_table_association" "jenkins_rta" {
  subnet_id      = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.jenkins_rt.id
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow SSH and Jenkins traffic"
  vpc_id      = aws_vpc.jenkins_vpc.id 

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "Jenkins-SG"
  }
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = var.ec2_ami
  instance_type          = "t3.medium"
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id              = aws_subnet.jenkins_subnet.id

  user_data = templatefile("${path.module}/scripts/jenkins_setup.sh", {
    aws_access_key = var.aws_access_key
    aws_secret_key = var.aws_secret_key
  })

  tags = {
    Name = "Jenkins"
  }
}

# Outputs for app-infra to reference
output "vpc_id" {
  value = aws_vpc.jenkins_vpc.id
}

output "jenkins_subnet_id" {
  value = aws_subnet.jenkins_subnet.id
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}