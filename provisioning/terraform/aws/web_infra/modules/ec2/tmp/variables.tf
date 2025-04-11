variable "ami" {}
variable "instance_type" {}
variable "key_name" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "user_data_file" {}
variable "instance_count" { default = 3 }
