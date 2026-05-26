variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" {
  type        = string
  description = "Spoke RG name — created here."
}
variable "address_space" { type = string }
variable "workload_subnet_bits" {
  type    = number
  default = 4
}
variable "hub_vnet_id" {
  type        = string
  description = "Hub VNet ID for bi-directional peering."
}
variable "hub_vnet_name" {
  type        = string
  description = "Hub VNet name (peering API requires name + RG)."
}
variable "hub_resource_group_name" {
  type        = string
  description = "Hub RG name (peering counterpart)."
}
variable "firewall_private_ip" {
  type        = string
  description = "Hub firewall IP — set as 0.0.0.0/0 next-hop on spoke workload route tables. null disables UDR."
  default     = null
}
variable "tags" { type = map(string) }

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

resource "azurerm_subnet" "workload" {
  count                = 3
  name                 = "${var.name}-workload-${count.index}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, var.workload_subnet_bits, count.index)]

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.ContainerRegistry",
  ]
}

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

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  count                     = 3
  subnet_id                 = azurerm_subnet.workload[count.index].id
  network_security_group_id = azurerm_network_security_group.workload[count.index].id
}

# UDR forcing egress through hub firewall.
resource "azurerm_route_table" "workload" {
  count                         = var.firewall_private_ip == null ? 0 : 3
  name                          = "${var.name}-workload-${count.index}-rt"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-via-hub-fw"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "workload" {
  count          = var.firewall_private_ip == null ? 0 : 3
  subnet_id      = azurerm_subnet.workload[count.index].id
  route_table_id = azurerm_route_table.workload[count.index].id
}

# Bidirectional peering with the hub.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "${var.name}-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-${var.name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.this.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

output "vnet_id" { value = azurerm_virtual_network.this.id }
output "vnet_address_space" { value = azurerm_virtual_network.this.address_space }
output "workload_subnet_ids" { value = azurerm_subnet.workload[*].id }
