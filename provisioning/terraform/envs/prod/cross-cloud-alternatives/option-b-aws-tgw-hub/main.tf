# Option B: AWS TGW is the transit hub.
# Only build AWS↔Azure + AWS↔GCP. Skip Azure↔GCP. Azure↔GCP traffic transits AWS.

variable "project" { default = "fastapi" }

variable "aws_region" { default = "us-east-1" }
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
    error_message = "Active-active required."
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

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  tags = {
    Project     = var.project
    Environment = "prod"
    Topology    = "aws-tgw-hub"
    ManagedBy   = "terraform"
  }
}

module "aws_azure" {
  source = "../../../../modules/aws-azure-vpn"
  name   = "${var.project}-prod-tgwhub"

  transit_gateway_id             = var.aws_transit_gateway_id
  transit_gateway_route_table_id = var.aws_transit_gateway_route_table_id
  aws_side_asn                   = var.aws_side_asn
  aws_address_space              = concat(var.aws_address_space, var.gcp_address_space) # advertise GCP via AWS

  azure_resource_group_name    = var.azure_resource_group_name
  azure_location               = var.azure_location
  azure_vpn_gateway_id         = var.azure_vpn_gateway_id
  azure_vpn_gateway_public_ips = var.azure_vpn_gateway_public_ips
  azure_vpn_gateway_asn        = var.azure_vpn_gateway_asn
  azure_address_space          = var.azure_address_space

  tags = local.tags
}

module "aws_gcp" {
  source = "../../../../modules/aws-gcp-vpn"
  name   = "${var.project}-prod-tgwhub"

  transit_gateway_id             = var.aws_transit_gateway_id
  transit_gateway_route_table_id = var.aws_transit_gateway_route_table_id
  aws_side_asn                   = var.aws_side_asn
  aws_address_space              = concat(var.aws_address_space, var.azure_address_space) # advertise Azure via AWS

  gcp_project_id        = var.gcp_project_id
  gcp_region            = var.gcp_region
  gcp_network_self_link = var.gcp_network_self_link
  gcp_ha_vpn_gateway_id = var.gcp_ha_vpn_gateway_id
  gcp_router_name       = var.gcp_router_name
  gcp_router_asn        = var.gcp_router_asn
  gcp_address_space     = var.gcp_address_space

  tags = local.tags
}
