# Option D: Azure Virtual WAN is the global hub.
# AWS TGW and GCP HA VPN attach as VPN sites.
# (Site-to-vHub IPsec connection objects are scaffolded; PSKs + tunnel IPs come from caller.)

variable "project" { default = "fastapi" }
variable "location" { default = "eastus2" }
variable "resource_group_name" { type = string }
variable "vwan_address_prefix" { default = "10.41.0.0/24" }
variable "vpn_gateway_scale_unit" { default = 2 }

variable "aws_branch_public_ips" {
  type        = list(string)
  description = "Public IPs of AWS TGW VPN tunnels (4 IPs from `aws_vpn_connection.*.tunnel{1,2}_address`)."
}
variable "aws_branch_asn" { type = number }
variable "aws_branch_cidrs" { type = list(string) }

variable "gcp_branch_public_ips" {
  type        = list(string)
  description = "Public IPs of GCP HA VPN interfaces (2 IPs)."
}
variable "gcp_branch_asn" { type = number }
variable "gcp_branch_cidrs" { type = list(string) }

variable "aws_psks" {
  type        = list(string)
  sensitive   = true
  description = "Pre-shared keys per AWS tunnel (4 entries)."
}
variable "gcp_psks" {
  type        = list(string)
  sensitive   = true
  description = "Pre-shared keys per GCP tunnel (2 entries)."
}

provider "azurerm" {
  features {}
}

locals {
  tags = {
    Project     = var.project
    Environment = "prod"
    Topology    = "azure-vwan-hub"
    ManagedBy   = "terraform"
  }
}

module "vwan" {
  source = "../../../../modules/azure-vwan-hub"

  name                   = "${var.project}-prod"
  location               = var.location
  resource_group_name    = var.resource_group_name
  vwan_address_prefix    = var.vwan_address_prefix
  vpn_gateway_scale_unit = var.vpn_gateway_scale_unit
  enable_firewall        = true
  tags                   = local.tags
}

# AWS branch (VPN site backed by AWS TGW tunnel public IPs).
resource "azurerm_vpn_site" "aws" {
  name                = "${var.project}-aws-site"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = module.vwan.virtual_wan_id

  dynamic "link" {
    for_each = { for i, ip in var.aws_branch_public_ips : tostring(i) => ip }
    content {
      name          = "aws-link-${link.key}"
      ip_address    = link.value
      provider_name = "AWS"
      speed_in_mbps = 1000
      bgp {
        asn             = var.aws_branch_asn
        peering_address = "169.254.21.${tonumber(link.key) + 1}"
      }
    }
  }

  address_cidrs = var.aws_branch_cidrs
  tags          = local.tags
}

resource "azurerm_vpn_gateway_connection" "aws" {
  count              = length(var.aws_branch_public_ips)
  name               = "${var.project}-aws-conn-${count.index}"
  vpn_gateway_id     = module.vwan.vpn_gateway_id
  remote_vpn_site_id = azurerm_vpn_site.aws.id

  vpn_link {
    name             = "aws-link-${count.index}"
    vpn_site_link_id = azurerm_vpn_site.aws.link[count.index].id
    bgp_enabled      = true
    shared_key       = var.aws_psks[count.index]
    bandwidth_mbps   = 250

    ipsec_policy {
      dh_group                 = "DHGroup14"
      ike_encryption_algorithm = "AES256"
      ike_integrity_algorithm  = "SHA256"
      encryption_algorithm     = "GCMAES256"
      integrity_algorithm      = "GCMAES256"
      pfs_group                = "PFS14"
      sa_data_size_kb          = 102400
      sa_lifetime_sec          = 27000
    }
  }
}

# GCP branch
resource "azurerm_vpn_site" "gcp" {
  name                = "${var.project}-gcp-site"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = module.vwan.virtual_wan_id

  dynamic "link" {
    for_each = { for i, ip in var.gcp_branch_public_ips : tostring(i) => ip }
    content {
      name          = "gcp-link-${link.key}"
      ip_address    = link.value
      provider_name = "GCP"
      speed_in_mbps = 1000
      bgp {
        asn             = var.gcp_branch_asn
        peering_address = "169.254.22.${tonumber(link.key) + 1}"
      }
    }
  }

  address_cidrs = var.gcp_branch_cidrs
  tags          = local.tags
}

resource "azurerm_vpn_gateway_connection" "gcp" {
  count              = length(var.gcp_branch_public_ips)
  name               = "${var.project}-gcp-conn-${count.index}"
  vpn_gateway_id     = module.vwan.vpn_gateway_id
  remote_vpn_site_id = azurerm_vpn_site.gcp.id

  vpn_link {
    name             = "gcp-link-${count.index}"
    vpn_site_link_id = azurerm_vpn_site.gcp.link[count.index].id
    bgp_enabled      = true
    shared_key       = var.gcp_psks[count.index]
    bandwidth_mbps   = 250

    ipsec_policy {
      dh_group                 = "DHGroup14"
      ike_encryption_algorithm = "AES256"
      ike_integrity_algorithm  = "SHA256"
      encryption_algorithm     = "GCMAES256"
      integrity_algorithm      = "GCMAES256"
      pfs_group                = "PFS14"
      sa_data_size_kb          = 102400
      sa_lifetime_sec          = 27000
    }
  }
}

output "virtual_wan_id" { value = module.vwan.virtual_wan_id }
output "virtual_hub_id" { value = module.vwan.virtual_hub_id }
output "vpn_gateway_id" { value = module.vwan.vpn_gateway_id }
