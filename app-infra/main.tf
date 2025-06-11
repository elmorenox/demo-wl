# This Terraform configuration is designed to be run by Jenkins pipeline
# It assumes the VPC and basic networking already exists from jenkins-infra

# Data sources to reference existing infrastructure
provider "aws" {
  region = var.region
}

data "aws_vpc" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["Jenkins-VPC"]
  }
}

data "aws_subnet" "existing_public_subnet" {
  filter {
    name   = "tag:Name"
    values = ["Jenkins-Subnet"]
  }
}

data "aws_internet_gateway" "existing_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

# Create additional subnets for application infrastructure
resource "aws_subnet" "private_subnet" {
  vpc_id            = data.aws_vpc.existing_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "Private-Subnet"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [data.aws_internet_gateway.existing_igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = data.aws_subnet.existing_public_subnet.id

  tags = {
    Name = "App-NAT-GW"
  }

  depends_on = [data.aws_internet_gateway.existing_igw]
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.existing_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private-Route-Table"
  }
}

# Route Table Association - Private
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.existing_vpc.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-Server-SG"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Allow SSH and Flask traffic"
  vpc_id      = data.aws_vpc.existing_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "App-Server-SG"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring_sg"
  description = "Allow SSH, Prometheus and Grafana traffic"
  vpc_id      = data.aws_vpc.existing_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "Monitoring-SG"
  }
}

# EC2 Instances
resource "aws_instance" "web_server" {
  ami                    = var.ec2_ami
  instance_type          = "t3.micro"
  key_name               = var.ssh_key_name
  subnet_id              = data.aws_subnet.existing_public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  private_ip             = "10.0.1.100"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF
  )

  depends_on = [aws_instance.app_server]

  tags = {
    Name = "Web-Server"
  }
}

resource "aws_instance" "app_server" {
  ami                    = var.ec2_ami
  instance_type          = "t3.micro"
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  private_ip             = "10.0.2.100"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y python3 python3-pip
              pip3 install flask
              EOF
  )

  depends_on = [aws_route_table_association.private_rta]

  tags = {
    Name = "App-Server"
  }
}

resource "aws_instance" "monitoring" {
  ami                    = var.ec2_ami
  instance_type          = "t3.micro"
  key_name               = var.ssh_key_name
  subnet_id              = data.aws_subnet.existing_public_subnet.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y prometheus grafana
              EOF
  )

  depends_on = [aws_instance.app_server]

  tags = {
    Name = "Monitoring-Server"
  }
}

# Outputs
output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "web_server_private_ip" {
  value = aws_instance.web_server.private_ip
}

output "app_server_private_ip" {
  value = aws_instance.app_server.private_ip
}

output "monitoring_server_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "monitoring_server_private_ip" {
  value = aws_instance.monitoring.private_ip
}