# Cross-cloud connectivity — alternative topologies

The default topology (`envs/prod/cross-cloud/`) is **full-mesh IPsec VPN**: three
legs (AWS↔Azure, AWS↔GCP, Azure↔GCP), BGP-routed, no single hub.

This directory holds three alternatives so a team can choose based on cost,
operational complexity, and SLA needs. **Only one option should be applied at a
time** — they are mutually exclusive ways of moving the same packets.

## Decision matrix

| Option                              | Cost ($/mo, rough) | Latency  | Throughput  | Ops cx | Single point of failure | Best when                                    |
|-------------------------------------|--------------------|----------|-------------|--------|-------------------------|----------------------------------------------|
| **Default — Full mesh IPsec VPN**   | ~$1.2k             | 60-90ms  | 1.25 Gbps/t | Med    | No                      | You want native-only, BGP HA, no vendor      |
| **B — AWS TGW hub-and-spoke**       | ~$0.9k             | 90-140ms | 1.25 Gbps/t | Low    | Yes (AWS region)        | AWS-centric org, simple routing wins         |
| **C — Megaport / Equinix SDN**      | ~$2.0-4.0k         | 5-15ms   | up to 10 G  | Med-H  | No (with redundancy)    | Latency-sensitive workloads, regulated data  |
| **D — Azure Virtual WAN hub**       | ~$1.5k             | 60-100ms | 20 Gbps agg | Med    | Yes (Azure region)      | Azure-centric, want managed routing service  |

Latency numbers assume `us-east-1` / `eastus2` / `us-east4`. Real numbers will
depend on regions and Megaport POP selection.

## Layout

```
cross-cloud-alternatives/
├── option-b-aws-tgw-hub/      # AWS is the transit hub; Azure & GCP each have one VPN to AWS, no Azure↔GCP direct leg
├── option-c-megaport-sdn/     # Megaport Cloud Router (MCR) with VXCs to AWS DXGW, Azure ExpressRoute, GCP Partner Interconnect
└── option-d-azure-vwan-hub/   # Azure Virtual WAN as the global hub; AWS & GCP connect as branches
```

## Switching topologies

1. `terraform destroy` the currently-applied option's directory.
2. Verify zero tunnels remain (`aws ec2 describe-vpn-connections`,
   `az network vnet-gateway list-connections`, `gcloud compute vpn-tunnels list`).
3. `terraform apply` the new option's directory.

Do NOT layer two options on the same hub at once — BGP route-selection becomes
nondeterministic and traffic can blackhole during failover tests.
