# ──────────────────────────────────────────────────────────────────────────────
# AWS Transit Gateway  ↔  GCP HA VPN Gateway   (4 tunnels, BGP, IKEv2)
# ──────────────────────────────────────────────────────────────────────────────

variable "name" { type = string }
variable "transit_gateway_id" { type = string }
variable "transit_gateway_route_table_id" { type = string }
variable "aws_side_asn" { type = number }
variable "aws_address_space" { type = list(string) }

variable "gcp_project_id" { type = string }
variable "gcp_region" { type = string }
variable "gcp_network_self_link" { type = string }
variable "gcp_ha_vpn_gateway_id" { type = string }
variable "gcp_router_name" { type = string }
variable "gcp_router_asn" { type = number }
variable "gcp_address_space" { type = list(string) }

variable "tags" { type = map(string) }

data "google_compute_ha_vpn_gateway" "this" {
  project = var.gcp_project_id
  region  = var.gcp_region
  name    = element(split("/", var.gcp_ha_vpn_gateway_id), length(split("/", var.gcp_ha_vpn_gateway_id)) - 1)
}

# AWS customer gateways — one per GCP HA VPN interface (HA VPN has 2 IPs).
resource "aws_customer_gateway" "gcp" {
  count       = 2
  bgp_asn     = var.gcp_router_asn
  ip_address  = data.google_compute_ha_vpn_gateway.this.vpn_interfaces[count.index].ip_address
  type        = "ipsec.1"
  device_name = "${var.name}-gcp-cgw-${count.index}"

  tags = merge(var.tags, { Name = "${var.name}-gcp-cgw-${count.index}" })
}

resource "random_password" "psk" {
  count            = 2
  length           = 32
  special          = false
  override_special = ""
}

resource "aws_vpn_connection" "gcp" {
  count               = 2
  customer_gateway_id = aws_customer_gateway.gcp[count.index].id
  transit_gateway_id  = var.transit_gateway_id
  type                = "ipsec.1"
  static_routes_only  = false

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

  tags = merge(var.tags, { Name = "${var.name}-aws-gcp-vpn-${count.index}" })
}

resource "aws_ec2_transit_gateway_route_table_association" "gcp" {
  count                          = 2
  transit_gateway_attachment_id  = aws_vpn_connection.gcp[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp" {
  count                          = 2
  transit_gateway_attachment_id  = aws_vpn_connection.gcp[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route" "gcp_static" {
  for_each = toset(var.gcp_address_space)

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_vpn_connection.gcp[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id

  depends_on = [aws_ec2_transit_gateway_route_table_propagation.gcp]
}

# ─── GCP side: external VPN gateway + tunnels + BGP peers ────────────────────
locals {
  # Flatten AWS tunnel endpoints across both connections.
  aws_tunnel_endpoints = flatten([
    for c_idx, conn in aws_vpn_connection.gcp : [
      {
        key           = "${c_idx}-1"
        public_ip     = conn.tunnel1_address
        psk           = conn.tunnel1_preshared_key
        cgw_inside_ip = conn.tunnel1_cgw_inside_address
        vgw_inside_ip = conn.tunnel1_vgw_inside_address
      },
      {
        key           = "${c_idx}-2"
        public_ip     = conn.tunnel2_address
        psk           = conn.tunnel2_preshared_key
        cgw_inside_ip = conn.tunnel2_cgw_inside_address
        vgw_inside_ip = conn.tunnel2_vgw_inside_address
      }
    ]
  ])
}

resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${var.name}-aws-ext-vpn"
  project         = var.gcp_project_id
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  description     = "AWS-side tunnel endpoints"

  dynamic "interface" {
    for_each = { for i, e in local.aws_tunnel_endpoints : i => e }
    content {
      id         = tonumber(interface.key)
      ip_address = interface.value.public_ip
    }
  }
}

resource "google_compute_vpn_tunnel" "aws" {
  for_each = { for i, e in local.aws_tunnel_endpoints : i => e }

  name                            = "${var.name}-aws-tun-${each.key}"
  project                         = var.gcp_project_id
  region                          = var.gcp_region
  vpn_gateway                     = var.gcp_ha_vpn_gateway_id
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = tonumber(each.key)
  vpn_gateway_interface           = tonumber(each.key) % 2
  router                          = var.gcp_router_name
  shared_secret                   = each.value.psk
  ike_version                     = 2
}

resource "google_compute_router_interface" "aws" {
  for_each   = google_compute_vpn_tunnel.aws
  name       = "${var.name}-aws-rif-${each.key}"
  project    = var.gcp_project_id
  region     = var.gcp_region
  router     = var.gcp_router_name
  ip_range   = "${local.aws_tunnel_endpoints[tonumber(each.key)].cgw_inside_ip}/30"
  vpn_tunnel = each.value.name
}

resource "google_compute_router_peer" "aws" {
  for_each = google_compute_router_interface.aws

  name                      = "${var.name}-aws-bgp-${each.key}"
  project                   = var.gcp_project_id
  region                    = var.gcp_region
  router                    = var.gcp_router_name
  interface                 = each.value.name
  peer_ip_address           = local.aws_tunnel_endpoints[tonumber(each.key)].vgw_inside_ip
  peer_asn                  = var.aws_side_asn
  advertised_route_priority = 100
}

output "aws_vpn_connection_ids" {
  value = aws_vpn_connection.gcp[*].id
}

output "gcp_vpn_tunnel_ids" {
  value = { for k, v in google_compute_vpn_tunnel.aws : k => v.id }
}
