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
    ManagedBy   = "terraform"
    Layer       = "cross-cloud-network"
  }
}

# Guardrail: cross-cloud CIDRs must not overlap. Validated here so a misconfigured
# tfvars file fails fast at plan time.
resource "null_resource" "cidr_overlap_guard" {
  lifecycle {
    precondition {
      condition = alltrue(flatten([
        for a in var.aws_address_space : [
          for z in var.azure_address_space : !can(cidrnetmask(cidrsubnet(a, 0, 0))) ? false : a != z
        ]
      ]))
      error_message = "AWS and Azure address_space must not overlap. See _global/network-cidr-plan.md."
    }
    precondition {
      condition     = length(setintersection(var.aws_address_space, var.gcp_address_space)) == 0
      error_message = "AWS and GCP address_space must not overlap."
    }
    precondition {
      condition     = length(setintersection(var.azure_address_space, var.gcp_address_space)) == 0
      error_message = "Azure and GCP address_space must not overlap."
    }
  }
}

module "aws_azure" {
  source = "../../../modules/aws-azure-vpn"

  name = "${var.project}-prod"

  transit_gateway_id             = var.aws_transit_gateway_id
  transit_gateway_route_table_id = var.aws_transit_gateway_route_table_id
  aws_side_asn                   = var.aws_side_asn
  aws_address_space              = var.aws_address_space

  azure_resource_group_name    = var.azure_resource_group_name
  azure_location               = var.azure_location
  azure_vpn_gateway_id         = var.azure_vpn_gateway_id
  azure_vpn_gateway_public_ips = var.azure_vpn_gateway_public_ips
  azure_vpn_gateway_asn        = var.azure_vpn_gateway_asn
  azure_address_space          = var.azure_address_space

  tags = local.tags
}

module "aws_gcp" {
  source = "../../../modules/aws-gcp-vpn"

  name = "${var.project}-prod"

  transit_gateway_id             = var.aws_transit_gateway_id
  transit_gateway_route_table_id = var.aws_transit_gateway_route_table_id
  aws_side_asn                   = var.aws_side_asn
  aws_address_space              = var.aws_address_space

  gcp_project_id        = var.gcp_project_id
  gcp_region            = var.gcp_region
  gcp_network_self_link = var.gcp_network_self_link
  gcp_ha_vpn_gateway_id = var.gcp_ha_vpn_gateway_id
  gcp_router_name       = var.gcp_router_name
  gcp_router_asn        = var.gcp_router_asn
  gcp_address_space     = var.gcp_address_space

  tags = local.tags
}

module "azure_gcp" {
  source = "../../../modules/azure-gcp-vpn"

  name = "${var.project}-prod"

  azure_resource_group_name    = var.azure_resource_group_name
  azure_location               = var.azure_location
  azure_vpn_gateway_id         = var.azure_vpn_gateway_id
  azure_vpn_gateway_public_ips = var.azure_vpn_gateway_public_ips
  azure_vpn_gateway_asn        = var.azure_vpn_gateway_asn
  azure_address_space          = var.azure_address_space

  gcp_project_id        = var.gcp_project_id
  gcp_region            = var.gcp_region
  gcp_ha_vpn_gateway_id = var.gcp_ha_vpn_gateway_id
  gcp_router_name       = var.gcp_router_name
  gcp_router_asn        = var.gcp_router_asn
  gcp_address_space     = var.gcp_address_space

  tags = local.tags
}
