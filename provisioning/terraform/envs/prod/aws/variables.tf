variable "region" {
  type        = string
  description = "AWS region for the hub."
  default     = "us-east-1"
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

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "hub_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "prod_spoke_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "tgw_asn" {
  type    = number
  default = 64512
}

variable "remote_cidrs" {
  type        = list(string)
  description = "Azure + GCP CIDRs reachable via cross-cloud VPN. Surfaced into the spoke route tables."
  default = [
    "10.40.0.0/16", # Azure hub
    "10.50.0.0/16", # Azure prod spoke
    "10.70.0.0/16", # GCP hub
    "10.80.0.0/16"  # GCP prod spoke
  ]
}
