package main

# Every taggable AWS / Azure resource must carry the standard tag set.
# GCP labels are checked separately (lowercase + restricted character set).

required_tags := {"Project", "Environment", "Owner", "CostCenter", "ManagedBy"}

# AWS — read .tags off any resource that supports it.
aws_taggable_types := {
  "aws_vpc",
  "aws_subnet",
  "aws_security_group",
  "aws_internet_gateway",
  "aws_nat_gateway",
  "aws_route_table",
  "aws_eip",
  "aws_ec2_transit_gateway",
  "aws_vpn_connection",
  "aws_customer_gateway",
  "aws_flow_log",
  "aws_cloudwatch_log_group",
  "aws_kms_key",
}

deny[msg] {
  resource := input.resource_changes[_]
  aws_taggable_types[resource.type]
  tags := object.get(resource.change.after, "tags", {})
  missing := required_tags - {k | tags[k]}
  count(missing) > 0
  msg := sprintf("%s %q is missing required tags: %v", [resource.type, resource.address, missing])
}

# Azure — same idea but tags live at the resource root.
azure_taggable_types := {
  "azurerm_resource_group",
  "azurerm_virtual_network",
  "azurerm_subnet",
  "azurerm_network_security_group",
  "azurerm_virtual_network_gateway",
  "azurerm_public_ip",
  "azurerm_firewall",
  "azurerm_firewall_policy",
  "azurerm_virtual_wan",
  "azurerm_virtual_hub",
  "azurerm_vpn_gateway",
  "azurerm_vpn_site",
}

deny[msg] {
  resource := input.resource_changes[_]
  azure_taggable_types[resource.type]
  tags := object.get(resource.change.after, "tags", {})
  missing := required_tags - {k | tags[k]}
  count(missing) > 0
  msg := sprintf("%s %q is missing required tags: %v", [resource.type, resource.address, missing])
}

# GCP — labels are lowercase; check the lowercase equivalents.
required_labels := {"project", "environment", "owner", "costcenter", "managedby"}

gcp_labelable_types := {
  "google_compute_subnetwork",
  "google_compute_router",
  "google_compute_router_nat",
}

deny[msg] {
  resource := input.resource_changes[_]
  gcp_labelable_types[resource.type]
  labels := object.get(resource.change.after, "labels", {})
  missing := required_labels - {k | labels[k]}
  count(missing) > 0
  msg := sprintf("%s %q is missing required labels: %v", [resource.type, resource.address, missing])
}
