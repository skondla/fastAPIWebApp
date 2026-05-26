# ──────────────────────────────────────────────────────────────────────────────
# Azure Virtual WAN — global transit hub.
# Spokes (AWS, GCP, on-prem) attach as VPN sites; Azure VNets attach as VHC peerings.
# vWAN handles BGP route propagation across all branches automatically.
# ──────────────────────────────────────────────────────────────────────────────

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vwan_address_prefix" {
  type        = string
  description = "Hub virtual address space. Must not overlap any branch CIDR."
}
variable "vpn_gateway_scale_unit" {
  type        = number
  description = "Aggregate Gbps for the S2S VPN gateway. 1 unit = 500 Mbps."
  default     = 2
}
variable "enable_firewall" {
  type    = bool
  default = true
}
variable "tags" { type = map(string) }

resource "azurerm_virtual_wan" "this" {
  name                = "${var.name}-vwan"
  resource_group_name = var.resource_group_name
  location            = var.location

  type                           = "Standard"
  allow_branch_to_branch_traffic = true
  disable_vpn_encryption         = false

  tags = var.tags
}

resource "azurerm_virtual_hub" "this" {
  name                = "${var.name}-vhub"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.this.id
  address_prefix      = var.vwan_address_prefix
  sku                 = "Standard"

  tags = var.tags
}

# S2S VPN gateway inside the hub — branches (AWS, GCP, on-prem) attach here.
resource "azurerm_vpn_gateway" "this" {
  name                = "${var.name}-vhub-vpngw"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_hub_id      = azurerm_virtual_hub.this.id

  scale_unit = var.vpn_gateway_scale_unit

  bgp_settings {
    asn         = 65515
    peer_weight = 0
  }

  tags = var.tags
}

# Azure Firewall in the hub — Secure Virtual Hub pattern.
resource "azurerm_firewall_policy" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "${var.name}-vhub-fw-policy"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"

  threat_intelligence_mode = "Alert"
  intrusion_detection {
    mode = "Alert"
  }
  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

resource "azurerm_firewall" "vhub" {
  count               = var.enable_firewall ? 1 : 0
  name                = "${var.name}-vhub-fw"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name           = "AZFW_Hub"
  sku_tier           = "Premium"
  firewall_policy_id = azurerm_firewall_policy.this[0].id

  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.this.id
    public_ip_count = 1
  }

  tags = var.tags
}

output "virtual_wan_id" {
  value = azurerm_virtual_wan.this.id
}

output "virtual_hub_id" {
  value = azurerm_virtual_hub.this.id
}

output "vpn_gateway_id" {
  value = azurerm_vpn_gateway.this.id
}

output "vpn_gateway_bgp_addresses" {
  description = "BGP instance 0 + 1 addresses for branch BGP peer config."
  value = [
    for inst in azurerm_vpn_gateway.this.bgp_settings[0].instance_0_bgp_peering_address : inst
  ]
}
