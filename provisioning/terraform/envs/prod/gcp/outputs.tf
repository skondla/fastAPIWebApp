output "host_project_id" {
  value = var.host_project_id
}

output "region" {
  value = var.region
}

output "network_self_link" {
  value = module.hub.network_self_link
}

output "ha_vpn_gateway_id" {
  value = module.hub.ha_vpn_gateway_id
}

output "router_name" {
  value = module.hub.router_name
}

output "router_asn" {
  value = module.hub.router_asn
}

output "advertised_cidrs" {
  value = [var.hub_cidr, var.spoke_subnet_cidr]
}
