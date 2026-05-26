output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Hub RG name (created here)."
}

output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Hub VNet resource ID."
}

output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "Hub VNet name."
}

output "vnet_address_space" {
  value       = azurerm_virtual_network.this.address_space
  description = "Hub VNet address space."
}

output "workload_subnet_ids" {
  value       = azurerm_subnet.workload[*].id
  description = "Workload subnet IDs."
}

output "gateway_subnet_id" {
  value       = azurerm_subnet.gateway.id
  description = "GatewaySubnet ID."
}

output "vpn_gateway_id" {
  value       = try(azurerm_virtual_network_gateway.vpn[0].id, null)
  description = "VPN gateway resource ID."
}

output "vpn_gateway_public_ips" {
  value       = [for ip in concat(azurerm_public_ip.vpn_a, azurerm_public_ip.vpn_b) : ip.ip_address]
  description = "Both gateway public IPs — used by AWS/GCP customer-gateway resources."
}

output "vpn_gateway_asn" {
  value       = var.vpn_gateway_asn
  description = "Azure-side BGP ASN — needed by remote BGP peer config."
}

output "firewall_private_ip" {
  value       = try(azurerm_firewall.this[0].ip_configuration[0].private_ip_address, null)
  description = "Azure Firewall private IP — set as default route next-hop on workload route tables."
}
