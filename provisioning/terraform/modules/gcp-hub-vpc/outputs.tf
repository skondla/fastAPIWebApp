output "network_id" {
  value       = google_compute_network.this.id
  description = "Hub VPC self-link."
}

output "network_name" {
  value       = google_compute_network.this.name
  description = "Hub VPC name."
}

output "network_self_link" {
  value       = google_compute_network.this.self_link
  description = "Hub VPC self-link (alternate form used by some resources)."
}

output "subnet_id" {
  value       = google_compute_subnetwork.primary.id
  description = "Primary subnet self-link."
}

output "subnet_cidr" {
  value       = google_compute_subnetwork.primary.ip_cidr_range
  description = "Primary subnet CIDR."
}

output "pods_secondary_range_name" {
  value       = "pods"
  description = "Name of the pods secondary range — pass to GKE."
}

output "services_secondary_range_name" {
  value       = "services"
  description = "Name of the services secondary range — pass to GKE."
}

output "router_name" {
  value       = google_compute_router.this.name
  description = "Cloud Router name — consumed by VPN modules."
}

output "router_asn" {
  value       = var.router_asn
  description = "Cloud Router ASN — needed by remote BGP peers."
}

output "ha_vpn_gateway_id" {
  value       = try(google_compute_ha_vpn_gateway.this[0].id, null)
  description = "HA VPN gateway self-link."
}

output "psc_google_apis_ip" {
  value       = google_compute_global_address.psc_apis.address
  description = "Private endpoint IP for Google APIs (use in DNS for *.p.googleapis.com)."
}
