# Option C — Megaport Cloud Router (SDN private interconnect)

```
           ┌──────────────────────────────────────────────┐
           │       Megaport Cloud Router (MCR)            │
           │       ASN 64513, 1-10 Gbps                   │
           └─┬───────────────┬──────────────────┬─────────┘
             │VXC            │VXC               │VXC
             ▼               ▼                  ▼
        ┌─────────┐     ┌──────────┐      ┌──────────┐
        │ AWS DX  │     │ Azure ER │      │ GCP PIC  │
        │ DXGW    │     │ Circuit  │      │ Attach   │
        └─────────┘     └──────────┘      └──────────┘
              │              │                  │
              ▼              ▼                  ▼
         AWS TGW         Azure VWAN         GCP VPC
```

5-15ms cross-cloud latency, up to 10 Gbps per VXC, no IPsec overhead.

## When to choose this
- Workloads sensitive to >50ms latency (gaming, real-time analytics, finance).
- Regulated data that must avoid the public internet entirely.
- East-west traffic >5 TB/month — Megaport is cheaper than VPN data-transfer at scale.

## When NOT to choose this
- Variable / spiky cross-cloud usage — Megaport monthly commit doesn't amortize.
- You can't get a Megaport sales contact within 1 week (signup → first VXC up takes ~5 days).
- You only need one leg (e.g. just AWS↔Azure) — point IPsec is fine for that.

## What's here (and what's NOT)
This option is **scaffolding only**. The Megaport provider, MCR, and 3 VXC
resources are modeled, but the prerequisites — AWS Direct Connect VIF, Azure
ExpressRoute circuit, GCP Partner Interconnect attachment — must be created
out of band and their service-keys / pairing-keys / VIF IDs handed in as
variables. See `modules/megaport-fabric/README.md`.

## Apply path
1. Sign Megaport contract; record account credentials.
2. Provision AWS DXGW + hosted VIF in target region.
3. Provision Azure ExpressRoute circuit (Standard SKU min).
4. Provision GCP Partner Interconnect attachment (in `PENDING_PARTNER`).
5. Populate this directory's `terraform.tfvars` with all keys + UIDs.
6. `terraform init && terraform plan && terraform apply`.
7. Approve VXC requests in Megaport portal.
8. Wait for all three BGP sessions to reach `Established`.
