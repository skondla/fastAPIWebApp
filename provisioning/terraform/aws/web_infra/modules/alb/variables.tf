variable "name" {}
variable "subnet_ids" { type = list(string) }
variable "sg_id" {}
# variable "lb_name" {}
# variable "target_group_name" {}

variable "vpc_id" {}
# variable "public_subnet_ids" { type = list(string) }
#variable "lb_security_groups" { type = list(string) }
variable "tags" { 
    type = map(string) 
    default = {}
}

variable "target_group_port" {
  description = "Port for the target group"
  type        = number
  default     = 80
}

variable "instance_ids" {
  description = "List of EC2 instance IDs to attach to the ALB"
  type        = list(string)
}


