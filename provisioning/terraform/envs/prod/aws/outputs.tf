output "hub_vpc_id" {
  value = module.hub.vpc_id
}

output "hub_vpc_cidr" {
  value = module.hub.vpc_cidr
}

output "transit_gateway_id" {
  value = module.hub.transit_gateway_id
}

output "transit_gateway_route_table_id" {
  value = module.hub.transit_gateway_route_table_id
}

output "tgw_asn" {
  value = var.tgw_asn
}

output "prod_spoke_vpc_id" {
  value = module.spoke_prod.vpc_id
}

output "prod_spoke_cidr" {
  value = module.spoke_prod.vpc_cidr
}

output "prod_spoke_private_subnet_ids" {
  value = module.spoke_prod.private_subnet_ids
}

output "advertised_cidrs" {
  description = "AWS CIDRs advertised to other clouds (consumed by cross-cloud module)."
  value       = [var.hub_cidr, var.prod_spoke_cidr]
}
