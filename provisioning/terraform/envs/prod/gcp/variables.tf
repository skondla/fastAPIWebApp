variable "host_project_id" {
  type        = string
  description = "Shared VPC host project ID."
}

variable "service_project_id" {
  type        = string
  description = "Spoke service project ID."
}

variable "region" {
  type    = string
  default = "us-east4"
}

variable "project" {
  type    = string
  default = "fastapi"
}

variable "owner" {
  type    = string
  default = "platform"
}

variable "cost_center" {
  type    = string
  default = "CC-PLAT-001"
}

variable "hub_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "spoke_subnet_cidr" {
  type    = string
  default = "10.80.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "100.72.0.0/14"
}

variable "services_cidr" {
  type    = string
  default = "100.76.0.0/16"
}

variable "router_asn" {
  type    = number
  default = 65530
}
