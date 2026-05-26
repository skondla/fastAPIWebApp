package main

# Permitted hub/spoke CIDRs per cloud — must match _global/network-cidr-plan.md.
# Catches accidental drift between the planning doc and live config.

allowed_aws_cidrs := {
  "10.10.0.0/16",
  "10.20.0.0/16",
  "10.30.0.0/16",
}

allowed_azure_cidrs := {
  "10.40.0.0/16",
  "10.50.0.0/16",
  "10.60.0.0/16",
  "10.41.0.0/24", # vWAN hub block from option D
}

allowed_gcp_cidrs := {
  "10.70.0.0/16",
  "10.80.0.0/16",
  "10.90.0.0/16",
}

deny[msg] {
  vpc := input.resource_changes[_]
  vpc.type == "aws_vpc"
  cidr := vpc.change.after.cidr_block
  not allowed_aws_cidrs[cidr]
  msg := sprintf("aws_vpc %q uses CIDR %v not in the AWS allocation table (see _global/network-cidr-plan.md)", [vpc.address, cidr])
}

deny[msg] {
  vnet := input.resource_changes[_]
  vnet.type == "azurerm_virtual_network"
  cidr := vnet.change.after.address_space[_]
  not allowed_azure_cidrs[cidr]
  msg := sprintf("azurerm_virtual_network %q uses CIDR %v not in the Azure allocation table", [vnet.address, cidr])
}

deny[msg] {
  subnet := input.resource_changes[_]
  subnet.type == "google_compute_subnetwork"
  cidr := subnet.change.after.ip_cidr_range
  not in_any_allowed_gcp_supernet(cidr)
  msg := sprintf("google_compute_subnetwork %q uses CIDR %v not contained in any GCP allocation block", [subnet.address, cidr])
}

in_any_allowed_gcp_supernet(cidr) {
  super := allowed_gcp_cidrs[_]
  net.cidr_contains(super, cidr)
}
