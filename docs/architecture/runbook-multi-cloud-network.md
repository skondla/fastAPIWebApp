# Multi-cloud network runbook

Operational guide for the network plane built by `provisioning/terraform/`.

## Day 0 — first-time provisioning

### Prereqs
- Terraform >= 1.5.0
- AWS CLI (configured with an admin role)
- Azure CLI (logged in to the target subscription)
- gcloud CLI (logged in to the host project + service projects)
- A pre-existing state backend per cloud (encrypted, versioned, locked)
- An LAW workspace + storage account in Azure for flow logs
- Pre-allocated CIDR blocks in `_global/network-cidr-plan.md`

### Sequence
```bash
# 1) AWS hub + spokes
cd provisioning/terraform/envs/prod/aws
terraform init && terraform plan -out=tfplan && terraform apply tfplan
AWS_TGW_ID=$(terraform output -raw transit_gateway_id)
AWS_TGW_RT=$(terraform output -raw transit_gateway_route_table_id)
AWS_CIDRS=$(terraform output -json advertised_cidrs)

# 2) Azure hub + spokes
cd ../azure
terraform init && terraform plan -out=tfplan && terraform apply tfplan
AZ_VPN_GW_ID=$(terraform output -raw vpn_gateway_id)
AZ_VPN_IPS=$(terraform output -json vpn_gateway_public_ips)

# 3) GCP hub + spokes
cd ../gcp
terraform init && terraform plan -out=tfplan && terraform apply tfplan

# 4) Cross-cloud mesh
cd ../cross-cloud
# Populate terraform.tfvars from steps 1-3 outputs
terraform init && terraform plan -out=tfplan && terraform apply tfplan
```

### Verify
- AWS: `aws ec2 describe-vpn-connections` — all 4 should show `state=available`, both tunnels `UP`.
- Azure: `az network vpn-connection list -g <hub-rg> --query "[].{name:name, status:connectionStatus}"` — all `Connected`.
- GCP: `gcloud compute vpn-tunnels list` — all `ESTABLISHED`.
- BGP: at least one tunnel per leg shows BGP `BGP UP` and route exchange.
- End-to-end: from an AWS prod EC2/EKS node, `ping` the GCP and Azure spoke subnet anycast (or a known instance IP).

## Day 2 — common operations

### Add a new spoke
1. Allocate a /16 in `_global/network-cidr-plan.md` (commit first).
2. Add a new `module "spoke_<name>" { source = "../../../modules/<cloud>-spoke-*" }` block in the relevant env stack.
3. Append the new CIDR to `remote_cidrs` on the OTHER two clouds' spoke modules.
4. Re-apply cross-cloud stack (TGW + LNG route updates).

### Rotate a tunnel PSK
1. Edit `cross-cloud/main.tf` — add a `replace_triggered_by` on the random_password resources OR just `terraform taint`.
2. `terraform apply` during a maintenance window — expect ~30s of route convergence per leg as tunnels re-establish.
3. Verify with `aws ec2 describe-vpn-connections` and `az network vpn-connection show`.

### Failover test
Pick a leg (e.g. AWS↔Azure):
1. Snapshot pre-test latency: `mtr -c 100 <azure-prod-subnet-IP>` from AWS workload.
2. Force-down one tunnel: `aws ec2 modify-vpn-tunnel-options ... --modify=down` OR disable on AzureLNG side.
3. Expect <30s BGP convergence; mtr should show packet loss for ≤15 packets.
4. Restore. Confirm BGP brings the route back.

### Change a region
NOT a runbook step — this is a re-provision. CIDRs are region-locked in the
plan. Open a design doc first.

## Troubleshooting

### Tunnel won't come up
1. Verify both sides have matching PSK (re-pull from state):
   `terraform state pull | jq '.resources[] | select(.type=="random_password")'`
2. Check IKE policies match — AWS / Azure / GCP all need IKEv2 + AES256-GCM + SHA2-256 + DH14+.
3. Check ASNs are unique. BGP loop prevention silently drops routes if duplicated.

### BGP up but no routes
1. AWS: `aws ec2 describe-transit-gateway-route-tables` — propagation enabled?
2. Azure: `az network vnet-gateway list-bgp-peer-status` — both peer status `Connected`?
3. GCP: `gcloud compute routers get-status <router>` — `bestRoutes` populated?

### CIDR overlap detected at plan time
You forgot to update `_global/network-cidr-plan.md`. Fix it; update the
`allowed_*_cidrs` lists in `conftest/policy/cidr.rego`; re-plan.

### Flow logs missing
- AWS: check IAM role trust policy on `vpc-flow-logs.amazonaws.com`, check
  the CloudWatch log group exists, check KMS key policy permits the regional
  Logs service principal.
- Azure: check `Microsoft.Insights/diagnosticSettings` on the NSG, check the
  storage account in `flow_logs_storage_account_id` is in the same region.
- GCP: `gcloud compute networks subnets describe <subnet> --format=json` —
  `logConfig.enable` must be true.

## Cost guardrails

- Every NAT GW + TGW attachment costs ~$0.05/hr + per-GB charges. Sandbox
  envs should set `enable_transit_gateway = false`.
- VPN tunnel cost: $0.05/hr per tunnel — full mesh is 12 tunnels = ~$430/mo
  baseline + data transfer.
- Azure Firewall Premium: ~$1.25/hr fixed = ~$900/mo. Disable in nonprod.
- VPC Flow Logs at INTERVAL_5_SEC + 100% sampling are expensive at scale —
  consider 60s aggregation for spokes once baseline is established.

## Decommissioning

`terraform destroy` order is the REVERSE of apply:
1. `cross-cloud/` (and any cross-cloud-alternatives)
2. `gcp/`
3. `azure/`
4. `aws/`

Destroying hub before cross-cloud will leave orphaned tunnels and
customer-gateways; subsequent applies will fail with attachment-state
conflicts.
