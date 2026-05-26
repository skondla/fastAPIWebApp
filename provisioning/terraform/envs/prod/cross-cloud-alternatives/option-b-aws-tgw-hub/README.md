# Option B — AWS Transit Gateway as the global hub

```
                     ┌─────────────────────────────┐
                     │   AWS Transit Gateway       │
                     │   (us-east-1, ASN 64512)    │
                     └──┬──────────────────────┬───┘
              IPsec/BGP │                      │ IPsec/BGP
                        ▼                      ▼
              ┌─────────────────┐    ┌─────────────────┐
              │ Azure VPN GW    │    │ GCP HA VPN GW   │
              │ (eastus2)       │    │ (us-east4)      │
              └─────────────────┘    └─────────────────┘
```

Azure ↔ GCP traffic transits AWS. This is a **2-leg** topology vs the default 3-leg mesh.

## Trade-offs vs. default mesh
- ✅ Half the tunnels to operate; simpler change windows.
- ✅ ~25% lower run cost (4 fewer tunnels).
- ❌ AWS region outage = total cross-cloud blackout. Mesh survives one region failure on any cloud.
- ❌ Azure↔GCP latency adds an extra inter-region hop through AWS (~+40ms in us-east).
- ❌ AWS data-transfer bill carries 100% of cross-cloud east-west.

## What this composes
Reuses the same `modules/aws-azure-vpn` + `modules/aws-gcp-vpn` modules — just
omits `modules/azure-gcp-vpn`. Routing is identical except Azure↔GCP routes
ride two TGW attachments.

## Apply
```
terraform init
cp terraform.tfvars.example terraform.tfvars   # edit the IDs/IPs
terraform plan
terraform apply
```
