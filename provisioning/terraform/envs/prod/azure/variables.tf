variable "location" {
  type    = string
  default = "eastus2"
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

variable "hub_address_space" {
  type    = string
  default = "10.40.0.0/16"
}

variable "prod_spoke_address_space" {
  type    = string
  default = "10.50.0.0/16"
}

variable "vpn_gateway_asn" {
  type    = number
  default = 65515
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing LAW resource ID — created by the observability stack."
}

variable "flow_logs_storage_account_id" {
  type        = string
  description = "Existing storage account ID for NSG flow logs."
}
