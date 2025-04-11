# variables.tf

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Map of AZ to public subnet CIDR blocks"
  type        = map(string)
  default     = {
    "us-west-2a" = "10.0.1.0/24"
    "us-west-2b" = "10.0.3.0/24"
    "us-west-2c" = "10.0.5.0/24"
  }
}

variable "private_subnets" {
  description = "Map of AZ to private subnet CIDR blocks"
  type        = map(string)
  default     = {
    "us-west-2a" = "10.0.2.0/24"
    "us-west-2b" = "10.0.4.0/24"
    "us-west-2c" = "10.0.6.0/24"
  }
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  default     = "ami-087f352c165340ea1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key name"
  default     = "ssh-key2-us-west-2"
}

variable "user_data_file" {
  description = "Path to user data script for EC2"
  default     = "bootstrap/bootstrap.sh"
}

variable "acm_cert_path" {
  default = "certs/certificate.pem"
}

variable "acm_key_path" {
  default = "certs/key.pem"
}

variable "acm_chain_path" {
  default = "certs/certificate_chain.pem"
}

# variable "app_instance_count" {
#   description = "Number of application instances"
#   default     = 3
# }
# variable "bastion_instance_count" {
#   description = "Number of bastion instances"
#   default     = 1
# }
