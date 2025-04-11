variable "cidr_block" {}
variable "name" {}
variable "public_subnets" { type = map(string) }
variable "private_subnets" { type = map(string) }
