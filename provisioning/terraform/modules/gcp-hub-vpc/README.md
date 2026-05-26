# Module: gcp-hub-vpc

Hub VPC for the GCP side of the multi-cloud topology. Defaults to `us-east4`.

## What it builds
- Shared VPC host project flag (service projects can attach later)
- Custom-mode VPC, global routing
- Primary subnet with /20-ish range carved from the hub CIDR, plus secondary
  ranges `pods` (RFC 6598 by default) and `services`
- Subnet-level VPC Flow Logs at 5s aggregation, 100% sampling, full metadata
- Cloud Router with BGP enabled (ASN guarded to 64512-65534)
- Cloud NAT with logging for failed translations
- Firewall baseline:
  - explicit deny-all-ingress @ priority 65534
  - allow east-west from hub/pods/services CIDRs @ priority 1000
  - allow IAP TCP-forwarding from 35.235.240.0/20 to `iap-ssh`-tagged hosts
  - allow GKE master ↔ node ports to `gke-node`-tagged hosts
- HA VPN gateway (2 interfaces — required for SLA)
- Private Service Connect endpoint for Google APIs (`all-apis`)

## Guardrails enforced inside the module
- `flow_logs_retention_days >= 90`
- Router ASN must be in private range and unique per cloud
- Flow logs are always-on for the hub subnet (no opt-out)
- NAT logs failed translations (helps detect outbound C2)
- HA VPN, not Classic VPN (Classic VPN is deprecated and offers no SLA)

## Outputs
Surface IDs needed by spoke modules + the cross-cloud VPN module
(`router_name`, `ha_vpn_gateway_id`, `router_asn`).
