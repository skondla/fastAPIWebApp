package main

# Resources that are silent money-sinks must carry a CostCenter tag matching the
# CC-XXX-NNN format. Catches the "untagged TGW left running in dev" pattern.

cost_sensitive_aws := {
  "aws_ec2_transit_gateway",
  "aws_nat_gateway",
  "aws_vpn_connection",
}

cost_sensitive_azure := {
  "azurerm_virtual_network_gateway",
  "azurerm_firewall",
  "azurerm_virtual_wan",
  "azurerm_vpn_gateway",
}

cc_pattern := `^CC-[A-Z]+-[0-9]{3}$`

deny[msg] {
  resource := input.resource_changes[_]
  cost_sensitive_aws[resource.type]
  cc := object.get(object.get(resource.change.after, "tags", {}), "CostCenter", "")
  not regex.match(cc_pattern, cc)
  msg := sprintf("%s %q CostCenter tag %q does not match required pattern %s", [resource.type, resource.address, cc, cc_pattern])
}

deny[msg] {
  resource := input.resource_changes[_]
  cost_sensitive_azure[resource.type]
  cc := object.get(object.get(resource.change.after, "tags", {}), "CostCenter", "")
  not regex.match(cc_pattern, cc)
  msg := sprintf("%s %q CostCenter tag %q does not match required pattern %s", [resource.type, resource.address, cc, cc_pattern])
}
