# Module: azure-hub-vnet

Hub VNet for the Azure side of the multi-cloud topology. Defaults to `eastus2`.

## What it builds
- Resource group
- VNet with caller-supplied CIDR
- `GatewaySubnet` (required name; for VPN/ER)
- `AzureFirewallSubnet` + Azure Firewall Premium (toggleable)
- 3× workload subnets with service endpoints for KeyVault / Storage / Sql / ACR
- Default-deny NSGs attached to each workload subnet (Internet → deny; VNet → allow)
- NSG flow logs v2 with Traffic Analytics → Log Analytics
- Active-active zonal VPN Gateway (VpnGw2AZ, BGP enabled)

## Guardrails enforced inside the module
- `flow_logs_retention_days >= 90`
- VPN gateway ASN must be private (64512-65534), default 65515 per Azure guidance
- Workload NSGs ship with explicit Internet-inbound deny
- Firewall is Premium with IDPS + threat-intel in `Alert` mode
- VPN gateway is zonal active-active (no single-AZ deployments)

## Outputs
Surface IDs + the two gateway public IPs (consumed by `aws-azure-vpn`,
`azure-gcp-vpn`) and the Azure-side BGP ASN.

## Required external inputs
This module does NOT create the Log Analytics workspace or flow-log storage
account — pass `log_analytics_workspace_id` and `flow_logs_storage_account_id`.
Those live in a separate logging/observability module so they can be shared
across spokes.
