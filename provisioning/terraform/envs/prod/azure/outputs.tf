output "hub_vnet_id" {
  value = module.hub.vnet_id
}

output "hub_resource_group_name" {
  value = module.hub.resource_group_name
}

output "vpn_gateway_id" {
  value = module.hub.vpn_gateway_id
}

output "vpn_gateway_public_ips" {
  value = module.hub.vpn_gateway_public_ips
}

output "vpn_gateway_asn" {
  value = module.hub.vpn_gateway_asn
}

output "advertised_cidrs" {
  description = "Azure CIDRs advertised to other clouds."
  value       = [var.hub_address_space, var.prod_spoke_address_space]
}

output "azure_location" {
  value = var.location
}
