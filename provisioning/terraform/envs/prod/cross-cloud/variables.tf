variable "project" {
  type    = string
  default = "fastapi"
}

# ─── Per-cloud handoff inputs ─────────────────────────────────────────────────
# Populate these from the outputs of the AWS / Azure / GCP env stacks
# (either via terraform_remote_state below, or by hand for a CI plan).

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_transit_gateway_id" { type = string }
variable "aws_transit_gateway_route_table_id" { type = string }
variable "aws_side_asn" { type = number }
variable "aws_address_space" { type = list(string) }

variable "azure_location" { type = string }
variable "azure_resource_group_name" { type = string }
variable "azure_vpn_gateway_id" { type = string }
variable "azure_vpn_gateway_public_ips" {
  type = list(string)
  validation {
    condition     = length(var.azure_vpn_gateway_public_ips) == 2
    error_message = "Azure VPN gateway must be active-active (2 public IPs)."
  }
}
variable "azure_vpn_gateway_asn" { type = number }
variable "azure_address_space" { type = list(string) }

variable "gcp_project_id" { type = string }
variable "gcp_region" { type = string }
variable "gcp_network_self_link" { type = string }
variable "gcp_ha_vpn_gateway_id" { type = string }
variable "gcp_router_name" { type = string }
variable "gcp_router_asn" { type = number }
variable "gcp_address_space" { type = list(string) }
