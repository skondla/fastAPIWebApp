package main

# ──────────────────────────────────────────────────────────────────────────────
# Network policy — enforced against `terraform show -json plan.out | conftest test`
# ──────────────────────────────────────────────────────────────────────────────

# 1) No ingress security group rule may allow 0.0.0.0/0 to a non-load-balancer port.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.after.type == "ingress"
  cidr := resource.change.after.cidr_blocks[_]
  cidr == "0.0.0.0/0"
  port := resource.change.after.from_port
  not allowed_public_ports[port]
  msg := sprintf("aws_security_group_rule %q allows 0.0.0.0/0 ingress to port %d", [resource.address, port])
}

allowed_public_ports := {80, 443}

# 2) No inline ingress on aws_security_group with 0.0.0.0/0 to non-public ports.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group"
  ingress := resource.change.after.ingress[_]
  cidr := ingress.cidr_blocks[_]
  cidr == "0.0.0.0/0"
  not allowed_public_ports[ingress.from_port]
  msg := sprintf("aws_security_group %q has inline ingress allowing 0.0.0.0/0 to port %d", [resource.address, ingress.from_port])
}

# 3) Azure NSG must not allow Internet to non-public ports.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "azurerm_network_security_rule"
  resource.change.after.direction == "Inbound"
  resource.change.after.access == "Allow"
  resource.change.after.source_address_prefix == "Internet"
  port := resource.change.after.destination_port_range
  not internet_allowed_port(port)
  msg := sprintf("azurerm_network_security_rule %q allows Internet inbound on port %v", [resource.address, port])
}

internet_allowed_port(port) {
  port == "80"
}
internet_allowed_port(port) {
  port == "443"
}

# 4) GCP firewall rule must not have source_ranges 0.0.0.0/0 unless deny.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_compute_firewall"
  resource.change.after.direction == "INGRESS"
  source := resource.change.after.source_ranges[_]
  source == "0.0.0.0/0"
  not has_deny(resource.change.after)
  not allowed_public_gcp_target(resource.change.after.target_tags)
  msg := sprintf("google_compute_firewall %q allows 0.0.0.0/0 ingress", [resource.address])
}

has_deny(rule) {
  rule.deny[_]
}

allowed_public_gcp_target(tags) {
  tags[_] == "public-lb"
}

# 5) IKEv1 is forbidden everywhere.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_vpn_connection"
  v := resource.change.after.tunnel1_ike_versions[_]
  v == "ikev1"
  msg := sprintf("aws_vpn_connection %q tunnel1 enables IKEv1 — IKEv2 required", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_vpn_connection"
  v := resource.change.after.tunnel2_ike_versions[_]
  v == "ikev1"
  msg := sprintf("aws_vpn_connection %q tunnel2 enables IKEv1 — IKEv2 required", [resource.address])
}

# 6) DH group must be >= 14 (1024-bit MODP minimum). Reject groups 1, 2, 5.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_vpn_connection"
  g := resource.change.after.tunnel1_phase1_dh_group_numbers[_]
  g < 14
  msg := sprintf("aws_vpn_connection %q tunnel1 phase1 allows weak DH group %d", [resource.address, g])
}

# 7) SHA1 forbidden on phase1 / phase2 integrity.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_vpn_connection"
  alg := resource.change.after.tunnel1_phase1_integrity_algorithms[_]
  alg == "SHA1"
  msg := sprintf("aws_vpn_connection %q tunnel1 phase1 allows SHA1", [resource.address])
}

# 8) VPC Flow Logs must exist for every aws_vpc.
deny[msg] {
  vpc := input.resource_changes[_]
  vpc.type == "aws_vpc"
  vpc.change.actions[_] == "create"
  not has_flow_log_for_vpc(vpc.address)
  msg := sprintf("aws_vpc %q has no aws_flow_log resource — flow logging required", [vpc.address])
}

has_flow_log_for_vpc(vpc_address) {
  fl := input.resource_changes[_]
  fl.type == "aws_flow_log"
  fl.change.after.vpc_id != null
}

# 9) Public IPs auto-assign is forbidden on subnets.
deny[msg] {
  subnet := input.resource_changes[_]
  subnet.type == "aws_subnet"
  subnet.change.after.map_public_ip_on_launch == true
  not is_public_subnet(subnet.change.after.tags)
  msg := sprintf("aws_subnet %q has map_public_ip_on_launch=true on a non-public subnet", [subnet.address])
}

is_public_subnet(tags) {
  tags.Tier == "public"
}
