# ──────────────────────────────────────────────────────────────────────────────
# Azure VPN Gateway  ↔  GCP HA VPN   (4 tunnels, BGP, IKEv2)
# ──────────────────────────────────────────────────────────────────────────────

variable "name" { type = string }

variable "azure_resource_group_name" { type = string }
variable "azure_location" { type = string }
variable "azure_vpn_gateway_id" { type = string }
variable "azure_vpn_gateway_asn" { type = number }
variable "azure_vpn_gateway_public_ips" {
  type = list(string)
  validation {
    condition     = length(var.azure_vpn_gateway_public_ips) == 2
    error_message = "Provide exactly 2 IPs (active-active)."
  }
}
variable "azure_address_space" { type = list(string) }

variable "gcp_project_id" { type = string }
variable "gcp_region" { type = string }
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

resource "random_password" "psk" {
  count            = 4
  length           = 32
  special          = false
  override_special = ""
}

# GCP external VPN representing Azure VPN gateway (both PIPs).
resource "google_compute_external_vpn_gateway" "azure" {
  name            = "${var.name}-azure-ext-vpn"
  project         = var.gcp_project_id
  redundancy_type = "TWO_IPS_REDUNDANCY"
  description     = "Azure VPN gateway public endpoints"

  interface {
    id         = 0
    ip_address = var.azure_vpn_gateway_public_ips[0]
  }
  interface {
    id         = 1
    ip_address = var.azure_vpn_gateway_public_ips[1]
  }
}

# 4 GCP tunnels: gcp-vpn-if-0 → azure-pip-0, gcp-vpn-if-0 → azure-pip-1, etc.
locals {
  tunnel_pairs = [
    { gcp_if = 0, az_if = 0, key = "0-0" },
    { gcp_if = 0, az_if = 1, key = "0-1" },
    { gcp_if = 1, az_if = 0, key = "1-0" },
    { gcp_if = 1, az_if = 1, key = "1-1" },
  ]

  # GCP APIPA pool 169.254.0.0/16 — pick disjoint /30s per tunnel.
  bgp_addrs = {
    "0-0" = { gcp = "169.254.10.1", az = "169.254.10.2" }
    "0-1" = { gcp = "169.254.11.1", az = "169.254.11.2" }
    "1-0" = { gcp = "169.254.12.1", az = "169.254.12.2" }
    "1-1" = { gcp = "169.254.13.1", az = "169.254.13.2" }
  }
}

resource "google_compute_vpn_tunnel" "azure" {
  for_each = { for p in local.tunnel_pairs : p.key => p }

  name                            = "${var.name}-azure-tun-${each.key}"
  project                         = var.gcp_project_id
  region                          = var.gcp_region
  vpn_gateway                     = var.gcp_ha_vpn_gateway_id
  vpn_gateway_interface           = each.value.gcp_if
  peer_external_gateway           = google_compute_external_vpn_gateway.azure.id
  peer_external_gateway_interface = each.value.az_if
  router                          = var.gcp_router_name
  ike_version                     = 2
  shared_secret                   = random_password.psk[index(local.tunnel_pairs, each.value)].result
}

resource "google_compute_router_interface" "azure" {
  for_each   = google_compute_vpn_tunnel.azure
  name       = "${var.name}-azure-rif-${each.key}"
  project    = var.gcp_project_id
  region     = var.gcp_region
  router     = var.gcp_router_name
  ip_range   = "${local.bgp_addrs[each.key].gcp}/30"
  vpn_tunnel = each.value.name
}

resource "google_compute_router_peer" "azure" {
  for_each = google_compute_router_interface.azure

  name                      = "${var.name}-azure-bgp-${each.key}"
  project                   = var.gcp_project_id
  region                    = var.gcp_region
  router                    = var.gcp_router_name
  interface                 = each.value.name
  peer_ip_address           = local.bgp_addrs[each.key].az
  peer_asn                  = var.azure_vpn_gateway_asn
  advertised_route_priority = 100
}

# Azure-side: 2 LNGs (one per GCP HA VPN interface), 2 connections.
resource "azurerm_local_network_gateway" "gcp" {
  for_each            = { for i, ip in data.google_compute_ha_vpn_gateway.this.vpn_interfaces : tostring(i) => ip.ip_address }
  name                = "${var.name}-gcp-lng-${each.key}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location
  gateway_address     = each.value
  address_space       = var.gcp_address_space

  bgp_settings {
    asn                 = var.gcp_router_asn
    bgp_peering_address = lookup({ "0" = local.bgp_addrs["0-0"].gcp, "1" = local.bgp_addrs["1-0"].gcp }, each.key)
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "gcp" {
  for_each            = azurerm_local_network_gateway.gcp
  name                = "${var.name}-gcp-conn-${each.key}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location

  type                       = "IPsec"
  virtual_network_gateway_id = var.azure_vpn_gateway_id
  local_network_gateway_id   = each.value.id

  enable_bgp = true
  shared_key = random_password.psk[tonumber(each.key)].result

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

output "azure_connection_ids" {
  value = { for k, v in azurerm_virtual_network_gateway_connection.gcp : k => v.id }
}

output "gcp_vpn_tunnel_ids" {
  value = { for k, v in google_compute_vpn_tunnel.azure : k => v.id }
}
