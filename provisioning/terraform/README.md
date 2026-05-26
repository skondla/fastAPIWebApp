# Multi-cloud network IaC

Terraform that builds the network plane underneath the AWS / Azure / GCP
FastAPI workloads. Three hub-and-spoke environments plus a cross-cloud
overlay that stitches them together.

## Layout

```
provisioning/terraform/
├── _global/
│   ├── network-cidr-plan.md          # IP allocation table — change here first
│   └── guardrails/                   # OPA/Rego, tfsec, checkov, pre-commit
├── modules/
│   ├── common-tags/                  # Standard tag map (AWS/Azure) + label map (GCP)
│   ├── aws-hub-vpc/                  # AWS hub VPC + TGW + flow logs + endpoints
│   ├── aws-spoke-vpc/                # AWS spoke VPC attached to TGW
│   ├── azure-hub-vnet/               # Azure hub VNet + Firewall Premium + VPN GW
│   ├── azure-spoke-vnet/             # Azure spoke VNet peered to hub
│   ├── gcp-hub-vpc/                  # GCP Shared VPC host + HA VPN + Cloud NAT + PSC
│   ├── gcp-spoke-vpc/                # GCP service-project VPC attached to shared VPC
│   ├── aws-azure-vpn/                # AWS TGW ↔ Azure VPN GW (IPsec/BGP)
│   ├── aws-gcp-vpn/                  # AWS TGW ↔ GCP HA VPN
│   ├── azure-gcp-vpn/                # Azure VPN GW ↔ GCP HA VPN
│   ├── azure-vwan-hub/               # Azure Virtual WAN hub (for option D)
│   └── megaport-fabric/              # Megaport MCR + 3× VXC (for option C)
└── envs/prod/
    ├── aws/                          # Apply per-cloud env stack
    ├── azure/
    ├── gcp/
    ├── cross-cloud/                  # Default: full-mesh IPsec (option A)
    └── cross-cloud-alternatives/
        ├── option-b-aws-tgw-hub/
        ├── option-c-megaport-sdn/
        └── option-d-azure-vwan-hub/
```

## Apply order

1. `envs/prod/aws/`     → TGW, hub VPC, spokes
2. `envs/prod/azure/`   → VPN GW, hub VNet, spokes
3. `envs/prod/gcp/`     → HA VPN, Shared VPC, spokes
4. `envs/prod/cross-cloud/` (or one of the alternatives) → wire them together

Output handoff: the cross-cloud stack consumes outputs from steps 1-3 via
`terraform.tfvars` (or via `terraform_remote_state` if you wire that in your
backend config — recommended for prod).

## Guardrails enforced (failed plans block merge)

| Check                                  | Where                                            |
|----------------------------------------|--------------------------------------------------|
| `terraform fmt` / `validate`           | GitHub Actions `network-iac-validate.yml`        |
| `tflint`                               | Workflow + pre-commit                            |
| `tfsec`                                | Workflow + pre-commit                            |
| `checkov` (CRITICAL/HIGH fails)        | Workflow + pre-commit                            |
| `conftest` against OPA policies        | Workflow                                         |
| No CIDR overlap                        | `_global/guardrails/conftest/policy/cidr.rego`   |
| No 0.0.0.0/0 ingress to non-LB ports   | `network.rego`                                   |
| IKEv2 only, AES256-GCM, SHA256, DH≥14  | `network.rego`                                   |
| VPC flow logs required                 | `network.rego` + tfsec                           |
| Required tag set                       | `tagging.rego`                                   |
| KMS rotation enabled                   | `encryption.rego`                                |
| CostCenter pattern on heavy resources  | `cost.rego`                                      |

## Local workflow

```bash
brew install terraform tflint tfsec checkov conftest pre-commit terraform-docs
pre-commit install   # use provisioning/terraform/_global/guardrails/pre-commit-config.yaml

cd provisioning/terraform/envs/prod/aws
cp terraform.tfvars.example terraform.tfvars   # if needed
terraform init -backend=false
terraform validate
terraform plan -out=tfplan.bin
terraform show -json tfplan.bin > tfplan.json
conftest test --policy ../../../_global/guardrails/conftest/policy tfplan.json
```

## Architecture diagrams

- [docs/architecture/multi-cloud-network.md](../../docs/architecture/multi-cloud-network.md)
- [docs/architecture/multi-cloud-topology-alternatives.md](../../docs/architecture/multi-cloud-topology-alternatives.md)

## Runbook

See [docs/architecture/runbook-multi-cloud-network.md](../../docs/architecture/runbook-multi-cloud-network.md).
