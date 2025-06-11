variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default = "demo"
}