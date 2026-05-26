# Option D — Azure Virtual WAN as the global hub

```
                  ┌──────────────────────────────┐
                  │  Azure Virtual WAN (Standard) │
                  │  Virtual Hub + S2S VPN GW     │
                  │  + Azure Firewall Premium     │
                  └────┬────────────┬─────────────┘
                       │            │
              VPN Site │            │ VPN Site
                       ▼            ▼
              ┌─────────────┐   ┌─────────────┐
              │ AWS TGW     │   │ GCP HA VPN  │
              │ (us-east-1) │   │ (us-east4)  │
              └─────────────┘   └─────────────┘
              VNet Conn │
                       ▼
                  Azure spokes
```

Azure vWAN gives you Microsoft-managed BGP route propagation across all
branches (AWS, GCP, on-prem) plus an in-hub Azure Firewall Premium for
inspection. Branches connect as VPN-sites; Azure VNets as hub-virtual-network
connections.

## Trade-offs vs. default mesh
- ✅ Microsoft fully manages route propagation, transit, and failover.
- ✅ Built-in Secure Virtual Hub firewall (inline inspection, no UDR plumbing).
- ✅ Encrypted ExpressRoute optional later.
- ❌ Azure region outage = total cross-cloud blackout.
- ❌ Vendor lock-in to Azure for the network plane.
- ❌ S2S VPN scale-unit cost is fixed regardless of usage (~$365/scale-unit/mo).

## What this composes
- `modules/azure-vwan-hub` (new) — provisions vWAN, vHub, S2S VPN GW, AzFw.
- `modules/aws-azure-vpn` adapted — AWS-side TGW VPN to vHub VPN site IPs.
- `modules/azure-gcp-vpn` adapted — GCP-side HA VPN to vHub VPN site IPs.

VPN-site connection resources (`azurerm_vpn_site` + `azurerm_vpn_gateway_connection`)
are scaffolded here.

## Apply
This option requires destroying the default-mesh `cross-cloud/` deploy first
(BGP loop prevention will reject the mixed topology otherwise).
