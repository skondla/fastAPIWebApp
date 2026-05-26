# Module: aws-azure-vpn

Builds the AWS ↔ Azure leg of the full-mesh IPsec topology.

## Topology
```
                  ┌──────────────┐                 ┌──────────────┐
   AWS TGW  ─────►│  VPN Conn 0  │◄─── IPsec ───►  │  Azure LNG 0 │  → Azure VNG
                  │  (2 tunnels) │                 │  (PIP-A)     │
                  └──────────────┘                 └──────────────┘
                  ┌──────────────┐                 ┌──────────────┐
   AWS TGW  ─────►│  VPN Conn 1  │◄─── IPsec ───►  │  Azure LNG 1 │  → Azure VNG
                  │  (2 tunnels) │                 │  (PIP-B)     │
                  └──────────────┘                 └──────────────┘
```
4 tunnels total, BGP-routed, AES-256-GCM, SHA2-256, DH-14+.

## What it builds
- 2× AWS customer gateways (one per Azure VPN public IP, active-active)
- 2× AWS VPN connections (TGW-attached, BGP), each with 2 tunnels
- Random 32-byte PSKs (kept in Terraform state — encrypt your backend)
- TGW route-table association + propagation
- Static fallback routes for Azure CIDRs on TGW RT
- 4× Azure Local Network Gateways (one per AWS tunnel public IP)
- 4× Azure VNG connections (IPsec, BGP)
- Strong IPsec policy: AES-256-GCM / SHA2-256 / PFS14 / IKEv2

## Guardrails
- IKEv2 only — IKEv1 forbidden
- AES256-GCM-16 only — no CBC, no 3DES
- SHA2-256 minimum — no SHA1
- DH group 14+ — no group 1/2/5
- Active-active mandatory (2 IPs validated)
- ASNs must come from caller; module refuses to default

## Inputs
- `transit_gateway_id`, `transit_gateway_route_table_id`, `aws_side_asn`, `aws_address_space`
- `azure_vpn_gateway_id`, `azure_vpn_gateway_public_ips` (2), `azure_vpn_gateway_asn`, `azure_address_space`
- `azure_resource_group_name`, `azure_location`, `tags`

## Notes
PSKs land in state. Make sure the Terraform backend (S3 / Azure Storage / GCS)
is encrypted at rest with a CMK, has versioning, MFA-delete or object-lock,
and least-privilege IAM. State-export is a credential leak.
