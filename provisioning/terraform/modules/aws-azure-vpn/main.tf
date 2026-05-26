# ──────────────────────────────────────────────────────────────────────────────
# AWS Transit Gateway  ↔  Azure VPN Gateway   (active-active IPsec, BGP)
# Builds 4 tunnels total: AWS TGW × 2 endpoints  ×  Azure VPN × 2 endpoints.
# Tunnel topology (per AWS VPN connection — AWS gives us 2 tunnels per CGW):
#   - CGW-A (Azure VPN PIP A)  → 2 tunnels to AWS
#   - CGW-B (Azure VPN PIP B)  → 2 tunnels to AWS
# ──────────────────────────────────────────────────────────────────────────────

variable "name" {
  type        = string
  description = "Logical name (e.g. fastapi-aws-azure)."
}

variable "transit_gateway_id" {
  type        = string
  description = "AWS TGW ID (hub)."
}

variable "transit_gateway_route_table_id" {
  type        = string
  description = "AWS TGW route table — associations + propagations happen here."
}

variable "aws_side_asn" {
  type        = number
  description = "AWS Amazon-side ASN (read from aws-hub-vpc.transit_gateway_id's owner — supply explicitly to keep modules decoupled)."
}

variable "azure_vpn_gateway_id" {
  type        = string
  description = "Azure VPN gateway resource ID."
}

variable "azure_vpn_gateway_public_ips" {
  type        = list(string)
  description = "Both Azure VPN gateway public IPs (active-active)."
  validation {
    condition     = length(var.azure_vpn_gateway_public_ips) == 2
    error_message = "Provide exactly 2 IPs (active-active)."
  }
}

variable "azure_vpn_gateway_asn" {
  type        = number
  description = "Azure VPN gateway BGP ASN."
}

variable "azure_resource_group_name" {
  type        = string
  description = "RG that holds the Azure VPN gateway."
}

variable "azure_location" {
  type        = string
  description = "Azure region."
}

variable "aws_address_space" {
  type        = list(string)
  description = "AWS CIDR(s) to advertise to Azure."
}

variable "azure_address_space" {
  type        = list(string)
  description = "Azure CIDR(s) to advertise to AWS — populated as static routes on TGW RT and Local Network Gateway."
}

variable "tags" {
  type        = map(string)
  description = "Standard tag map."
}

# ─── AWS customer gateways (one per Azure VPN public IP) ──────────────────────
resource "aws_customer_gateway" "azure" {
  count       = 2
  bgp_asn     = var.azure_vpn_gateway_asn
  ip_address  = var.azure_vpn_gateway_public_ips[count.index]
  type        = "ipsec.1"
  device_name = "${var.name}-azure-cgw-${count.index}"

  tags = merge(var.tags, {
    Name = "${var.name}-azure-cgw-${count.index}"
  })
}

resource "random_password" "psk" {
  count            = 2
  length           = 32
  special          = false
  override_special = ""
}

resource "aws_vpn_connection" "azure" {
  count               = 2
  customer_gateway_id = aws_customer_gateway.azure[count.index].id
  transit_gateway_id  = var.transit_gateway_id
  type                = "ipsec.1"
  static_routes_only  = false

  # BGP — Azure side picks its own peer IPs; AWS APIPA pool is fine.
  tunnel1_preshared_key = random_password.psk[count.index].result
  tunnel2_preshared_key = random_password.psk[count.index].result

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14, 19, 20, 21, 24]
  tunnel2_phase1_dh_group_numbers      = [14, 19, 20, 21, 24]
  tunnel1_phase2_dh_group_numbers      = [14, 19, 20, 21, 24]
  tunnel2_phase2_dh_group_numbers      = [14, 19, 20, 21, 24]
  tunnel1_startup_action               = "start"
  tunnel2_startup_action               = "start"

  tags = merge(var.tags, {
    Name = "${var.name}-aws-azure-vpn-${count.index}"
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "azure" {
  count                          = 2
  transit_gateway_attachment_id  = aws_vpn_connection.azure[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "azure" {
  count                          = 2
  transit_gateway_attachment_id  = aws_vpn_connection.azure[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

# Static fallback routes on the AWS side (in case BGP flaps).
resource "aws_ec2_transit_gateway_route" "azure_static" {
  for_each = toset(var.azure_address_space)

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_vpn_connection.azure[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id

  depends_on = [aws_ec2_transit_gateway_route_table_propagation.azure]
}

# ─── Azure side: Local Network Gateway + Connection per AWS tunnel ────────────
# AWS VPN connection has 2 tunnel public IPs; we expose both as Azure LNGs.
locals {
  # aws_vpn_connection has tunnelN_address attributes — flatten across the two connections.
  azure_lng_entries = flatten([
    for c_idx, conn in aws_vpn_connection.azure : [
      {
        key       = "${c_idx}-1"
        ip        = conn.tunnel1_address
        peer_cidr = conn.tunnel1_inside_cidr
        psk       = conn.tunnel1_preshared_key
        bgp_addr  = conn.tunnel1_bgp_asn != null ? conn.tunnel1_vgw_inside_address : null
      },
      {
        key       = "${c_idx}-2"
        ip        = conn.tunnel2_address
        peer_cidr = conn.tunnel2_inside_cidr
        psk       = conn.tunnel2_preshared_key
        bgp_addr  = conn.tunnel2_bgp_asn != null ? conn.tunnel2_vgw_inside_address : null
      }
    ]
  ])
}

resource "azurerm_local_network_gateway" "aws" {
  for_each            = { for e in local.azure_lng_entries : e.key => e }
  name                = "${var.name}-aws-lng-${each.key}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location
  gateway_address     = each.value.ip
  address_space       = var.aws_address_space

  bgp_settings {
    asn                 = var.aws_side_asn
    bgp_peering_address = each.value.bgp_addr
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "aws" {
  for_each = { for e in local.azure_lng_entries : e.key => e }

  name                = "${var.name}-aws-conn-${each.key}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location

  type                       = "IPsec"
  virtual_network_gateway_id = var.azure_vpn_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.aws[each.key].id

  enable_bgp = true
  shared_key = each.value.psk

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "PFS14"
    sa_datasize      = 1024000
    sa_lifetime      = 27000
  }

  tags = var.tags
}

output "aws_vpn_connection_ids" {
  value = aws_vpn_connection.azure[*].id
}

output "azure_connection_ids" {
  value = { for k, v in azurerm_virtual_network_gateway_connection.aws : k => v.id }
}
