locals {
  gateway_cidr  = cidrsubnet(var.address_space, var.gateway_subnet_bits, 0)
  firewall_cidr = cidrsubnet(var.address_space, var.firewall_subnet_bits, 1)
  workload_cidrs = [
    cidrsubnet(var.address_space, var.workload_subnet_bits, 1),
    cidrsubnet(var.address_space, var.workload_subnet_bits, 2),
    cidrsubnet(var.address_space, var.workload_subnet_bits, 3),
  ]
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = var.tags
}

# Required-name subnet for the VPN/ExpressRoute gateway.
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.gateway_cidr]
}

# Required-name subnet for Azure Firewall.
resource "azurerm_subnet" "firewall" {
  count                = var.enable_firewall ? 1 : 0
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.firewall_cidr]
}

resource "azurerm_subnet" "workload" {
  count                = 3
  name                 = "${var.name}-workload-${count.index}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.workload_cidrs[count.index]]

  # Service endpoints — keep PaaS traffic on the Microsoft backbone.
  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.ContainerRegistry",
  ]
}

# Default-deny NSG on workload subnets. Add explicit allow rules per workload.
resource "azurerm_network_security_group" "workload" {
  count               = 3
  name                = "${var.name}-workload-${count.index}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "DenyAllInboundFromInternet"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  count                     = 3
  subnet_id                 = azurerm_subnet.workload[count.index].id
  network_security_group_id = azurerm_network_security_group.workload[count.index].id
}

# ─── NSG flow logs → Storage + Traffic Analytics ──────────────────────────────
resource "azurerm_network_watcher_flow_log" "workload" {
  count                     = 3
  network_watcher_name      = "NetworkWatcher_${var.location}"
  resource_group_name       = var.network_watcher_resource_group
  name                      = "${var.name}-workload-${count.index}-flow"
  network_security_group_id = azurerm_network_security_group.workload[count.index].id
  storage_account_id        = var.flow_logs_storage_account_id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = var.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.log_analytics_workspace_id
    workspace_region      = var.location
    workspace_resource_id = var.log_analytics_workspace_id
    interval_in_minutes   = 10
  }

  tags = var.tags
}

# ─── Azure Firewall Premium ───────────────────────────────────────────────────
resource "azurerm_public_ip" "firewall" {
  count               = var.enable_firewall ? 1 : 0
  name                = "${var.name}-fw-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "${var.name}-fw-policy"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
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

resource "azurerm_firewall" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "${var.name}-fw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = var.tags
}

# ─── VPN Gateway (active-active, BGP) ─────────────────────────────────────────
resource "azurerm_public_ip" "vpn_a" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${var.name}-vpn-pip-a"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "vpn_b" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${var.name}-vpn-pip-b"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${var.name}-vpngw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2AZ"

  active_active = true
  enable_bgp    = true

  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.vpn_a[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.vpn_b[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  bgp_settings {
    asn = var.vpn_gateway_asn
  }

  tags = var.tags
}
